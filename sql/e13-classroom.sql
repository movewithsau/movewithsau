-- =====================================================================
-- MOVE · E13 · Classroom (Educación en Food) · 24 nov 2026
-- 100 % aditivo e idempotente: crea 3 tablas nuevas, un bucket nuevo y una
-- policy de Storage SOLO para ese bucket. No toca tablas ni buckets existentes.
-- RLS de las tablas queda desactivado (igual que el resto del app).
-- Los videos NO se suben: se guarda el link de Vimeo / YouTube.
-- =====================================================================

do $do$
declare
  t text;
begin
  -- Tipo real de clients.id (INTEGER o UUID): la FK de classroom_views usa el mismo tipo
  select format_type(a.atttypid, a.atttypmod) into t
  from pg_attribute a
  where a.attrelid = 'public.clients'::regclass and a.attname = 'id' and not a.attisdropped;
  if t is null then
    raise exception 'No encontré clients.id: avisale a Claude antes de seguir';
  end if;

  -- 1) Categorías (orden con position)
  create table if not exists public.classroom_categories (
    id bigint generated always as identity primary key,
    name text not null,
    position int not null default 0,
    created_at timestamptz not null default now()
  );

  -- 2) Clases (video) y recursos (bloques). Una categoría con contenido no se puede
  --    borrar (on delete restrict): el app pide moverlo o borrarlo antes.
  create table if not exists public.classroom_items (
    id bigint generated always as identity primary key,
    category_id bigint not null references public.classroom_categories(id) on delete restrict,
    kind text not null check (kind in ('class','resource')),
    title text not null,
    description text,
    cover_url text,
    video_url text,
    video_provider text check (video_provider in ('vimeo','youtube')),
    video_duration_seconds int,
    blocks jsonb not null default '[]'::jsonb,
    access text not null default 'all' check (access in ('all','vip')),
    status text not null default 'draft' check (status in ('draft','published')),
    position int not null default 0,
    published_at timestamptz,          -- primera publicación: etiqueta "Nueva" (14 días sin ver)
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  -- 3) Qué vio cada cliente
  execute format($f$
    create table if not exists public.classroom_views (
      client_id %s not null references public.clients(id),
      item_id bigint not null references public.classroom_items(id) on delete cascade,
      viewed_at timestamptz not null default now(),
      primary key (client_id, item_id)
    )$f$, t);
end
$do$;

create index if not exists idx_classroom_items_cat on public.classroom_items (category_id, position);
create index if not exists idx_classroom_views_item on public.classroom_views (item_id);

-- 4) Bucket PÚBLICO para portadas e imágenes de recursos (solo imágenes, 5 MB)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('classroom', 'classroom', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do nothing;

-- 5) Policy de Storage SOLO para classroom, mismo patrón que support_chat_all_access
do $do$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'classroom_all_access'
  ) then
    create policy classroom_all_access on storage.objects
      for all to public
      using (bucket_id = 'classroom')
      with check (bucket_id = 'classroom');
  end if;
end
$do$;

-- 6) Verificación: mandale el resultado a Claude
select table_name, count(*) as columnas
from information_schema.columns
where table_schema = 'public' and table_name in ('classroom_categories','classroom_items','classroom_views')
group by table_name order by table_name;
select id, public, file_size_limit from storage.buckets where id = 'classroom';
select policyname, cmd, roles from pg_policies
where schemaname = 'storage' and tablename = 'objects' and policyname = 'classroom_all_access';

-- =====================================================================
-- MOVE · E11 · Aviso a pantalla completa (botón wifi) · 24 nov 2026
-- 100 % aditivo e idempotente: solo crea una tabla nueva y su índice.
-- No toca tablas existentes ni borra nada. Se puede correr más de una vez.
-- RLS queda desactivado (igual que el resto del app): no se agregan políticas.
-- La purga de 7 días de coach_feed (11.5) NO necesita SQL: la hace el cron
-- api/coach-digest con un DELETE por REST.
-- =====================================================================

do $do$
declare
  t text;
begin
  -- Tipo real de clients.id (INTEGER o UUID): la FK usa el mismo tipo
  select format_type(a.atttypid, a.atttypmod) into t
  from pg_attribute a
  where a.attrelid = 'public.clients'::regclass and a.attname = 'id' and not a.attisdropped;
  if t is null then
    raise exception 'No encontré clients.id: avisale a Claude antes de seguir';
  end if;

  -- Un registro por cliente destino. seen_at se llena cuando el cliente toca
  -- el botón principal, "Más tarde" o la X: desde ahí no vuelve a salir.
  execute format($f$
    create table if not exists public.client_announcements (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      title text not null,
      body text,
      destination text not null check (destination in
        ('semana','extra','protocolos','guias','run','classroom','menu','hive','chat')),
      destination_ref text,          -- id del ítem concreto (texto: sirve para int o uuid)
      source text not null default 'manual' check (source in ('manual','after_save','bulk')),
      created_at timestamptz not null default now(),
      seen_at timestamptz
    )$f$, t);
end
$do$;

-- Pendientes de un cliente, el más reciente primero
create index if not exists idx_client_announcements_pending
  on public.client_announcements (client_id, seen_at, created_at desc);

-- Verificación: mandale el resultado a Claude
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'client_announcements'
order by ordinal_position;

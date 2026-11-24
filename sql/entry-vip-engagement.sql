-- =====================================================================
-- MOVE · Entry / VIP · E9 Engagement (borrador del 23 nov 2026)
-- 100 % aditivo e idempotente. No toca tablas existentes: solo crea 2 tablas nuevas.
-- No hace falta backup (no se modifica ni se borra nada existente).
-- =====================================================================

do $do$
declare
  t text;
begin
  select format_type(a.atttypid, a.atttypmod) into t
  from pg_attribute a
  where a.attrelid = 'public.clients'::regclass and a.attname = 'id' and not a.attisdropped;
  if t is null then
    raise exception 'No encontré clients.id: avisale a Claude antes de seguir';
  end if;

  -- (a) Hilo "Coach" del lado de Sau: solo historial (resúmenes nocturnos y avisos de nudges).
  --     Tabla aparte: no se mezcla con support_messages ni entra en la purga de 7 días.
  execute format($f$
    create table if not exists public.coach_feed (
      id bigint generated always as identity primary key,
      kind text not null check (kind in ('digest','nudge')),
      body text not null,
      client_id %s references public.clients(id),
      created_at timestamptz not null default now()
    )$f$, t);

  -- (b) Registro de nudges de inactividad enviados (uno por episodio).
  --     last_training_date = último entreno conocido al enviar (null si nunca entrenó);
  --     un episodio nuevo solo se abre si hay un entreno posterior a esa fecha.
  execute format($f$
    create table if not exists public.entry_nudges (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      episode int not null check (episode >= 1),
      last_training_date date,
      message_id bigint references public.support_messages(id) on delete set null,
      sent_at timestamptz not null default now(),
      unique (client_id, episode)
    )$f$, t);
end
$do$;

create index if not exists idx_coach_feed_created on public.coach_feed (created_at desc);
create index if not exists idx_entry_nudges_client on public.entry_nudges (client_id, episode desc);

-- Verificación (solo lectura): deberían salir las 2 tablas.
select table_name from information_schema.tables
 where table_schema = 'public' and table_name in ('coach_feed','entry_nudges');

-- =====================================================================
-- MOVE · E12 · Cambios de semana automáticos · 24 nov 2026
-- 100 % aditivo e idempotente: crea dos tablas nuevas y carga dos valores
-- por defecto (sin pisar nada si ya existen). No toca tablas existentes.
-- RLS queda desactivado (igual que el resto del app): no se agregan políticas.
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

  -- Nota de Sau y "No avisar esta semana" por cliente y semana del plan
  -- (week_number = monthly_plans.week_number). Sin fila = nota por defecto y sí avisar.
  execute format($f$
    create table if not exists public.week_change_notes (
      id bigint generated always as identity primary key,
      client_id %s not null references public.clients(id),
      week_number int not null,
      note text,
      skip boolean not null default false,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now(),
      unique (client_id, week_number)
    )$f$, t);
end
$do$;

-- Ajustes del coach (clave / valor). Se comparte con E14 (lift_enabled, etc.).
create table if not exists public.coach_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

-- Valores por defecto (no pisa lo que ya exista)
insert into public.coach_settings (key, value) values
  ('week_change_auto', 'true'),
  ('week_change_default_note', 'Seguimos mejorando.')
on conflict (key) do nothing;

-- Verificación: mandale el resultado a Claude
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name in ('week_change_notes', 'coach_settings')
order by table_name, ordinal_position;
select * from public.coach_settings order by key;

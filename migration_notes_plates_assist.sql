-- =====================================================================
-- MOVE · Notas, placas y solicitudes de asistencia por ejercicio
-- Rama: feat/notes-plates-assist
--
-- SOLO ADITIVO: tablas nuevas (IF NOT EXISTS). No toca ninguna tabla existente.
-- RLS sigue deshabilitado: no se agregan policies.
-- Correr en el SQL Editor de Supabase.
--
-- Identidad del ejercicio: exercises.id cambia en cada semana/mes del plan,
-- así que todo se ata al ejercicio de la librería:
--   exercise_library_id  uuid  → exercise_library.id resuelto por nombre (null si no hay match)
--   exercise_key         text  → nombre normalizado (minúsculas, sin tildes, espacios simples)
-- Las búsquedas y la unicidad usan (client_id, exercise_key).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- A1 · Notas por ejercicio
-- ---------------------------------------------------------------------
create table if not exists exercise_notes (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid not null references clients(id),
  exercise_library_id uuid null references exercise_library(id),
  exercise_key        text not null,
  note                text not null,
  created_at          timestamptz not null default now(),
  deleted_at          timestamptz null,
  seen_by_coach_at    timestamptz null
);

create index if not exists exercise_notes_client_ex_created_idx
  on exercise_notes (client_id, exercise_key, created_at desc);

-- ---------------------------------------------------------------------
-- A2 · Último setup de placas (1 fila por cliente + ejercicio; upsert)
-- ---------------------------------------------------------------------
create table if not exists exercise_plate_setups (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid not null references clients(id),
  exercise_library_id uuid null references exercise_library(id),
  exercise_key        text not null,
  mode                text not null check (mode in ('bar','pin')),
  bar_kg              numeric null,
  plates              jsonb not null default '[]'::jsonb,   -- [{tier:'t20', unit:'kg'}, ...] por lado
  pin_position        int null,
  pin_stack_size      int not null default 12,
  pin_plate_weight    numeric null,
  weight_unit         text not null default 'kg' check (weight_unit in ('kg','lb')),
  total_kg            numeric null,
  updated_at          timestamptz not null default now(),
  constraint exercise_plate_setups_client_ex_uniq unique (client_id, exercise_key)
);

-- ---------------------------------------------------------------------
-- B · Solicitudes de asistencia (nunca se borran: open → resolved)
-- ---------------------------------------------------------------------
create table if not exists assistance_requests (
  id                  uuid primary key default gen_random_uuid(),
  client_id           uuid not null references clients(id),
  exercise_library_id uuid null references exercise_library(id),
  exercise_key        text not null,
  exercise_id         uuid null,          -- exercises.id de esa semana (referencia, sin FK)
  exercise_name       text not null,      -- snapshot
  plan_day_id         uuid null,
  week_number         int null,
  reason              text not null,
  detail              text null,
  last_load           jsonb null,
  status              text not null default 'open' check (status in ('open','resolved')),
  created_at          timestamptz not null default now(),
  resolved_at         timestamptz null
);

create index if not exists assistance_requests_status_idx
  on assistance_requests (status);
create index if not exists assistance_requests_client_status_idx
  on assistance_requests (client_id, status);

-- ---------------------------------------------------------------------
-- Verificación (solo lectura)
-- ---------------------------------------------------------------------
select table_name, column_name, data_type
from information_schema.columns
where table_name in ('exercise_notes','exercise_plate_setups','assistance_requests')
order by table_name, ordinal_position;

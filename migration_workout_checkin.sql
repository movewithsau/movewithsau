-- ============================================================================
-- MOVE · Check-in de entreno ("Entreno completado") · 27 oct 2026
-- Aditivo: una columna nueva en clients y una tabla nueva. No borra ni modifica
-- ningún dato existente. Correr en el SQL Editor de Supabase.
--
-- Tipos verificados en el código:
--   clients.id        uuid  (ver migration_bulk_swap_log.sql / migration_auto_week.sql)
--   monthly_plans.id  uuid  (plan_day_id, igual que migration_notes_plates_assist.sql)
-- RLS desactivado en el proyecto: no se agregan policies.
-- ============================================================================

-- 0) Verificación ANTES (anotá los números)
select count(*) as clientes from clients;
select to_regclass('public.workout_completions') as tabla_ya_existe; -- debe dar NULL

-- 1) Interruptor por cliente (apagado por defecto)
alter table clients
  add column if not exists quick_checkin_enabled boolean not null default false;

-- 2) Un check-in por cliente y día
create table if not exists workout_completions (
  id                uuid primary key default gen_random_uuid(),
  client_id         uuid not null references clients(id) on delete cascade, -- el app borra clientes: que esta tabla no lo trabe
  completed_date    date not null,               -- el día entrenado (fecha de Costa Rica)
  plan_day_id       uuid null,                   -- snapshot: monthly_plans.id del día que vio el cliente
  week_number       int  null,                   -- snapshot
  day_label         text null,                   -- snapshot: day_of_week del plan (ej. "Día 1")
  rating            int  not null check (rating between 1 and 10),
  did_all           boolean not null default true,
  skipped_exercises jsonb not null default '[]'::jsonb, -- [{ "id": "...", "name": "..." }]
  comment           text null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (client_id, completed_date)
);

create index if not exists workout_completions_client_date_idx
  on workout_completions (client_id, completed_date desc);

-- 3) Verificación DESPUÉS
select count(*) as clientes from clients;                                   -- mismo número que antes
select count(*) as con_checkin_activo from clients where quick_checkin_enabled; -- 0
select count(*) as checkins from workout_completions;                       -- 0
select column_name, data_type, column_default
  from information_schema.columns
 where table_name = 'workout_completions'
 order by ordinal_position;

-- ----------------------------------------------------------------------------
-- ROLLBACK (solo borra lo nuevo; descomentá si hace falta)
-- drop table if exists workout_completions;
-- alter table clients drop column if exists quick_checkin_enabled;
-- ----------------------------------------------------------------------------

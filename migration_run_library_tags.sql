-- Puente entre la biblioteca general de ejercicios y el módulo Run.
-- Aditivo: tabla nueva run_library_tags, no toca exercise_library ni run_exercises.
-- Permite marcar un ejercicio YA existente en la biblioteca general (ej. "Iso Lunge")
-- como pre-run/post-run/apoyo, sin duplicarlo en run_exercises.

-- 1) Verificación ANTES
select to_regclass('public.run_library_tags') as run_library_tags_existe; -- NULL

-- 2) Tabla nueva
create table if not exists run_library_tags (
  id               uuid primary key default gen_random_uuid(),
  coach_id         uuid not null,
  lib_exercise_id  uuid not null references exercise_library(id) on delete cascade,
  categories       text[] not null check (cardinality(categories) > 0 and categories <@ array['pre','post','apoyo']),
  created_at       timestamptz not null default now(),
  unique (coach_id, lib_exercise_id)
);
create index if not exists run_library_tags_coach_idx on run_library_tags (coach_id);

-- 3) Verificación DESPUÉS
select count(*) as run_library_tags_filas from run_library_tags; -- 0

-- ============================================================================
-- ROLLBACK (descomentá si hiciera falta)
-- drop table if exists run_library_tags;

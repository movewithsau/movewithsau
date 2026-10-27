-- ============================================================================
-- MOVE · Rating 1-10 de fin de entreno · 27 oct 2026
-- Aditivo: una tabla nueva. No toca workout_ratings (los emojis viejos quedan
-- como están, sin convertir ni rellenar).
--
-- Por qué tabla nueva y no una columna en workout_ratings: workout_ratings.rating
-- es text NOT NULL, así que una fila con solo la nota nueva fallaría, y cambiar
-- esa restricción sería modificar lo existente.
--
-- Una nota por cliente y día (fecha de Costa Rica, igual que el check-in):
-- calificar de nuevo el mismo día actualiza la fila.
-- Tipos verificados: clients.id uuid (ver migration_workout_checkin.sql).
-- RLS desactivado en el proyecto: no se agregan policies.
-- ============================================================================

-- 0) Verificación ANTES (anotá los números)
select count(*) as ratings_viejos from workout_ratings;
select to_regclass('public.workout_ratings_10') as tabla_ya_existe; -- debe dar NULL

-- 1) Tabla nueva
create table if not exists workout_ratings_10 (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references clients(id) on delete cascade, -- el app borra clientes: que esta tabla no lo trabe
  rated_date  date not null,                                         -- día del entreno (fecha de Costa Rica)
  rating_10   smallint not null check (rating_10 between 1 and 10),  -- "¿Cómo calificás este entreno?"
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (client_id, rated_date)
);

create index if not exists workout_ratings_10_client_date_idx
  on workout_ratings_10 (client_id, rated_date desc);

-- 2) Verificación DESPUÉS
select count(*) as ratings_viejos from workout_ratings;  -- mismo número que antes
select count(*) as ratings_10 from workout_ratings_10;   -- 0
select column_name, data_type, is_nullable, column_default
  from information_schema.columns
 where table_name = 'workout_ratings_10'
 order by ordinal_position;

-- ----------------------------------------------------------------------------
-- ROLLBACK (solo borra lo nuevo; descomentá si hace falta)
-- Ojo: borra las notas 1-10 que ya se hayan guardado. Respaldá antes:
--   create table workout_ratings_10_backup as select * from workout_ratings_10;
-- drop table if exists workout_ratings_10;
-- ----------------------------------------------------------------------------

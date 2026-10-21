-- =====================================================================
-- MOVE · Mi diario · Registros "solo el mes" (sin día)
-- Rama: feat/habit-fixes
--
-- ADITIVO: no borra ni modifica filas existentes.
--   1. Backup completo de diary_entries.
--   2. entry_date pasa a aceptar null (las filas actuales no cambian).
--   3. Columnas nuevas: is_historical (default false) y entry_month.
--   4. CHECK: o tiene día (normal) o es histórica con mes y sin día.
--   5. Índice para leer los sin día por cliente + mes.
-- RLS sigue deshabilitado: no se agregan policies.
-- Correr en el SQL Editor de Supabase, en orden, PASO por PASO.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASO 1 · Backup (correr solo y verificar que los dos números coincidan)
-- ---------------------------------------------------------------------
create table if not exists diary_entries_backup_20261021 as
  table diary_entries;

select
  (select count(*) from diary_entries)                 as filas_actuales,
  (select count(*) from diary_entries_backup_20261021) as filas_backup;


-- ---------------------------------------------------------------------
-- PASO 2 · Cambios aditivos
-- ---------------------------------------------------------------------
begin;

alter table diary_entries
  alter column entry_date drop not null;

alter table diary_entries
  add column if not exists is_historical boolean not null default false;

-- Mes de referencia: siempre el día 1 del mes (ej. 2026-10-01). Solo en filas históricas.
alter table diary_entries
  add column if not exists entry_month date;

-- Todas las filas actuales tienen entry_date y quedan con is_historical = false,
-- así que el CHECK valida sin tocar nada.
alter table diary_entries
  add constraint diary_entries_day_or_month_chk check (
    (is_historical = false and entry_date is not null)
    or
    (is_historical = true and entry_date is null and entry_month is not null
      and extract(day from entry_month) = 1)
  );

create index if not exists diary_entries_client_month_hist_idx
  on diary_entries (client_id, entry_month)
  where is_historical;

commit;


-- ---------------------------------------------------------------------
-- PASO 3 · Verificación (solo lectura)
-- ---------------------------------------------------------------------
-- select column_name, data_type, is_nullable, column_default
-- from information_schema.columns
-- where table_name = 'diary_entries'
--   and column_name in ('entry_date', 'is_historical', 'entry_month');
--
-- select count(*) as filas, count(*) filter (where is_historical) as historicas
-- from diary_entries;


-- ---------------------------------------------------------------------
-- ROLLBACK (solo si Sau lo pide; NO correr por defecto)
-- Antes de volver entry_date a NOT NULL hay que decidir qué hacer con las
-- filas históricas (no tienen día). Este bloque NO las borra: si existen,
-- el último alter falla y no cambia nada.
-- ---------------------------------------------------------------------
-- begin;
-- drop index if exists diary_entries_client_month_hist_idx;
-- alter table diary_entries drop constraint if exists diary_entries_day_or_month_chk;
-- alter table diary_entries alter column entry_date set not null;
-- commit;

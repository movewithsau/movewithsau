-- =====================================================================
-- MOVE · Mi diario · Migración de datos legacy
-- Correr DESPUÉS de mi-diario-schema.sql.
--
-- Copia:
--   habit_logs (+ habits)  -> diary_entries (kind='habit', source='coach')
--   sleep_logs             -> diary_sleep
--
-- Idempotente: se puede correr varias veces sin duplicar.
-- NO modifica ni borra habit_logs, habits ni sleep_logs.
-- Los registros migrados quedan sin emoción (emotion = null), a propósito.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PASO 0 · Reporte previo (solo lectura). Correlo solo para ver números.
-- ---------------------------------------------------------------------
-- select
--   (select count(*) from habit_logs)                                   as habit_logs_total,
--   (select count(*) from sleep_logs where sleep_end is null)           as sleep_abiertos_no_se_migran,
--   (select count(*) from sleep_logs
--      where sleep_end is not null
--        and coalesce(duration_minutes::numeric,
--                     extract(epoch from (sleep_end - sleep_start)) / 60.0) > 24 * 60)
--                                                                       as sleep_mas_de_24h_no_se_migran,
--   (select count(*) from sleep_logs
--      where sleep_end is not null
--        and coalesce(duration_minutes::numeric,
--                     extract(epoch from (sleep_end - sleep_start)) / 60.0) < 0)
--                                                                       as sleep_negativos_no_se_migran;


begin;

-- ---------------------------------------------------------------------
-- 1 · Hábitos: habit_logs -> diary_entries
-- ---------------------------------------------------------------------
-- entry_date: la app vieja guardaba completed_date en UTC (después de las
-- 6 pm en CR quedaba como el día siguiente). Se recalcula desde created_at
-- en hora de Costa Rica; si created_at viene null se usa completed_date.
insert into diary_entries (
  client_id, kind, entry_date, activity_name, option_id,
  source, source_ref, emotion,
  is_migrated, legacy_ref, created_at, updated_at
)
select
  hl.client_id,
  'habit',
  coalesce((hl.created_at at time zone 'America/Costa_Rica')::date, hl.completed_date),
  h.name,
  null,
  'coach',
  h.id::text,
  null,
  true,
  hl.id::text,
  coalesce(hl.created_at, now()),
  coalesce(hl.created_at, now())
from habit_logs hl
join habits h on h.id = hl.habit_id
where not exists (
  select 1 from diary_entries de
  where de.is_migrated = true
    and de.kind = 'habit'
    and de.legacy_ref = hl.id::text
)
on conflict do nothing;


-- ---------------------------------------------------------------------
-- 2 · Sueño: sleep_logs -> diary_sleep
-- ---------------------------------------------------------------------
-- sleep_date = día en que despertó (sleep_end en hora CR)
-- bedtime    = hora de sleep_start en CR · wake_time = hora de sleep_end en CR
-- hours      = duration_minutes / 60 (o desde los timestamps si es null)
-- Se excluyen: registros abiertos (sleep_end null), > 24 h y negativos.
-- Si hay varios el mismo día se queda el más largo.
with src as (
  select
    sl.client_id,
    (sl.sleep_end   at time zone 'America/Costa_Rica')::date as sleep_date,
    (sl.sleep_start at time zone 'America/Costa_Rica')::time as bedtime,
    (sl.sleep_end   at time zone 'America/Costa_Rica')::time as wake_time,
    coalesce(sl.duration_minutes::numeric,
             extract(epoch from (sl.sleep_end - sl.sleep_start)) / 60.0) as minutes,
    sl.created_at
  from sleep_logs sl
  where sl.sleep_end is not null
),
valid as (
  select * from src where minutes >= 0 and minutes <= 24 * 60
),
best as (
  select distinct on (client_id, sleep_date) *
  from valid
  order by client_id, sleep_date, minutes desc, created_at desc
)
insert into diary_sleep (
  client_id, sleep_date, bedtime, wake_time, hours,
  is_migrated, created_at, updated_at
)
select
  client_id, sleep_date, bedtime, wake_time,
  round(minutes / 60.0, 2),
  true,
  coalesce(created_at, now()),
  coalesce(created_at, now())
from best
on conflict (client_id, sleep_date) do nothing;

commit;


-- ---------------------------------------------------------------------
-- 3 · Verificación (solo lectura)
-- ---------------------------------------------------------------------
-- select
--   (select count(*) from diary_entries where is_migrated and kind = 'habit') as habitos_migrados,
--   (select count(*) from diary_sleep   where is_migrated)                    as suenos_migrados;

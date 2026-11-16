-- MOVE — Menú dinámico por semanas
-- Correr a mano en el SQL Editor de Supabase. Solo aditivo: no borra ni modifica datos.
--
-- nutrition_plans.week_number:
--   NULL = menú Base (lo que existe hoy; el cliente lo ve en toda semana sin menú propio)
--   N    = menú de la semana N del entreno del cliente
-- Todos los días de menú que ya existen quedan en NULL (Base), así nadie pierde su menú.

ALTER TABLE nutrition_plans ADD COLUMN IF NOT EXISTS week_number integer NULL;

CREATE INDEX IF NOT EXISTS nutrition_plans_client_week_idx
  ON nutrition_plans (client_id, week_number);

-- Verificación: todo debería salir en la fila "Base" (week_number vacío).
SELECT COALESCE(week_number::text, 'Base') AS semana, count(*) AS dias
FROM nutrition_plans GROUP BY week_number ORDER BY week_number NULLS FIRST;

-- Chequeo: si esta consulta devuelve alguna fila, la tabla tiene una regla de "un día por nombre"
-- que impide repetir "Lunes" en dos semanas. Si sale algo, avisale a Claude antes de usar semanas.
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'nutrition_plans'::regclass AND contype = 'u';

-- Rollback (solo la columna nueva; los días de semana N quedarían como Base):
-- DROP INDEX IF EXISTS nutrition_plans_client_week_idx;
-- ALTER TABLE nutrition_plans DROP COLUMN IF EXISTS week_number;

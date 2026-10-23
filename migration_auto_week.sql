-- MOVE — Semana automática, Evolution y semana completa
-- Correr a mano en el SQL Editor de Supabase. Solo aditivo: no borra ni modifica datos.
-- clients.id es UUID (confirmado en el Paso 0).

-- ============================================================
-- F1. Semana automática por fecha
-- ============================================================
-- week_mode: 'manual' (default, todo igual que antes) o 'auto' (la semana sale de la fecha).
-- program_week1_start: el domingo 8 p. m. (hora de Costa Rica) en que arranca la Semana 1.
ALTER TABLE clients ADD COLUMN IF NOT EXISTS week_mode text NOT NULL DEFAULT 'manual' CHECK (week_mode IN ('manual','auto'));
ALTER TABLE clients ADD COLUMN IF NOT EXISTS program_week1_start timestamptz NULL;

-- Verificación: todos deberían quedar en 'manual' hasta que Sau sincronice a alguien.
SELECT week_mode, count(*) AS clientes FROM clients GROUP BY week_mode ORDER BY week_mode;

-- Rollback (solo las 2 columnas nuevas, no toca ningún otro dato):
-- ALTER TABLE clients DROP COLUMN IF EXISTS program_week1_start;
-- ALTER TABLE clients DROP COLUMN IF EXISTS week_mode;

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

-- ============================================================
-- F3. Semana completa: el pop-up sale una sola vez por semana
-- ============================================================
-- week_start = inicio de la ventana de esa semana (domingo 8 p. m. CR). UNIQUE evita que se
-- repita en otro dispositivo o después de volver a sincronizar la fecha. Sin RLS.
CREATE TABLE IF NOT EXISTS week_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE, -- el app borra clientes: que esta tabla no lo trabe
  week_start timestamptz NOT NULL,
  week_label text,
  days_completed int,
  created_at timestamptz DEFAULT now(),
  UNIQUE (client_id, week_start)
);

-- Verificación: la tabla existe y arranca vacía.
SELECT count(*) AS semanas_completas FROM week_completions;

-- Rollback (solo esta tabla nueva):
-- DROP TABLE IF EXISTS week_completions;

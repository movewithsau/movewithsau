-- Ejercicios de Run como tags múltiples en vez de una sola categoría.
-- Aditivo: agrega run_exercises.categories, la rellena desde category (que no se toca ni se borra).
-- No toca exercise_library.

-- 1) Verificación ANTES
select count(*) as run_exercises_antes from run_exercises;

-- 2) Columna nueva
alter table run_exercises add column if not exists categories text[];

-- 3) Backfill: todo ejercicio existente conserva su categoría actual como su única tag
update run_exercises set categories = array[category] where categories is null;

-- 4) De acá en más, categories no puede quedar vacío ni tener valores fuera de pre/post/apoyo
alter table run_exercises alter column categories set not null;
alter table run_exercises add constraint run_exercises_categories_chk
  check (cardinality(categories) > 0 and categories <@ array['pre','post','apoyo']);

-- 5) Verificación DESPUÉS
select count(*) as run_exercises_despues from run_exercises;
select count(*) as sin_categories from run_exercises where categories is null or cardinality(categories) = 0; -- 0

-- ============================================================================
-- ROLLBACK (descomentá si hiciera falta)
-- alter table run_exercises drop constraint if exists run_exercises_categories_chk;
-- alter table run_exercises drop column if exists categories;

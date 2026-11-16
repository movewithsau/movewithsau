-- ============================================================================
-- MOVE · Run · categorizar biblioteca (pre/post/apoyo) + bloques por defecto
-- Adaptado al esquema REAL del repo (no al borrador original):
--   - La tabla de ejercicios es `exercise_library`, no `exercises`.
--   - No se tocan columnas de exercise_library. La categoría va en la tabla
--     puente `run_library_tags` (coach_id, lib_exercise_id, categories text[]).
--   - Se agrega una columna `subgroup` (nullable) a run_library_tags para guardar
--     el subgrupo (Movilidad dinámica, Activación, etc.) como dato de consulta.
--     No se construye UI para Apoyo; solo se guarda.
--   - Los bloques Pre/Post van en `run_routines` (ya existente), como bloques
--     POR DEFECTO (is_default=true) de cada tipo de salida, referenciando la
--     biblioteca general vía exercise_ids = [{"lib": "<uuid>"}, ...] EN ORDEN.
--   - 'umbral_intervalos' del borrador se mapea a 'umbral' (session_type real).
--   - coach_id NO se hardcodea: se busca en vivo a partir de un ejercicio que ya
--     está en tu biblioteca (226f9518-7859-4259-b680-7f1c5aa8e1e8, Leg Swings). Si ese
--     ejercicio no existe con ese id en tu exercise_library, el script frena con
--     una excepción en vez de insertar datos con un coach_id inventado.
-- Corré esto vos mismo en el SQL Editor de Supabase (no lo ejecuto yo).
-- ============================================================================

-- 0) Verificación ANTES
select count(*) as run_library_tags_antes from run_library_tags;
select count(*) as run_routines_antes from run_routines;

-- 1) Columna nueva, aditiva, solo en la tabla puente (no toca exercise_library)
alter table run_library_tags add column if not exists subgroup text;

-- 2) Único por (coach_id, session_type, block) mientras is_default: permite volver a
--    correr este script sin duplicar bloques por defecto.
create unique index if not exists run_routines_default_once_idx
  on run_routines (coach_id, session_type, block) where is_default;

-- 3) Todo en una transacción implícita (DO block): si algo falla, no se aplica nada a medias.
do $$
declare v_coach uuid;
begin
  select coach_id into v_coach from exercise_library where id = '226f9518-7859-4259-b680-7f1c5aa8e1e8';
  if v_coach is null then
    raise exception 'No se encontró el ejercicio ancla (% ) en exercise_library: revisá el id o pasá tu coach_id a mano antes de correr esto.', '226f9518-7859-4259-b680-7f1c5aa8e1e8';
  end if;

  -- Categorías: 186 ejercicios de tu biblioteca general, tageados para Run
  -- (una sola categoría por ejercicio, como decidiste)
  -- PRE / Activación (13)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '4b53d533-a300-4569-8ea4-64169b331b1e', array['pre'], 'Activación'), -- Abducción Lateral Acostado Banda
    (v_coach, '990e8984-1610-40b1-98df-9e7883b6f63b', array['pre'], 'Activación'), -- Abducción de Cadera Sentado con Banda
    (v_coach, 'f393bc47-f608-4e34-ab67-df2326cfeb42', array['pre'], 'Activación'), -- Abducción de Cadera en 4 Puntos (Banda)
    (v_coach, '38bb121b-0dc4-4550-900e-d5f03bd21ca7', array['pre'], 'Activación'), -- Acostado de lado Pierna trasera sube
    (v_coach, '48c221b6-966e-4095-a9ff-0ca06354e6d2', array['pre'], 'Activación'), -- Bird Dog
    (v_coach, 'aff22a15-5ddb-47c7-9af5-8a6973869700', array['pre'], 'Activación'), -- Caminata Lateral con Banda
    (v_coach, '72d22df7-b74c-4541-bc9c-a6c19b171521', array['pre'], 'Activación'), -- Clamshell con Banda
    (v_coach, 'd02c2fda-73d2-4f62-b0cd-9860e191dfa6', array['pre'], 'Activación'), -- Dead Bug
    (v_coach, '98146392-d3f3-4ec4-a241-221a963fa731', array['pre'], 'Activación'), -- Extensión de Cadera
    (v_coach, 'a883127e-afca-48f2-bb8a-691780918f04', array['pre'], 'Activación'), -- Frankenstein Walk
    (v_coach, '16e0288c-39ed-4af5-bfd6-55125acc48da', array['pre'], 'Activación'), -- Puente + Abducción de costado
    (v_coach, '10dc226f-4213-43f5-8c05-49b301c4df6a', array['pre'], 'Activación'), -- Puente de glúteos
    (v_coach, '7dd23ecb-33ff-46e2-8621-ba6dc743f6d4', array['pre'], 'Activación') -- Short Foot
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- PRE / Drills de carrera (6)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '40dcd6c7-c4f6-482b-b29b-007cd45ffaac', array['pre'], 'Drills de carrera'), -- Butt Kicks
    (v_coach, '0b54c84e-6401-4633-8a4f-dcc413a88980', array['pre'], 'Drills de carrera'), -- Carioca
    (v_coach, '71d6f677-5114-4995-85bd-faa7676b1501', array['pre'], 'Drills de carrera'), -- Pogos en Punta
    (v_coach, '1d851254-4178-4d97-92da-182983c89bc0', array['pre'], 'Drills de carrera'), -- Skipping Extendiendo Rodillas
    (v_coach, '2f9e4823-098d-44cb-979a-4ee872b94754', array['pre'], 'Drills de carrera'), -- Skipping Rodillas Altas
    (v_coach, '7003a178-e6c8-4eb7-8bdd-4c77df1ad7f3', array['pre'], 'Drills de carrera') -- Straight Leg Bound
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- PRE / Movilidad dinámica (21)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, 'e0084a0b-9a90-44fa-94ae-ae7744b4149e', array['pre'], 'Movilidad dinámica'), -- 90/90 Switch
    (v_coach, '53453d5a-4385-46b4-a947-9e9c5c6b1f7d', array['pre'], 'Movilidad dinámica'), -- 90/90 sentado a levantarse sobre Rodillas
    (v_coach, '2e40518b-82be-4abb-b8a7-a37f20bac45b', array['pre'], 'Movilidad dinámica'), -- Alcance Unilateral
    (v_coach, '18ce5c5c-2555-49d9-a91a-4459b5b7bf7d', array['pre'], 'Movilidad dinámica'), -- Apertura de Cadera de Pie
    (v_coach, '07311a82-c4fe-4f6e-bbd8-86daac0a31cc', array['pre'], 'Movilidad dinámica'), -- Apertura de Cadera en 4 puntos
    (v_coach, 'f42913c0-58df-46b0-8670-8aa79e7400b7', array['pre'], 'Movilidad dinámica'), -- Bisagra de Cadera
    (v_coach, '68f3d5a1-80da-4b3c-9fdb-d6b03e1ba106', array['pre'], 'Movilidad dinámica'), -- Caminata de Oso
    (v_coach, '1de3844e-e30d-4ecb-a33d-1cbe04096880', array['pre'], 'Movilidad dinámica'), -- Circulos de Cadera en 4 puntos
    (v_coach, 'ada212d7-37ff-48b5-ade4-00c93eb2b6d6', array['pre'], 'Movilidad dinámica'), -- Cossack Squat Alternando
    (v_coach, 'bd1a4834-83da-446a-9f65-f6d512cef50f', array['pre'], 'Movilidad dinámica'), -- Desplante con Rotación Torácica
    (v_coach, 'bc161993-9ed5-4db8-9ef8-d3a7d1327d17', array['pre'], 'Movilidad dinámica'), -- Dorsiflexión tobillo con banda
    (v_coach, 'caa3f185-9d8f-4844-8a6d-61d6171ecd94', array['pre'], 'Movilidad dinámica'), -- Escorpiones Dinámicos
    (v_coach, '73b845be-aca4-4b70-8910-dd16eb7baf60', array['pre'], 'Movilidad dinámica'), -- Flexor de Cadera Elevaciones
    (v_coach, '5a1c6c50-6adc-431e-b907-00d9f8c8b54d', array['pre'], 'Movilidad dinámica'), -- Gato Vaca
    (v_coach, '85ec1d75-ef35-4e2b-a2e5-1b716c0d3dd4', array['pre'], 'Movilidad dinámica'), -- Gusano
    (v_coach, '226f9518-7859-4259-b680-7f1c5aa8e1e8', array['pre'], 'Movilidad dinámica'), -- Leg Swings
    (v_coach, '68653f7f-389b-44da-bba7-ca7d13325338', array['pre'], 'Movilidad dinámica'), -- Movilidad de Tobillo en Pared
    (v_coach, '776248a4-7992-414d-a495-8973107a461b', array['pre'], 'Movilidad dinámica'), -- Pose de Rana Dinámica
    (v_coach, '744971b0-0cde-4f50-85a8-4f5541c1367a', array['pre'], 'Movilidad dinámica'), -- Scorpion Reach
    (v_coach, 'bffb96d6-704d-4d66-afe5-c4fd65ca9627', array['pre'], 'Movilidad dinámica'), -- World's Greatest Stretch
    (v_coach, '3aed3a6b-14b6-4225-913c-b9efbac8d17d', array['pre'], 'Movilidad dinámica') -- World's Greatest Stretch [Alternando de lado]
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- POST / Estiramiento y movilidad (22)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '265feb9e-2bae-45a1-bf61-8e448949da42', array['post'], 'Estiramiento y movilidad'), -- Apertura de Cadera Supino con banda
    (v_coach, 'c60a15b1-16f9-4bd5-9156-701072658e0e', array['post'], 'Estiramiento y movilidad'), -- Estiramiento de cuádriceps
    (v_coach, '21d2f109-8045-412d-a4b8-3753c005539d', array['post'], 'Estiramiento y movilidad'), -- Estiramiento en Desplante
    (v_coach, 'bbb89b6a-ee72-432d-b220-aa7af37974b6', array['post'], 'Estiramiento y movilidad'), -- Estiramiento en Figura de 4
    (v_coach, '8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd', array['post'], 'Estiramiento y movilidad'), -- Estiramiento para Isquios con Peso
    (v_coach, '8809cfcd-8716-41bd-830f-e89956061c41', array['post'], 'Estiramiento y movilidad'), -- Gluteos a Talones de Rodillas
    (v_coach, '6fcc52da-cb72-47c3-a30d-1f620bcdc670', array['post'], 'Estiramiento y movilidad'), -- Knee Hug a pecho en suelo
    (v_coach, 'f1fc3366-110e-4a35-9259-26a60c8fcdd8', array['post'], 'Estiramiento y movilidad'), -- Mariposa Sostenido
    (v_coach, '0c8848ba-b6bd-4609-b2fb-0fe5d8acbe54', array['post'], 'Estiramiento y movilidad'), -- Medio Split
    (v_coach, 'a51ad549-66e9-409a-88be-a4f26d7f1437', array['post'], 'Estiramiento y movilidad'), -- Perro hacia Abajo con Pedal
    (v_coach, 'd441d9b4-dea2-4400-8896-3fe555195162', array['post'], 'Estiramiento y movilidad'), -- Pliegue Frontal Alternando
    (v_coach, 'f2b60463-cb32-443e-b63a-a42f85b9eeff', array['post'], 'Estiramiento y movilidad'), -- Pliegue Frontal Sentado
    (v_coach, '88d08197-2e86-4777-879c-15b91a78b85e', array['post'], 'Estiramiento y movilidad'), -- Pose de Cobra
    (v_coach, 'fd7668a6-5c19-4b4b-9279-dbe0f82fde18', array['post'], 'Estiramiento y movilidad'), -- Pose de Esfinge
    (v_coach, '4c84696d-4cd7-4d26-8dd0-920f2801e1d4', array['post'], 'Estiramiento y movilidad'), -- Pose de paloma
    (v_coach, '4efdfd95-69af-48e8-99c3-9f02a7e8aba7', array['post'], 'Estiramiento y movilidad'), -- Pose del Grillo
    (v_coach, '7d6c4018-93f4-48ab-9aad-a13c9cbd15e7', array['post'], 'Estiramiento y movilidad'), -- Pose del niño + alcance lateral
    (v_coach, 'b6112368-1e23-4946-991c-72b4116c3297', array['post'], 'Estiramiento y movilidad'), -- Rock de Aductor
    (v_coach, '8a344d06-5d75-4d7c-8f96-0c1047c88bbf', array['post'], 'Estiramiento y movilidad'), -- Standing Hip Flexor
    (v_coach, '840a92bb-2780-4c63-8e62-e72671dda41d', array['post'], 'Estiramiento y movilidad'), -- Thread the Needle
    (v_coach, '9767988a-ea08-48b3-a686-43c9d17ac2db', array['post'], 'Estiramiento y movilidad'), -- Torsión Dorsal
    (v_coach, 'c122b12c-ffcb-464e-ac52-82a566a4ddcd', array['post'], 'Estiramiento y movilidad') -- Vakrasana
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- POST / Respiración y recuperación (5)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '7c4675b6-97dd-4b67-aee9-58a6f5e42bae', array['post'], 'Respiración y recuperación'), -- Meditación
    (v_coach, '7b30a96a-a59c-4784-821a-3bf83b5d89f3', array['post'], 'Respiración y recuperación'), -- Respiración 4-2-8-2
    (v_coach, 'ef142989-a8a4-41a8-9edd-4c21e37dbcd2', array['post'], 'Respiración y recuperación'), -- Respiración 4-7-8
    (v_coach, '2b789e47-050c-4dc5-b046-c57d1643b9c5', array['post'], 'Respiración y recuperación'), -- Respiración en 3
    (v_coach, '730aac77-f787-46df-a97f-8a9d765ef216', array['post'], 'Respiración y recuperación') -- Yoga Nidra
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Cadera y glúteo (23)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '9eba8532-8765-48b0-8f06-922b7e262dd8', array['apoyo'], 'Cadera y glúteo'), -- Abducción de Cadera de Pie en Maquina
    (v_coach, '73bb4b3a-bd5a-4b9a-a33b-8d7a88c7fea4', array['apoyo'], 'Cadera y glúteo'), -- Abducción de Cadera en Maquina
    (v_coach, 'a40f7c28-b92e-4016-9ad1-0032af0ce07f', array['apoyo'], 'Cadera y glúteo'), -- Aductor en Máquina
    (v_coach, '880cbc07-1622-41b0-8cf8-cb1cb7cefa43', array['apoyo'], 'Cadera y glúteo'), -- Buenos Días con Mancuerna
    (v_coach, '46b429e0-1c7a-42ea-9489-49d309a93b04', array['apoyo'], 'Cadera y glúteo'), -- Copenhagen Plank Dinámica pierna extendida
    (v_coach, '28f1df07-c605-4d5e-b89e-90a3c896ceb4', array['apoyo'], 'Cadera y glúteo'), -- Copenhagen Plank Isométrico
    (v_coach, '17893843-02bd-4208-8f08-087506f2c947', array['apoyo'], 'Cadera y glúteo'), -- Copenhagen raises
    (v_coach, '327aed3b-0b97-4767-b27e-24edd3e4a995', array['apoyo'], 'Cadera y glúteo'), -- Elevación lateral de pierna de Pie con Disco
    (v_coach, 'd0655e5a-3cf8-45c1-be9e-2682de37bc6b', array['apoyo'], 'Cadera y glúteo'), -- Hip Thrust UNILATERAL
    (v_coach, 'd6bd8279-0b28-49cd-8a86-0d00cac16de7', array['apoyo'], 'Cadera y glúteo'), -- Hip Thrust con Barra
    (v_coach, '70159615-d124-40a0-bc22-bc083adeeea0', array['apoyo'], 'Cadera y glúteo'), -- Hip Thrust en Máquina
    (v_coach, '9f03dae8-9bbf-4e70-b6ad-ac70ee13ce12', array['apoyo'], 'Cadera y glúteo'), -- Hip thrust con Mancuerna
    (v_coach, '2c859705-02d7-4ea4-8e13-7c0c345daa37', array['apoyo'], 'Cadera y glúteo'), -- Hip thrust en Smith
    (v_coach, 'dba0e5bb-a389-4843-b594-a54fb9cd07f7', array['apoyo'], 'Cadera y glúteo'), -- Kettlebell Swing
    (v_coach, 'b6cb49b9-61dd-4ad0-8234-1212844007e4', array['apoyo'], 'Cadera y glúteo'), -- Patada Lateral en Polea baja
    (v_coach, 'd498119e-ecbf-4a13-b717-9dad47b10060', array['apoyo'], 'Cadera y glúteo'), -- Patada de Glúteo en Máquina Arrodillado
    (v_coach, '642f7a19-4550-4885-8c6a-47f5f1db512d', array['apoyo'], 'Cadera y glúteo'), -- Patada de Glúteo en Máquina de Pie
    (v_coach, '7efd4c1a-8de7-4c64-affd-30dbead07ccd', array['apoyo'], 'Cadera y glúteo'), -- Patada de Glúteo en Polea
    (v_coach, 'd919c1dd-9744-4577-bfeb-682901e72187', array['apoyo'], 'Cadera y glúteo'), -- Plancha lateral + Abducción de Cadera
    (v_coach, '8f0c4324-06a9-48bf-b9ee-a0681e57ba90', array['apoyo'], 'Cadera y glúteo'), -- Puente de glúteos + HOLD
    (v_coach, 'da505c38-67c4-41c0-8af6-e6f4853d9716', array['apoyo'], 'Cadera y glúteo'), -- Puente de glúteos con Mancuerna
    (v_coach, '824da285-e19a-46fd-bb2e-c6c170578f34', array['apoyo'], 'Cadera y glúteo'), -- Step-Up con Mancuerna en una Mano
    (v_coach, '402cdc97-8469-4140-9e7d-006fae025c8a', array['apoyo'], 'Cadera y glúteo') -- Sumo squat con Mancuerna
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Core y estabilidad (18)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '9765f2fa-d8e7-47c6-89b7-c903ca222120', array['apoyo'], 'Core y estabilidad'), -- Bear Plank Toca Hombros
    (v_coach, '7fd15e38-65b8-4e62-a5f5-f904c9a49a12', array['apoyo'], 'Core y estabilidad'), -- Elevación de Piernas Acostado
    (v_coach, '6af082c3-8f54-4f7d-880a-6ceda55c4774', array['apoyo'], 'Core y estabilidad'), -- Hollow Hold
    (v_coach, '9ca748c7-6aba-4a35-aee6-fe24390d73c7', array['apoyo'], 'Core y estabilidad'), -- Levantamiento de Piernas Acostado
    (v_coach, '831c972d-0c12-4184-bd85-1b5dda4c5094', array['apoyo'], 'Core y estabilidad'), -- Levantamiento de Piernas Colgado
    (v_coach, '65b0c656-bd56-45fd-ac4d-957056e2048b', array['apoyo'], 'Core y estabilidad'), -- Levantamiento de piernas sobre obstaculo
    (v_coach, '4a829d65-6bfb-4235-bdbc-88b1baa29726', array['apoyo'], 'Core y estabilidad'), -- Pallof Press con Banda
    (v_coach, 'ac8521f7-452c-4362-b389-f7b1dd186562', array['apoyo'], 'Core y estabilidad'), -- Pallof Press en Polea
    (v_coach, 'c107a4b1-e785-4f16-9eab-15a177c05c63', array['apoyo'], 'Core y estabilidad'), -- Plancha + alcance
    (v_coach, '88ef79c0-5c04-4853-9df1-db912ccdd16a', array['apoyo'], 'Core y estabilidad'), -- Plancha Lateral con Rotación con Mancuerna
    (v_coach, '7685c91d-12a8-4885-85a2-4430c3d74225', array['apoyo'], 'Core y estabilidad'), -- Plancha en antebrazos
    (v_coach, '6da71001-b48e-4db0-9cab-30a4312e3c48', array['apoyo'], 'Core y estabilidad'), -- Plancha inversa
    (v_coach, '35e7c9ae-b158-472f-aede-6b621ab74be4', array['apoyo'], 'Core y estabilidad'), -- Pose de Langosta
    (v_coach, '7276f1b6-d9c1-4cfb-9463-5518eb02c1d1', array['apoyo'], 'Core y estabilidad'), -- Puente en 3 Puntos + Alcance
    (v_coach, 'a8fcd7e0-6d6b-4216-8097-d9f75bc7ed5e', array['apoyo'], 'Core y estabilidad'), -- Puente en 3 Puntos + Alcance RÁPIDO
    (v_coach, '4cfc4fd5-ce90-47aa-91c3-f3043b3d039c', array['apoyo'], 'Core y estabilidad'), -- Rueda Abdominal
    (v_coach, 'f2222760-0e3a-4923-b00f-f1365fd16218', array['apoyo'], 'Core y estabilidad'), -- Suitcase Hold estático Mancuerna
    (v_coach, '263858b2-cdc2-4030-925f-21132a3a88e5', array['apoyo'], 'Core y estabilidad') -- Superman Alternando
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Cross-training (6)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '1ba34c9c-7b48-4705-b592-4ba0d82f79f5', array['apoyo'], 'Cross-training'), -- Airbike HIIT
    (v_coach, 'e5d1de06-be69-4075-8888-d2ff1d07a8b0', array['apoyo'], 'Cross-training'), -- Bici estática
    (v_coach, '000818db-d8cf-489f-8f5a-5d4bfb2d915f', array['apoyo'], 'Cross-training'), -- Caminata Inclinada
    (v_coach, '8155eacd-c97f-42e5-b393-cb7d2c10b3fe', array['apoyo'], 'Cross-training'), -- Gradas Estáticas
    (v_coach, '4430d8be-e042-4f19-b5a2-7bb66931a7a5', array['apoyo'], 'Cross-training'), -- Remo Cardio
    (v_coach, 'd31a783f-597c-4704-924a-dd989a256675', array['apoyo'], 'Cross-training') -- SWIM Libre
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Equilibrio (4)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, 'e9c07a92-7d69-4bd2-8277-80f785599d7c', array['apoyo'], 'Equilibrio'), -- Balance Unipodal Piso a Superficie Inestable
    (v_coach, '74676b1a-7ae8-4e4d-885c-b50c73058a3f', array['apoyo'], 'Equilibrio'), -- Balance Unipodal con Alcance
    (v_coach, 'ea87626e-1473-4bb4-b760-07b60aad34c5', array['apoyo'], 'Equilibrio'), -- Balance Unipodal con Perturbación
    (v_coach, 'c51cfcc2-5a15-453e-8922-670fe197e2dc', array['apoyo'], 'Equilibrio') -- Single Leg Balance con ojos cerrados
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Pantorrilla y pie (10)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '01d1b479-f166-4f08-b814-d2141b2ddfac', array['apoyo'], 'Pantorrilla y pie'), -- Bent knee calf raises
    (v_coach, 'ec97a8cd-39bd-4a5d-bee0-2ed1ddd1f435', array['apoyo'], 'Pantorrilla y pie'), -- Bent-knee calf raises en step
    (v_coach, '0d0a4c9f-1418-42e1-9c51-dcdfe83bd963', array['apoyo'], 'Pantorrilla y pie'), -- Elevación Pantorilla en 1 Pierna
    (v_coach, '35684a31-9d71-4272-981a-4d7ab0ccafd7', array['apoyo'], 'Pantorrilla y pie'), -- Elevación de Pantorillas Sentado
    (v_coach, '0624f6ea-396f-4e82-a4eb-d06418e74385', array['apoyo'], 'Pantorrilla y pie'), -- Elevación de Pantorillas en Step
    (v_coach, '38193a84-3087-4ce3-ad44-33de0f687499', array['apoyo'], 'Pantorrilla y pie'), -- Elevación de Talones Sentado
    (v_coach, '93d9767d-3e80-4775-9a94-00adeaaebcf6', array['apoyo'], 'Pantorrilla y pie'), -- Eversión/Inversión de Tobillo con Banda
    (v_coach, 'd2da8aad-eb8a-40e3-81df-e4624bf89d2d', array['apoyo'], 'Pantorrilla y pie'), -- Extension Pantorilla en Smith con Step
    (v_coach, '86209c4e-1ccd-4949-bf88-8f0d206be7db', array['apoyo'], 'Pantorrilla y pie'), -- Extension de Pantorilla en Prensa
    (v_coach, '34f5f474-fe7e-4f0f-a136-0b10d45d0142', array['apoyo'], 'Pantorrilla y pie') -- Tibia + Pantorilla con Mancuernas
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Pierna (cuádriceps, isquios, unilateral) (40)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '5287ba5d-e2d5-45c8-a230-ad934a3eaed1', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Curl Nórdico Invertido
    (v_coach, 'edd32f8b-a7dc-4c35-a33e-b9c6e34c3f55', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Curl Nórdico Negativo (5 seg caída controlada)
    (v_coach, 'e4626d7f-f262-45fd-809c-243ce7955608', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Desplante Hacia Atrás estacionario
    (v_coach, '574d3c63-d399-4256-8a1a-fb5d3d8c3d54', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Desplante Hacia Atrás estacionario (alternando)
    (v_coach, '97babe40-9ec6-4590-abf3-61c7d60666c4', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Desplante con apoyo dinámico
    (v_coach, '90a06dbb-7910-4722-9e53-06b5238b0288', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Desplante en Smith
    (v_coach, '5b972f3e-f195-4b19-a018-81f8485d8bb4', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Desplantes Caminata con Mancuernas
    (v_coach, '46c37407-1fae-4588-9966-d166820047e0', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Extensión de Rodilla Sentado en Máquina
    (v_coach, '7e2b1a2b-7012-41b8-8537-a210dce98e2e', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Extensión de rodilla sentado en Máquina UNILATERAL
    (v_coach, '032acf3f-2e01-4c70-8c68-396e1fcd264f', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Flexion de Rodilla sentado en Máquina
    (v_coach, 'e4dc1698-7dea-48cf-b7b6-d1237ac816bc', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Flexion de Rodilla sentado en Máquina UNILATERAL
    (v_coach, '0ef23385-bcfd-4aa6-acd5-a26053a9bf88', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Flexión de Rodilla Acostado en Máquina
    (v_coach, 'df514681-03aa-42ae-ae1a-693d12c289e7', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Flexión de Rodilla Acostado en Máquina UNILATERAL
    (v_coach, '546a5b0f-e0ca-437c-b0f9-f4ae9f8267cb', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Flexión de Rodilla de Pie Unilateral
    (v_coach, '89216ae4-199b-44c8-98d2-d27b71dc5f79', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Goblet Squat con Mancuerna
    (v_coach, '3e673662-b4a4-4e3d-99f6-d3d48f8a29f6', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Goblet Squat con Mancuerna PROFUNDO
    (v_coach, 'f24161fb-21a5-4e1a-8e2b-c25820a621a7', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Hack Squat
    (v_coach, '0525b271-dfdc-4b18-b571-f306e873228e', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Heel elevated iso lunge hold
    (v_coach, '3c30dd06-7213-44eb-afa6-513f51e6711b', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Jalón Supino para Isquios
    (v_coach, '21e4e2cc-32ba-47fb-a1f9-63a8e17d89a6', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Peso Muerto Rumano 1 Pierna Apoyado con Mancuernas
    (v_coach, 'b30ce92b-6f68-42f9-951c-e3ba530c04db', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Peso Muerto Rumano con Mancuernas
    (v_coach, 'f1e5ae5e-ce66-4cfb-bb34-b09db2752472', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Peterson Step Up
    (v_coach, 'a455cd46-f620-4780-8043-4aef66a0a6fb', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Plate Skater Squat
    (v_coach, '4eb85868-4e5a-4f3c-9607-8a6750f301db', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Prensa de Pierna 45°
    (v_coach, '856bf003-8cb5-4922-b1b9-c8062deb22f3', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Prensa de pierna horizontal
    (v_coach, 'fd8124cf-efcc-49ed-8b66-d8f3aaf3f98c', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Press de Pierna Cerrado
    (v_coach, 'f2d46547-cdf9-492f-8f08-864e880e86fd', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Raspados Alternando Piernas
    (v_coach, '5fdd2582-3555-4abe-87fc-3bdd4434917e', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla Bulgara con Mancuernas
    (v_coach, '8793d1f7-5b67-4c2a-ba1e-d64ce3e3af74', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla Búlgara Isométrica Hold
    (v_coach, '383db3b7-6d5b-459b-9b8b-2e220afecd2b', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla Búlgara en Smith
    (v_coach, '5fce75be-a956-4af1-844f-960813b83ad7', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla Isométrica (Banda)
    (v_coach, 'baede1b6-73c8-422a-8808-0244674fa8da', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla con Banda
    (v_coach, '527f0222-f902-4147-a646-93199269a096', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla con Barra Libre
    (v_coach, '2bb19c68-25de-4416-b87e-d2bfe008f3ca', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla con Pausa 3seg Abajo
    (v_coach, '0c7012f5-a18c-4859-90d5-29f22a4912d0', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Sentadilla en Smith
    (v_coach, '9818a117-7d3f-48ab-a932-44a0b03df5cf', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Split Squat con Barra
    (v_coach, 'bf53c632-c10b-4fe9-b3be-09a59b1ba3e8', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Step Down Individual
    (v_coach, '7e8c13f3-206a-4ba8-9649-23232d3eaa5c', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Terminal Knee Extension
    (v_coach, '975bec0a-01be-4248-bef3-547672e36956', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)'), -- Wall Sit Isométrico
    (v_coach, 'd65ba772-4cc8-4691-9204-92383e67cdc4', array['apoyo'], 'Pierna (cuádriceps, isquios, unilateral)') -- Wall Sit con Banda
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Pliometría y potencia (13)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '506fb20f-c227-43bc-b176-74a83e20d4b3', array['apoyo'], 'Pliometría y potencia'), -- Goblet Squat + Salto con Mancuerna
    (v_coach, '06036c80-7ebd-41da-bcf8-90acc317cc1a', array['apoyo'], 'Pliometría y potencia'), -- Lateral Bound
    (v_coach, '81cd2685-54de-4853-be47-0f9bef11fc97', array['apoyo'], 'Pliometría y potencia'), -- Plate Skater
    (v_coach, 'b12de61e-5a87-43d6-be14-ead3463b973a', array['apoyo'], 'Pliometría y potencia'), -- Plate U Jumps
    (v_coach, 'cd40ed75-38da-4df7-a8c7-8d6a0dcbcc7c', array['apoyo'], 'Pliometría y potencia'), -- Salto al Cajón
    (v_coach, 'a5c58b97-5bed-49d3-99a2-2e1115bcc759', array['apoyo'], 'Pliometría y potencia'), -- Salto con cuerda
    (v_coach, '36d17dac-048f-410a-9054-007f774b22d7', array['apoyo'], 'Pliometría y potencia'), -- Salto de rodillas
    (v_coach, 'd186b7b6-78b4-4498-b584-3a943b650612', array['apoyo'], 'Pliometría y potencia'), -- Salto largo horizontal
    (v_coach, 'c007bcd2-7ea0-4a87-b907-e72b2e2d6b9b', array['apoyo'], 'Pliometría y potencia'), -- Sentadilla con Salto
    (v_coach, '151fc8d2-f460-4c64-9a3f-085106f99f39', array['apoyo'], 'Pliometría y potencia'), -- Single Leg Hop
    (v_coach, 'd7f235bd-dd32-4863-96ff-032016d2f642', array['apoyo'], 'Pliometría y potencia'), -- Suiza Alternando Pies
    (v_coach, 'a9340080-0be7-4750-ac08-3c72f676a53a', array['apoyo'], 'Pliometría y potencia'), -- Suiza Salto Básico
    (v_coach, '5371ed45-fb25-44c7-b9d7-59fcf47d110c', array['apoyo'], 'Pliometría y potencia') -- Wall Run
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- APOYO / Tibia (5)
  insert into run_library_tags (coach_id, lib_exercise_id, categories, subgroup) values
    (v_coach, '64676420-d4b2-4072-9f8f-03b458dd6247', array['apoyo'], 'Tibia'), -- Elevaciones de Tibia en Pared
    (v_coach, '334d3e3b-54fb-4c97-93dc-241402d68f6c', array['apoyo'], 'Tibia'), -- Elevación de Tibias Sentado
    (v_coach, '9dae05b3-5188-4cb9-8ab4-70ba23bb695c', array['apoyo'], 'Tibia'), -- Elevación de Tibias con Disco
    (v_coach, '4d39215b-19cb-449b-ac0c-e27a6c7411d5', array['apoyo'], 'Tibia'), -- Elevación de Tibias en Máquina
    (v_coach, '9e9a58ec-d185-4046-914f-385e68fd76d2', array['apoyo'], 'Tibia') -- Flexión de Puntas de Pies con Mancuerna
  on conflict (coach_id, lib_exercise_id) do update set categories = excluded.categories, subgroup = excluded.subgroup;

  -- Bloques por defecto (pre/post) de cada tipo de salida
  -- Correr y caminar · pre (4 ejercicios): Leg Swings, Puente de glúteos, Clamshell con Banda, Movilidad de Tobillo en Pared
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'correr_caminar', 'pre', 'Pre correr y caminar', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "10dc226f-4213-43f5-8c05-49b301c4df6a"}, {"lib": "72d22df7-b74c-4541-bc9c-a6c19b171521"}, {"lib": "68653f7f-389b-44da-bba7-ca7d13325338"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Correr y caminar · post (4 ejercicios): Estiramiento de cuádriceps, Estiramiento en Figura de 4, Perro hacia Abajo con Pedal, Respiración en 3
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'correr_caminar', 'post', 'Post correr y caminar', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "a51ad549-66e9-409a-88be-a4f26d7f1437"}, {"lib": "2b789e47-050c-4dc5-b046-c57d1643b9c5"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Fácil · pre (4 ejercicios): Leg Swings, Apertura de Cadera en 4 puntos, Puente de glúteos, Short Foot
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'facil', 'pre', 'Pre fácil', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "07311a82-c4fe-4f6e-bbd8-86daac0a31cc"}, {"lib": "10dc226f-4213-43f5-8c05-49b301c4df6a"}, {"lib": "7dd23ecb-33ff-46e2-8621-ba6dc743f6d4"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Fácil · post (4 ejercicios): Estiramiento de cuádriceps, Estiramiento en Figura de 4, Estiramiento en Desplante, Respiración 4-7-8
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'facil', 'post', 'Post fácil', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "21d2f109-8045-412d-a4b8-3753c005539d"}, {"lib": "ef142989-a8a4-41a8-9edd-4c21e37dbcd2"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Larga fácil · pre (5 ejercicios): Leg Swings, Gato Vaca, Puente de glúteos, Caminata Lateral con Banda, Movilidad de Tobillo en Pared
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'larga_facil', 'pre', 'Pre larga fácil', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "5a1c6c50-6adc-431e-b907-00d9f8c8b54d"}, {"lib": "10dc226f-4213-43f5-8c05-49b301c4df6a"}, {"lib": "aff22a15-5ddb-47c7-9af5-8a6973869700"}, {"lib": "68653f7f-389b-44da-bba7-ca7d13325338"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Larga fácil · post (7 ejercicios): Estiramiento de cuádriceps, Estiramiento en Figura de 4, Estiramiento en Desplante, Estiramiento para Isquios con Peso, Perro hacia Abajo con Pedal, Pose de paloma, Respiración 4-7-8
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'larga_facil', 'post', 'Post larga fácil', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "21d2f109-8045-412d-a4b8-3753c005539d"}, {"lib": "8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd"}, {"lib": "a51ad549-66e9-409a-88be-a4f26d7f1437"}, {"lib": "4c84696d-4cd7-4d26-8dd0-920f2801e1d4"}, {"lib": "ef142989-a8a4-41a8-9edd-4c21e37dbcd2"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Strides · pre (6 ejercicios): Leg Swings, World's Greatest Stretch, Butt Kicks, Skipping Rodillas Altas, Carioca, Pogos en Punta
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'strides', 'pre', 'Pre strides', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "bffb96d6-704d-4d66-afe5-c4fd65ca9627"}, {"lib": "40dcd6c7-c4f6-482b-b29b-007cd45ffaac"}, {"lib": "2f9e4823-098d-44cb-979a-4ee872b94754"}, {"lib": "0b54c84e-6401-4633-8a4f-dcc413a88980"}, {"lib": "71d6f677-5114-4995-85bd-faa7676b1501"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Strides · post (4 ejercicios): Estiramiento de cuádriceps, Estiramiento para Isquios con Peso, Estiramiento en Figura de 4, Respiración 4-2-8-2
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'strides', 'post', 'Post strides', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "7b30a96a-a59c-4784-821a-3bf83b5d89f3"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Umbral e intervalos · pre (8 ejercicios): Leg Swings, World's Greatest Stretch, Puente de glúteos, Caminata Lateral con Banda, Butt Kicks, Skipping Rodillas Altas, Skipping Extendiendo Rodillas, Pogos en Punta
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'umbral', 'pre', 'Pre umbral e intervalos', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "bffb96d6-704d-4d66-afe5-c4fd65ca9627"}, {"lib": "10dc226f-4213-43f5-8c05-49b301c4df6a"}, {"lib": "aff22a15-5ddb-47c7-9af5-8a6973869700"}, {"lib": "40dcd6c7-c4f6-482b-b29b-007cd45ffaac"}, {"lib": "2f9e4823-098d-44cb-979a-4ee872b94754"}, {"lib": "1d851254-4178-4d97-92da-182983c89bc0"}, {"lib": "71d6f677-5114-4995-85bd-faa7676b1501"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Umbral e intervalos · post (6 ejercicios): Estiramiento de cuádriceps, Estiramiento para Isquios con Peso, Estiramiento en Figura de 4, Estiramiento en Desplante, Perro hacia Abajo con Pedal, Respiración 4-2-8-2
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'umbral', 'post', 'Post umbral e intervalos', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "21d2f109-8045-412d-a4b8-3753c005539d"}, {"lib": "a51ad549-66e9-409a-88be-a4f26d7f1437"}, {"lib": "7b30a96a-a59c-4784-821a-3bf83b5d89f3"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Prueba 5K · pre (7 ejercicios): Leg Swings, World's Greatest Stretch, Bisagra de Cadera, Butt Kicks, Skipping Rodillas Altas, Carioca, Pogos en Punta
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'prueba_5k', 'pre', 'Pre prueba 5k', '[{"lib": "226f9518-7859-4259-b680-7f1c5aa8e1e8"}, {"lib": "bffb96d6-704d-4d66-afe5-c4fd65ca9627"}, {"lib": "f42913c0-58df-46b0-8670-8aa79e7400b7"}, {"lib": "40dcd6c7-c4f6-482b-b29b-007cd45ffaac"}, {"lib": "2f9e4823-098d-44cb-979a-4ee872b94754"}, {"lib": "0b54c84e-6401-4633-8a4f-dcc413a88980"}, {"lib": "71d6f677-5114-4995-85bd-faa7676b1501"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

  -- Prueba 5K · post (7 ejercicios): Estiramiento de cuádriceps, Estiramiento para Isquios con Peso, Estiramiento en Figura de 4, Estiramiento en Desplante, Pose de paloma, Perro hacia Abajo con Pedal, Respiración 4-2-8-2
  insert into run_routines (coach_id, session_type, block, name, exercise_ids, is_default) values
    (v_coach, 'prueba_5k', 'post', 'Post prueba 5k', '[{"lib": "c60a15b1-16f9-4bd5-9156-701072658e0e"}, {"lib": "8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd"}, {"lib": "bbb89b6a-ee72-432d-b220-aa7af37974b6"}, {"lib": "21d2f109-8045-412d-a4b8-3753c005539d"}, {"lib": "4c84696d-4cd7-4d26-8dd0-920f2801e1d4"}, {"lib": "a51ad549-66e9-409a-88be-a4f26d7f1437"}, {"lib": "7b30a96a-a59c-4784-821a-3bf83b5d89f3"}]'::jsonb, true)
  on conflict (coach_id, session_type, block) where is_default
    do update set name = excluded.name, exercise_ids = excluded.exercise_ids;

end $$;

-- 4) Verificación DESPUÉS
select count(*) as run_library_tags_despues from run_library_tags;
select categories, subgroup, count(*) from run_library_tags group by categories, subgroup order by 1,2;
select session_type, block, name, jsonb_array_length(exercise_ids) as n_ejercicios from run_routines where is_default order by session_type, block;

-- 5) Chequeo de integridad: ningún lib_exercise_id de run_library_tags ni ningún
--    {"lib":...} de run_routines debe apuntar a un id inexistente en exercise_library
--    (debería devolver 0 filas en ambas)
select lib_exercise_id from run_library_tags lt
  where not exists (select 1 from exercise_library el where el.id = lt.lib_exercise_id);
select r.id as routine_id, r.name, x.item->>'lib' as lib_id
  from run_routines r, jsonb_array_elements(r.exercise_ids) x(item)
  where x.item ? 'lib'
    and not exists (select 1 from exercise_library el where el.id = (x.item->>'lib')::uuid);

-- ============================================================================
-- CÓMO DESHACER DESPUÉS, SIN TOCAR SQL
-- ============================================================================
-- Quitar UN ejercicio de Run (le saca el tag; sigue en tu biblioteca general):
--   Coach → Biblioteca → filtro Run → tocá el ícono de la papelera junto al ejercicio
--   ("tu biblioteca") → "Quitar de Run". Es rnLibTagRemove() en index.html.
-- Editar o borrar UN bloque (quita o reordena ejercicios, o lo elimina entero):
--   Coach → Biblioteca → sección "Bloques" o "Bloques por tipo de sesión" → Editar
--   → "Eliminar bloque". Es rnBlockForm()/rnBlockDelete() en index.html.
-- Ambas ya existen en la app: no hace falta código nuevo ni SQL para ajustes puntuales.

-- ============================================================================
-- ROLLBACK COMPLETO (deshace TODO lo que agregó este script; descomentá si hiciera falta)
-- Borra exactamente los 186 tags y los 12 bloques por defecto de este script,
-- nada más (no toca bloques con nombre que hayas creado vos a mano).
-- ============================================================================
-- do $$
-- declare v_coach uuid;
-- begin
--   select coach_id into v_coach from exercise_library where id = '226f9518-7859-4259-b680-7f1c5aa8e1e8';
--   delete from run_library_tags where coach_id = v_coach and lib_exercise_id in (
--     '4b53d533-a300-4569-8ea4-64169b331b1e',
--     '990e8984-1610-40b1-98df-9e7883b6f63b',
--     'f393bc47-f608-4e34-ab67-df2326cfeb42',
--     '38bb121b-0dc4-4550-900e-d5f03bd21ca7',
--     '48c221b6-966e-4095-a9ff-0ca06354e6d2',
--     'aff22a15-5ddb-47c7-9af5-8a6973869700',
--     '72d22df7-b74c-4541-bc9c-a6c19b171521',
--     'd02c2fda-73d2-4f62-b0cd-9860e191dfa6',
--     '98146392-d3f3-4ec4-a241-221a963fa731',
--     'a883127e-afca-48f2-bb8a-691780918f04',
--     '16e0288c-39ed-4af5-bfd6-55125acc48da',
--     '10dc226f-4213-43f5-8c05-49b301c4df6a',
--     '7dd23ecb-33ff-46e2-8621-ba6dc743f6d4',
--     '40dcd6c7-c4f6-482b-b29b-007cd45ffaac',
--     '0b54c84e-6401-4633-8a4f-dcc413a88980',
--     '71d6f677-5114-4995-85bd-faa7676b1501',
--     '1d851254-4178-4d97-92da-182983c89bc0',
--     '2f9e4823-098d-44cb-979a-4ee872b94754',
--     '7003a178-e6c8-4eb7-8bdd-4c77df1ad7f3',
--     'e0084a0b-9a90-44fa-94ae-ae7744b4149e',
--     '53453d5a-4385-46b4-a947-9e9c5c6b1f7d',
--     '2e40518b-82be-4abb-b8a7-a37f20bac45b',
--     '18ce5c5c-2555-49d9-a91a-4459b5b7bf7d',
--     '07311a82-c4fe-4f6e-bbd8-86daac0a31cc',
--     'f42913c0-58df-46b0-8670-8aa79e7400b7',
--     '68f3d5a1-80da-4b3c-9fdb-d6b03e1ba106',
--     '1de3844e-e30d-4ecb-a33d-1cbe04096880',
--     'ada212d7-37ff-48b5-ade4-00c93eb2b6d6',
--     'bd1a4834-83da-446a-9f65-f6d512cef50f',
--     'bc161993-9ed5-4db8-9ef8-d3a7d1327d17',
--     'caa3f185-9d8f-4844-8a6d-61d6171ecd94',
--     '73b845be-aca4-4b70-8910-dd16eb7baf60',
--     '5a1c6c50-6adc-431e-b907-00d9f8c8b54d',
--     '85ec1d75-ef35-4e2b-a2e5-1b716c0d3dd4',
--     '226f9518-7859-4259-b680-7f1c5aa8e1e8',
--     '68653f7f-389b-44da-bba7-ca7d13325338',
--     '776248a4-7992-414d-a495-8973107a461b',
--     '744971b0-0cde-4f50-85a8-4f5541c1367a',
--     'bffb96d6-704d-4d66-afe5-c4fd65ca9627',
--     '3aed3a6b-14b6-4225-913c-b9efbac8d17d',
--     '265feb9e-2bae-45a1-bf61-8e448949da42',
--     'c60a15b1-16f9-4bd5-9156-701072658e0e',
--     '21d2f109-8045-412d-a4b8-3753c005539d',
--     'bbb89b6a-ee72-432d-b220-aa7af37974b6',
--     '8b3adab5-aaaf-4ad1-b33a-09361fa0b6cd',
--     '8809cfcd-8716-41bd-830f-e89956061c41',
--     '6fcc52da-cb72-47c3-a30d-1f620bcdc670',
--     'f1fc3366-110e-4a35-9259-26a60c8fcdd8',
--     '0c8848ba-b6bd-4609-b2fb-0fe5d8acbe54',
--     'a51ad549-66e9-409a-88be-a4f26d7f1437',
--     'd441d9b4-dea2-4400-8896-3fe555195162',
--     'f2b60463-cb32-443e-b63a-a42f85b9eeff',
--     '88d08197-2e86-4777-879c-15b91a78b85e',
--     'fd7668a6-5c19-4b4b-9279-dbe0f82fde18',
--     '4c84696d-4cd7-4d26-8dd0-920f2801e1d4',
--     '4efdfd95-69af-48e8-99c3-9f02a7e8aba7',
--     '7d6c4018-93f4-48ab-9aad-a13c9cbd15e7',
--     'b6112368-1e23-4946-991c-72b4116c3297',
--     '8a344d06-5d75-4d7c-8f96-0c1047c88bbf',
--     '840a92bb-2780-4c63-8e62-e72671dda41d',
--     '9767988a-ea08-48b3-a686-43c9d17ac2db',
--     'c122b12c-ffcb-464e-ac52-82a566a4ddcd',
--     '7c4675b6-97dd-4b67-aee9-58a6f5e42bae',
--     '7b30a96a-a59c-4784-821a-3bf83b5d89f3',
--     'ef142989-a8a4-41a8-9edd-4c21e37dbcd2',
--     '2b789e47-050c-4dc5-b046-c57d1643b9c5',
--     '730aac77-f787-46df-a97f-8a9d765ef216',
--     '9eba8532-8765-48b0-8f06-922b7e262dd8',
--     '73bb4b3a-bd5a-4b9a-a33b-8d7a88c7fea4',
--     'a40f7c28-b92e-4016-9ad1-0032af0ce07f',
--     '880cbc07-1622-41b0-8cf8-cb1cb7cefa43',
--     '46b429e0-1c7a-42ea-9489-49d309a93b04',
--     '28f1df07-c605-4d5e-b89e-90a3c896ceb4',
--     '17893843-02bd-4208-8f08-087506f2c947',
--     '327aed3b-0b97-4767-b27e-24edd3e4a995',
--     'd0655e5a-3cf8-45c1-be9e-2682de37bc6b',
--     'd6bd8279-0b28-49cd-8a86-0d00cac16de7',
--     '70159615-d124-40a0-bc22-bc083adeeea0',
--     '9f03dae8-9bbf-4e70-b6ad-ac70ee13ce12',
--     '2c859705-02d7-4ea4-8e13-7c0c345daa37',
--     'dba0e5bb-a389-4843-b594-a54fb9cd07f7',
--     'b6cb49b9-61dd-4ad0-8234-1212844007e4',
--     'd498119e-ecbf-4a13-b717-9dad47b10060',
--     '642f7a19-4550-4885-8c6a-47f5f1db512d',
--     '7efd4c1a-8de7-4c64-affd-30dbead07ccd',
--     'd919c1dd-9744-4577-bfeb-682901e72187',
--     '8f0c4324-06a9-48bf-b9ee-a0681e57ba90',
--     'da505c38-67c4-41c0-8af6-e6f4853d9716',
--     '824da285-e19a-46fd-bb2e-c6c170578f34',
--     '402cdc97-8469-4140-9e7d-006fae025c8a',
--     '9765f2fa-d8e7-47c6-89b7-c903ca222120',
--     '7fd15e38-65b8-4e62-a5f5-f904c9a49a12',
--     '6af082c3-8f54-4f7d-880a-6ceda55c4774',
--     '9ca748c7-6aba-4a35-aee6-fe24390d73c7',
--     '831c972d-0c12-4184-bd85-1b5dda4c5094',
--     '65b0c656-bd56-45fd-ac4d-957056e2048b',
--     '4a829d65-6bfb-4235-bdbc-88b1baa29726',
--     'ac8521f7-452c-4362-b389-f7b1dd186562',
--     'c107a4b1-e785-4f16-9eab-15a177c05c63',
--     '88ef79c0-5c04-4853-9df1-db912ccdd16a',
--     '7685c91d-12a8-4885-85a2-4430c3d74225',
--     '6da71001-b48e-4db0-9cab-30a4312e3c48',
--     '35e7c9ae-b158-472f-aede-6b621ab74be4',
--     '7276f1b6-d9c1-4cfb-9463-5518eb02c1d1',
--     'a8fcd7e0-6d6b-4216-8097-d9f75bc7ed5e',
--     '4cfc4fd5-ce90-47aa-91c3-f3043b3d039c',
--     'f2222760-0e3a-4923-b00f-f1365fd16218',
--     '263858b2-cdc2-4030-925f-21132a3a88e5',
--     '1ba34c9c-7b48-4705-b592-4ba0d82f79f5',
--     'e5d1de06-be69-4075-8888-d2ff1d07a8b0',
--     '000818db-d8cf-489f-8f5a-5d4bfb2d915f',
--     '8155eacd-c97f-42e5-b393-cb7d2c10b3fe',
--     '4430d8be-e042-4f19-b5a2-7bb66931a7a5',
--     'd31a783f-597c-4704-924a-dd989a256675',
--     'e9c07a92-7d69-4bd2-8277-80f785599d7c',
--     '74676b1a-7ae8-4e4d-885c-b50c73058a3f',
--     'ea87626e-1473-4bb4-b760-07b60aad34c5',
--     'c51cfcc2-5a15-453e-8922-670fe197e2dc',
--     '01d1b479-f166-4f08-b814-d2141b2ddfac',
--     'ec97a8cd-39bd-4a5d-bee0-2ed1ddd1f435',
--     '0d0a4c9f-1418-42e1-9c51-dcdfe83bd963',
--     '35684a31-9d71-4272-981a-4d7ab0ccafd7',
--     '0624f6ea-396f-4e82-a4eb-d06418e74385',
--     '38193a84-3087-4ce3-ad44-33de0f687499',
--     '93d9767d-3e80-4775-9a94-00adeaaebcf6',
--     'd2da8aad-eb8a-40e3-81df-e4624bf89d2d',
--     '86209c4e-1ccd-4949-bf88-8f0d206be7db',
--     '34f5f474-fe7e-4f0f-a136-0b10d45d0142',
--     '5287ba5d-e2d5-45c8-a230-ad934a3eaed1',
--     'edd32f8b-a7dc-4c35-a33e-b9c6e34c3f55',
--     'e4626d7f-f262-45fd-809c-243ce7955608',
--     '574d3c63-d399-4256-8a1a-fb5d3d8c3d54',
--     '97babe40-9ec6-4590-abf3-61c7d60666c4',
--     '90a06dbb-7910-4722-9e53-06b5238b0288',
--     '5b972f3e-f195-4b19-a018-81f8485d8bb4',
--     '46c37407-1fae-4588-9966-d166820047e0',
--     '7e2b1a2b-7012-41b8-8537-a210dce98e2e',
--     '032acf3f-2e01-4c70-8c68-396e1fcd264f',
--     'e4dc1698-7dea-48cf-b7b6-d1237ac816bc',
--     '0ef23385-bcfd-4aa6-acd5-a26053a9bf88',
--     'df514681-03aa-42ae-ae1a-693d12c289e7',
--     '546a5b0f-e0ca-437c-b0f9-f4ae9f8267cb',
--     '89216ae4-199b-44c8-98d2-d27b71dc5f79',
--     '3e673662-b4a4-4e3d-99f6-d3d48f8a29f6',
--     'f24161fb-21a5-4e1a-8e2b-c25820a621a7',
--     '0525b271-dfdc-4b18-b571-f306e873228e',
--     '3c30dd06-7213-44eb-afa6-513f51e6711b',
--     '21e4e2cc-32ba-47fb-a1f9-63a8e17d89a6',
--     'b30ce92b-6f68-42f9-951c-e3ba530c04db',
--     'f1e5ae5e-ce66-4cfb-bb34-b09db2752472',
--     'a455cd46-f620-4780-8043-4aef66a0a6fb',
--     '4eb85868-4e5a-4f3c-9607-8a6750f301db',
--     '856bf003-8cb5-4922-b1b9-c8062deb22f3',
--     'fd8124cf-efcc-49ed-8b66-d8f3aaf3f98c',
--     'f2d46547-cdf9-492f-8f08-864e880e86fd',
--     '5fdd2582-3555-4abe-87fc-3bdd4434917e',
--     '8793d1f7-5b67-4c2a-ba1e-d64ce3e3af74',
--     '383db3b7-6d5b-459b-9b8b-2e220afecd2b',
--     '5fce75be-a956-4af1-844f-960813b83ad7',
--     'baede1b6-73c8-422a-8808-0244674fa8da',
--     '527f0222-f902-4147-a646-93199269a096',
--     '2bb19c68-25de-4416-b87e-d2bfe008f3ca',
--     '0c7012f5-a18c-4859-90d5-29f22a4912d0',
--     '9818a117-7d3f-48ab-a932-44a0b03df5cf',
--     'bf53c632-c10b-4fe9-b3be-09a59b1ba3e8',
--     '7e8c13f3-206a-4ba8-9649-23232d3eaa5c',
--     '975bec0a-01be-4248-bef3-547672e36956',
--     'd65ba772-4cc8-4691-9204-92383e67cdc4',
--     '506fb20f-c227-43bc-b176-74a83e20d4b3',
--     '06036c80-7ebd-41da-bcf8-90acc317cc1a',
--     '81cd2685-54de-4853-be47-0f9bef11fc97',
--     'b12de61e-5a87-43d6-be14-ead3463b973a',
--     'cd40ed75-38da-4df7-a8c7-8d6a0dcbcc7c',
--     'a5c58b97-5bed-49d3-99a2-2e1115bcc759',
--     '36d17dac-048f-410a-9054-007f774b22d7',
--     'd186b7b6-78b4-4498-b584-3a943b650612',
--     'c007bcd2-7ea0-4a87-b907-e72b2e2d6b9b',
--     '151fc8d2-f460-4c64-9a3f-085106f99f39',
--     'd7f235bd-dd32-4863-96ff-032016d2f642',
--     'a9340080-0be7-4750-ac08-3c72f676a53a',
--     '5371ed45-fb25-44c7-b9d7-59fcf47d110c',
--     '64676420-d4b2-4072-9f8f-03b458dd6247',
--     '334d3e3b-54fb-4c97-93dc-241402d68f6c',
--     '9dae05b3-5188-4cb9-8ab4-70ba23bb695c',
--     '4d39215b-19cb-449b-ac0c-e27a6c7411d5',
--     '9e9a58ec-d185-4046-914f-385e68fd76d2'
--   );
--   delete from run_routines where coach_id = v_coach and is_default and (session_type, block) in (
--     ('correr_caminar', 'post'),
--     ('correr_caminar', 'pre'),
--     ('facil', 'post'),
--     ('facil', 'pre'),
--     ('larga_facil', 'post'),
--     ('larga_facil', 'pre'),
--     ('prueba_5k', 'post'),
--     ('prueba_5k', 'pre'),
--     ('strides', 'post'),
--     ('strides', 'pre'),
--     ('umbral', 'post'),
--     ('umbral', 'pre')
--   );
-- end $$;
-- -- y, si ya no querés guardar el subgrupo para nada:
-- -- alter table run_library_tags drop column if exists subgroup;
# Entry / VIP: progreso (rama feat/entry-vip)

Cómo retomar: leé este archivo, `docs/referencias/` (mockup, TEXTOS-FIJOS, actualizacion-v7) y los commits de la rama. No se hace push. Claude no ejecuta SQL.

## Cómo se prueba

Servidor `python3 -m http.server 3000` en la raíz, ventana de 390 px. **Las pruebas usan una base simulada en el navegador** (se reemplaza `sb.from` y `sb.storage.from` por un doble en memoria), para no crear ni tocar filas en Supabase de producción. Lo que depende de la base real queda marcado como "no probado en real".

## SQL

| Archivo | Estado |
|---|---|
| sql/entry-vip-base.sql | Corrido por Sau (23 nov) |
| sql/entry-vip-extra.sql | Corrido por Sau (23 nov): `client_onboarding.completed_at`, `rate_us_dismissed_at`, bucket 15 MB, policy `support_chat_all_access` |

## Decisiones de Sau (23 nov) que mandan sobre el prompt

- Fecha de pago = `clients.next_payment_date` (un solo campo). Pastilla, pantalla de pago del tour y pausa de 48 h solo para `tier='entry'` o `onboarding_required=true`. `payment_due_date` sin uso.
- Entry se crea con `food_access` y `training_access` encendidos.
- Mi motivación: si `goal_text` = `client_onboarding.success_text`, se muestra tal cual; si no, formato viejo.
- Foto obligatoria Entry: Frente + peso.
- Todo WhatsApp al número de Sau → para Entry "Abrir el chat con Sau". No tocar "Compartir menú" ni "lista de compras".
- Run = `run_module_enabled`.
- `onboarding_required = true` marca a los clientes creados desde el lanzamiento (Entry y VIP). Nunca se vuelve a false.

## Bloques

### E1: tier, crear como Entry, filtro, onboardings y bienvenida VIP — terminado
Commit: (ver git log, "E1")

Hecho:
- Bloque nuevo al final de `index.html` (`<style id="ev-css">` + script `ENTRY / VIP`, prefijo `ev`).
- Coach, crear cliente: tarjetas VIP / Entry con el recuadro "Entry aplica al instante"; inserta `tier`, `onboarding_required=true` y, para Entry, `food_access` y `training_access` en true. Virtual/Híbrido oculto en crear y editar (el dato no se borra: el select oculto conserva el valor).
- Coach, lista: filtro desplegable Todos / VIP / Entry / Evo con cantidades dentro de la pestaña actual (Activos, Churn, Ocultos); etiquetas Entry/VIP y "Onboarding pendiente"; la etiqueta V/H ya no se muestra.
- Coach, ficha: "Tipo de cliente" (VIP/Entry, solo cambia `tier`), tarjeta Onboarding con profesión, correo, peso de Tu Progreso y el resto; editable solo para VIP ("Editar datos del cliente", upsert que no pisa lo que respondió el cliente).
- Cliente: onboarding Entry (una vez; valida profesión, correo, objetivo, días, experiencia; "Empezar" apagado hasta aceptar términos) y onboarding VIP (tarjeta de 3 pasos + 2 campos). Éxito → Mi motivación solo si no había una. Bienvenida VIP con `img/sau-vip.jpg` después del onboarding VIP.
- Imágenes en `img/`: sau-bw, sau-color, sau-fire, sau-vip (800×1200).
- Arreglo chico: el nombre del cliente no se veía en el encabezado de la ficha del coach (un estilo del Perfil del cliente lo pintaba blanco). Venía de antes; se acotó a `#coach-profile-header`.

Probado (base simulada, 390 px):
- [x] Cliente viejo (onboarding_required false): sin pantallas nuevas y sin escrituras nuevas.
- [x] Crear Entry: payload de `clients` correcto. Entrar como Entry → onboarding; guardado en `client_onboarding`; no se repite al volver a entrar.
- [x] Crear VIP → onboarding VIP → bienvenida; "Algo más" de Sau se conserva (se agrega lo del cliente).
- [x] Filtro con cantidades correctas (Todos 4, VIP 2, Entry 2, Evo 1; churn aparte).
- [x] Motivación existente no se pisa; motivación del onboarding se muestra tal cual.
- [x] Ficha: cambio de tier y edición VIP.
- [x] Sin errores de consola propios (los de OneSignal en localhost son esperables).
- [ ] No probado en real: escritura en Supabase de producción, login real.

Supuestos / dudas:
- "términos y el descargo" abre una hoja con los textos de Aviso médico, Riesgos y Resultados del contrato actual.
- Campos obligatorios del onboarding Entry: profesión, correo, objetivo, días, experiencia y términos. Lesiones, equipo, éxito y "Algo más" opcionales.
- En la ficha, la fila extra "Éxito para el cliente" muestra la respuesta de éxito.

### E2: barra nueva del coach — terminado
Commit: (ver git log, "E2")

Hecho:
- Las 7 barras del coach (Clientes, Machotes, Coaching, Run, Ajustes, más ai-builder y data) pasan a 4: Clientes, Build, Delivery, Ajustes (`.ev-coach-nav`, `data-nav`).
- Pantalla nueva `screen-coach-build` con tres tarjetas (Machotes, Coaching, Run) que abren las pantallas de siempre con `coachNav('builder'|'coaching'|'run')`, sin cambios por dentro. La tarjeta de Run muestra "N pidió acceso" cuando `evRunRequestCount()` > 0 (se conecta en E4; hoy devuelve 0).
- Pantalla nueva `screen-coach-delivery` con estado "Pronto" (se llena en E4, E5, E7). En la barra hay un globito para avisos (`data-ev-badge="delivery"`, oculto por ahora).
- `coachNav` marca el ítem activo en todas las barras según la sección (Machotes/Coaching/Run → Build).

Probado (base simulada, 390 px):
- [x] Clientes → Build → Machotes / Coaching / Run abren `screen-templates`, `screen-coach-coaching`, `screen-coach-run`; Build queda marcado.
- [x] Delivery muestra "Pronto"; Ajustes y Clientes funcionan; ítem activo correcto al volver.
- [ ] No probado en real.

Notas:
- `screen-coach-data` (Analytics) ya no tenía entrada en la barra antes de este cambio; sigue igual.

### E3A: tour de onboarding y paso obligatorio en Tu Progreso — terminado
Commit: (ver git log, "E3A")

Hecho:
- Tour como lista calculada en código (`evTourList`): Entry = MOVE, Entrená, Menú, Luz, LIFT, [Fecha de pago], Chat con acuerdo, Hive, Transformación, LET'S GO. VIP = Bienvenida Lado Premium, MOVE, Entrená, Menú VIP, Luz, [Fecha de pago], Hive, Transformación, LET'S GO. Puntos y "N de M" salen de la lista final (la Bienvenida VIP no cuenta y no tiene puntos).
- Cada pantalla es un escenario de 390×844 portado del HTML del mockup (clases `t-` propias, ids de SVG con prefijo `evt-`), escalado a la pantalla real; en teléfonos más altos se estira hacia abajo, en más bajos se achica con bandas a los lados.
- Los títulos en Dela respetan los cortes de línea del mockup y se achican si no entran (Dela real es más ancha que la fuente con que se capturó el mockup). Se carga Playfair 500 como en el mockup.
- "Saltar" en todas menos la Bienvenida VIP, el acuerdo del chat y LET'S GO; lleva a la próxima pantalla obligatoria (acuerdo si falta, si no el cierre). "Siguiente" del chat apagado hasta marcar el acuerdo.
- Pantalla de fecha: solo con `next_payment_date` y cliente Entry u `onboarding_required` (`evPayDate`). Fecha en texto ("12 de diciembre").
- Al tocar "Ir a Tu Progreso" se guarda `client_onboarding.tour_seen_at` y se abre Tu Progreso.
- Paso obligatorio (solo Entry nuevo): aviso arriba de Tu Progreso con el texto fijo; el resto del app bloqueado (`evLockGuard` en `clientNav` y `switchClientPlanTab`; se ocultan The MOVE Menu, gráficos e historial y se abre el registro de la semana). Para guardar se exige foto de frente además del peso. Se desbloquea con una fila de `client_progress_logs` con `weight_kg` y `photo_front_path`.
- El onboarding VIP ya no muestra la bienvenida suelta: el tour VIP arranca con ella.

Probado (base simulada):
- [x] Entry con fecha: 10 pantallas, contadores 1..10 de 10. Entry sin fecha: 9 (chat "6 de 9"). VIP con fecha: 8 contadas. VIP sin fecha: 7 ("3 de 7" como el mockup).
- [x] Saltar desde la pantalla de pago lleva al acuerdo; el acuerdo bloquea "Siguiente".
- [x] `tour_seen_at` guardado; el tour no vuelve a salir.
- [x] Bloqueo: Hoy y Mi Diario vuelven a Tu Progreso; sin foto no guarda; con foto de frente + peso guarda, se desbloquea y Hoy abre.
- [x] VIP: sin bloqueo. Cliente viejo: sin tour ni bloqueo. Cliente VIP viejo con next_payment_date: sin pantalla de pago.
- [x] 390×844 y 375×667.
- [ ] No probado en real (Supabase, iPhone).

Supuestos / dudas:
- Pantalla de pago: el mockup no tiene "Saltar"; el prompt dice que solo no lo tienen el acuerdo y el cierre. Quedó **con** "Saltar" (según el prompt).
- Pantalla de pago: la tarjeta dice "Tu próximo pago es el / 12 de diciembre" y debajo va la frase fija "Gracias por ser parte de MOVE. Ese día renovamos tu plan con el mismo método de pago." (TEXTOS-FIJOS), además de la tarjeta "Si se te pasa, no pasa nada".
- NoPain en Luz: "Visibilidad para lo que sentís. / Espacio privado." (sin corchetes, según actualizacion-v7).
- Intensidad del aclarado en LIFT, pago y chat: igual que el mockup (pendiente de Sau).
- VIP en LET'S GO: mismo botón "Ir a Tu Progreso", sin la línea "Último paso".

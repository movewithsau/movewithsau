# Entry / VIP: progreso (rama feat/entry-vip)

Cómo retomar: leé este archivo, `docs/referencias/` (mockup, TEXTOS-FIJOS, actualizacion-v7) y los commits de la rama. No se hace push. Claude no ejecuta SQL.

## Cómo se prueba

Servidor `python3 -m http.server 3000` en la raíz, ventana de 390 px. **Las pruebas usan una base simulada en el navegador** (se reemplaza `sb.from` y `sb.storage.from` por un doble en memoria), para no crear ni tocar filas en Supabase de producción. Lo que depende de la base real queda marcado como "no probado en real".

## SQL

| Archivo | Estado |
|---|---|
| sql/entry-vip-base.sql | Corrido por Sau (23 nov) |
| sql/entry-vip-engagement.sql | Corrido por Sau (24 nov): tablas `coach_feed` y `entry_nudges` (rowsecurity false) |
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

### E3B: The MOVE Menu por tier, Perfil, Run con candado y sin WhatsApp para Entry — terminado
Commit: (ver git log, "E3B")

Hecho:
- `evApplyTier` (en `initClient`, antes del churn) pone `body.ev-entry`. Se limpia en `handleLogout` e `initCoach`.
- Menú Entry: Run con candado (etiqueta "Aparte" + candado; abre el modal del mockup), Mi Diario y Tu Progreso. Guías y recursos, Evaluaciones y Extras no aparecen. Entry arranca en Mi Diario. Si Entry tiene `run_module_enabled`, Run aparece normal. VIP igual que hoy.
- Modal de Run: "Pedir acceso" queda como aviso "Pronto…" hasta E4 (ahí manda el mensaje al chat).
- Perfil: pastilla "Fecha de pago > dd/mm/aa" bajo el usuario (solo con fecha enlazada: `next_payment_date` y Entry u `onboarding_required`). Entry: "Qué incluye tu plan" (textos fijos) en lugar de "Mi contrato". "Muévete con Sau" (Instagram, YouTube, TikTok) para todos.
- WhatsApp al número de Sau → para Entry "Abrir el chat con Sau" (el chat se arma en E4; hasta entonces muestra "pronto"): overlay de churn, "Quiero mi programa de Entreno", "Quiero mi programa FOOD", Evolution (portada y home oscuro), "Pagar" del recordatorio, "Escribirle a mi coach" de Run. Las 5 burbujas flotantes de WhatsApp se ocultan para Entry (la burbuja del chat va en E4). "Compartir menú" y "lista de compras" sin cambios.
- Entry sin "Solicitar asistencia" (ejercicio y circuito, claro y oscuro). Entry sin aviso de contrato en Hoy.

Probado (base simulada, 390 px):
- [x] Entry: 0 botones de WhatsApp visibles; menú Run(candado)/Mi Diario/Tu Progreso; candado abre el modal; Perfil con pastilla, motivación, hitos, "Qué incluye", redes; sin contrato.
- [x] VIP viejo: WhatsApp flotante visible, menú completo, contrato visible, sin pastilla.
- [x] Entry en churn: botón "Abrir el chat con Sau".
- [ ] No probado en real.

Notas:
- La burbuja del chat con la abeja (Perfil y resto de pantallas) se agrega en E4, junto con el chat.

### E4: chat con Sau, bandeja del coach, Pedir acceso a Run y burbuja VIP — terminado
Commit: (ver git log, "E4")

Hecho:
- Cliente Entry: burbuja del chat en el mismo lugar que la de WhatsApp en las 5 pantallas (en el Perfil, con la abeja de marca provisoria), con punto miel si hay respuesta de Sau sin leer (revisa cada 60 s). Chat a pantalla completa como el mockup: foto de Sau, horario, aviso de 7 días, estrellas en destacados; manda texto y fotos (sin audio). Lee y marca `read_at` en lo que mandó Sau. Se actualiza cada 8 s mientras está abierto.
- "Pedir acceso" a Run (modal del candado) crea `request_run` (etiqueta `run`) una sola vez mientras siga sin responder, y abre el chat. Todos los botones "Abrir el chat con Sau" de E3B ya abren el chat.
- Burbuja de upsell VIP (Entry con `vip_offer_active`): "Quiero info" deja `request_vip` (etiqueta `vip`, texto "Quiero VIP"); las dos opciones la apagan (`vip_offer_active=false`, `vip_offer_dismissed_at`). No sale durante el tour ni con Tu Progreso bloqueado.
- Coach, Delivery: conversaciones por cliente con filtros Todos / Soporte / Quiero VIP / Quiero Run y "Solo sin responder"; "N nuevos" arriba y globito en la barra. Build muestra "N pidió acceso" en Run.
- Coach, chat: texto, foto, grabar audio (MediaRecorder; prioriza `audio/mp4` para iPhone), destacar cualquier mensaje, "Activar Run" en el pedido. Cada mensaje de Sau deja `status='answered'` en lo pendiente del cliente y manda push al cliente ("Sau te respondió", sin el texto) dentro de try/catch.
- Coach, ficha (Entry): burbuja de upsell VIP (interruptor), Módulo Run con "Pidió acceso" e interruptor, "Abrir el chat".
- Coach, Ajustes: "Tu foto en el chat" (sube a `support-chat/coach/sau.jpg`; si no hay, usa `img/sau-color.jpg`).
- `api/purge-support.js`: borrado de 7 días **sin activar** (no está en `vercel.json`). Lee la vista `support_messages_purgeable`, borra esos archivos del bucket y esas filas (repite `starred=false` y la fecha en el DELETE). En seco por defecto; borra solo con `?run=1`; exige `CRON_SECRET`.

Probado (base simulada / node):
- [x] Cliente: enviar texto y foto, ver audio de Sau, destacados con estrella, punto de no leído y lectura.
- [x] Pedir acceso a Run → tarjeta "Quiero Run" y etiqueta; Build "1 pidió acceso"; Delivery filtra por Quiero Run.
- [x] Coach: destacar, responder (pendientes pasan a respondidos, push), Activar Run (cliente con Run, pedido respondido).
- [x] Burbuja VIP: se activa desde la ficha, el cliente la ve, "Quiero info" crea el mensaje y la apaga.
- [x] Job en seco con node: sin secreto 401; en seco no borra; borra solo mensajes viejos no destacados y respondidos (o de Sau) y sus archivos; destacados, sin responder y recientes quedan. Solo `support_messages` y el bucket.
- [ ] No probado: grabar audio de verdad (necesita micrófono) y reproducirlo en iPhone y Android; subida real al bucket; push real.

Dudas:
- Push del cliente a Sau: no se envía (el coach no registra su etiqueta en OneSignal; Sau ve el globito en Delivery). Si lo quiere, hay que registrar al coach en OneSignal.
- Para activar el borrado: crear `CRON_SECRET` en Vercel y agregar la entrada a `vercel.json` (texto en el encabezado del archivo).

### E5: LIFT Challenge y rifa — terminado
Commit: (ver git log, "E5")

Hecho:
- Mi Diario (solo Entry): tarjeta "Activá LIFT Challenge" arriba del diario (`#ev-lift`). Hoja "Elegí tu hábito" (texto libre, hasta 140, "Empezar mi racha" apagado hasta escribir) → `entry_lift_habits`. Racha con el hexágono: encendido (marcado hoy), contorno miel (falta hoy, racha viva desde ayer), apagado punteado (se pasó un día → 0, "Empezar de nuevo" marca hoy y arranca en 1). Marcar = fila en `entry_lift_checkins` (única por hábito y día; nunca se desmarca ni se borra).
- Tarjeta de la rifa: "Estás en la rifa del mes" / "Seguís en la rifa de este mes" / "Entrá a la rifa del mes" según si marcó algún día del mes. Modal "Las reglas" con los 4 puntos del mockup.
- Ficha del coach (Entry): fila LIFT Challenge con el hábito y la racha actual ("· en la rifa" si participa este mes).
- Delivery: tarjeta desplegable "Rifa del mes" (N participantes · mes) con "Este mes / Mes pasado", los 2 primeros y "Ver los N y sortear" → lista completa con hábito y racha, "Sortear ahora" (al azar, misma chance para todos) → `entry_lift_raffles` (upsert por mes). Si ya hay ganador, "Sortear de nuevo" pide confirmación.
- Fechas en hora de Costa Rica (`todayCR`).

Probado (base simulada):
- [x] Activar, marcar (0 → 1, "Hoy: marcado"), perder racha (marcas de hace 3 y 4 días → 0, "Racha apagada", mejor racha) y reiniciar (→ 1).
- [x] Cálculo de racha: solo hoy, desde ayer, con hueco, perdida; cambio de mes y febrero.
- [x] Hora de Costa Rica: 05:30 UTC = día anterior en CR; 06:30 UTC = día siguiente.
- [x] La rifa lista a todos los que marcaron al menos 1 día del mes, con hábito y racha; sorteo guardado y ganador visible.
- [x] VIP no ve LIFT.
- [ ] No probado en real.

Supuestos:
- Al crear el hábito no se marca el día solo; el cliente toca "Marcar el hábito de hoy".
- "Mes pasado" en la rifa, para sortear a principio de mes el mes que terminó.
- Texto cuando todavía no participa del mes: "Entrá a la rifa del mes · Marcá tu hábito al menos 1 día de este mes para participar."

### E6: fecha de pago y acceso en pausa — terminado
Commit: (ver git log, "E6")

Hecho:
- Fecha = `clients.next_payment_date` (decisión de Sau; `payment_due_date` sin uso). Aplica solo a `tier='entry'` u `onboarding_required=true`; sin fecha no pasa nada; los VIP actuales no cambian.
- Acceso en pausa: desde las 00:00 (hora de Costa Rica) del día de pago + 48 h. Pantalla del mockup "Vamos a arreglarlo juntos" por encima de todo (también del onboarding y el tour) menos el chat. Entry: "Abrir el chat con Sau" (con el texto de pago listo). VIP nuevo con fecha: "Escribirle a Sau" por WhatsApp (VIP no tiene chat en el app).
- Vuelve el acceso al cambiar la fecha: se revisa al volver al app (`visibilitychange`) y cada 5 minutos mientras está en pausa.
- Ficha del coach: tarjeta "Próxima fecha de pago" con estado (Al día / En las 48 h / En pausa / Sin fecha) y "Cambiar fecha" (abre el mismo "Editar cliente", un solo campo).
- Pastilla del Perfil y pantalla del tour (E3B/E3A) usan la misma regla.

Probado (base simulada):
- [x] Fecha futura, hoy y ayer: sin pausa. Hace 3 días: en pausa, con la fecha en el texto. Sin fecha: nada.
- [x] El chat abre encima de la pausa. Al cambiar la fecha a futuro, vuelve el acceso.
- [x] Ninguna escritura en la base al pausar ni al reactivar (datos intactos).
- [x] VIP viejo con fecha vencida (Edgar en la prueba): sin pausa ni nada nuevo.
- [x] Ficha del coach: "En pausa" con fecha vencida; "Al día" con fecha futura.
- [ ] No probado en real.

Supuestos:
- "48 h de esa fecha" = 48 h desde el inicio del día de pago en Costa Rica (pago el 12 → pausa el 14 a las 00:00).
- Texto de la pausa: el del mockup (incluye "Apenas se acredite el pago, volvés a entrar a todo.").
- La pausa no tiene "Cerrar sesión" (el mockup no lo trae).
- El recordatorio naranja de pago que ya existía sigue igual; para Entry su botón abre el chat (E3B).

### E7: Refiere y Gana $$ y Rate us — terminado
Commit: (ver git log, "E7")

Hecho:
- Bloque miel "Refiere y Gana $$" entre la tarjeta "Done" y "Trabajo de hoy" (todos los clientes, cuando hay entreno del día). No se puede cerrar y no rastrea nada. Abre la hoja del mockup: 10% del primer pago; 2 referidos en el mismo mes = 15% por cada uno; el amigo menciona quién lo refirió al escribirle a Sau por Instagram; pago "por SINPE al cierre del mes" (texto a confirmar).
- Rate us: automático desde el día 20 del primer mes (día 1 = `start_date`, o si no hay, cuando terminó el onboarding, o `created_at`), solo clientes con `onboarding_required` (los dos tiers). Estrellas 1–5 + comentario opcional → `client_rate_us`. Con 4 o 5 estrellas pide un testimonio, que se agrega al comentario como "Testimonio: …". "Ahora no" → `client_onboarding.rate_us_dismissed_at` (no vuelve a salir). Sale antes que la burbuja VIP; nunca durante tour, bloqueo o pausa.
- Delivery: "Calificaciones", más nueva primero (nombre, estrellas, comentario, fecha).

Probado (base simulada):
- [x] Cliente nuevo día 19: no sale; día 20: sale ("Día 20"); día 26 sin responder: sale. Cliente viejo: no sale.
- [x] Guardado del rating y del testimonio (el comentario se conserva). Una vez respondido o con "Ahora no", no vuelve.
- [x] Bloque Refiere y Gana en su lugar y la hoja; 390 px.
- [x] Lista del coach ordenada, más nueva primero.
- [ ] No probado en real.

Supuestos / pendientes:
- Texto de pago de referidos "Sau te paga tu comisión por SINPE al cierre del mes": a confirmar con Sau.
- Testimonio: se guarda dentro del mismo comentario (no hay columna aparte).
- Vista del coach en Delivery: propuesta, a confirmar con Sau.

### E8: NoPain (acompañamiento emocional en Mi Diario) — terminado
Commit: (ver git log, "E8")

Paso 0:
- NutriFlex y StrongFlow: llaman a `/api/chat` (Vercel → Groq, modelo `openai/gpt-oss-120b` vía `GROQ_MODEL`, clave `GROQ_API_KEY` en el servidor); el prompt vive en `index.html`; **sí guardan** la conversación (`nutrition_chats`, `training_chats`). NoPain copia la llamada pero no guarda nada.
- `api/chat.js` solo escribe en los logs el estado, el código y el mensaje de error de Groq; nunca el cuerpo ni el texto de los mensajes.
- `claude/nopain-agente-emocional.md` no existe en el repo; se usó `docs/NoPain_2.0_Emotional_Wellness_OS.md`, `docs/referencias/docs/TEXTOS-FIJOS.md` y los mockups 32–35.

Hecho:
- Tarjeta miel "NoPain · Espacio privado" en Mi Diario para todos los clientes (Entry y VIP), con botón blanco y el hexágono con punto central.
- "Antes de empezar" (primer uso) con los 3 puntos del mockup y el checkbox "Entendí que NoPain no es terapia ni atención médica." Solo se guarda `clients.nopain_accepted_at`.
- Chat sin historial: la conversación vive solo en memoria de la pestaña; se borra al salir (pide confirmar), con "Borrar" y al cerrar sesión. Sin tablas, sin localStorage, sin datos del cliente en el prompt. Aviso: "Sau no ve esta conversación y no se guarda: si salís, se borra. Tus mensajes se procesan con inteligencia artificial para poder responderte." Nunca "100 % privado".
- Saludo fijo del mockup y chips "Ordenar mis ideas" / "Solo quiero desahogarme". Respuestas en burbuja miel, cliente en naranja.
- Prompt "NoPain 2.0" adaptado a voseo costarricense: respuestas cortas (máx. 70 palabras), una pregunta a la vez, sin diagnosticar, sin datos del cliente, con la regla de seguridad (911 y Aquí Estoy) como respaldo.
- Filtro de crisis fijo en el código (sin tildes, minúsculas; frases en español, voseo y jerga tica). Si dispara, muestra el mensaje fijo del mockup con "Llamar al 911" (`tel:911`) y "Aquí Estoy · 800 273 7869" (`tel:8002737869`), sin llamar al modelo; ese mensaje tampoco se manda después en el historial. No usa el 1322.
- "Llevarme un resumen (Harvest)": pide la cosecha al modelo y la muestra en una hoja con Copiar y Compartir; el app no la guarda.
- Sin tope de mensajes.

Probado:
- [x] Filtro de crisis (node): 29 frases de riesgo reales disparan (incluye "mae ya no quiero vivir", "Diay, ya no quiero seguir aquí", "me quiero tirar del puente", "me tomé todas las pastillas", "serían mejor sin mí"); 12 frases comunes no ("Me mato en el gym", "esta rutina me está matando", "quiero morirme de la risa", "me voy a hacer algo de comer", "ya no puedo más con las sentadillas").
- [x] Navegador (base simulada): primer uso → solo escribe `nopain_accepted_at`; mensaje normal → 1 llamada a `/api/chat`, 0 escrituras en la base, prompt sin datos del cliente; crisis → 0 llamadas y tarjeta con los dos teléfonos; Harvest sin escrituras; salir vacía la memoria y al volver arranca de cero; localStorage sin cambios.
- [x] Entry y VIP ven la tarjeta. 390 px.
- [ ] No probado: respuesta real del modelo (en local `/api/chat` no corre; se simuló).
- [ ] **Antes de lanzar, Sau re-verifica los contactos**: 911 y Aquí Estoy 800 273 7869 (horario de la línea pendiente).

Pendientes de Sau: nombre final de NoPain, horario de Aquí Estoy, si "sin costo" = sin tope de mensajes.

### Ajustes de Sau (23 nov, después de E8)
- NoPain: el campo de texto ahora es de varias líneas y crece hacia arriba (hasta ~6 líneas, después scroll). En el teléfono Enter hace salto de línea y se envía con el botón; en compu Enter envía.
- Tu Progreso: guía colapsable "Cómo tomarte las fotos" arriba del registro de la semana, con el texto de Sau (en ayunas, una vez por semana, sin forzar pose) y las 3 referencias (`img/pose-frente.webp`, `img/pose-costado.webp`, `img/pose-espalda.webp`); tocar una la abre a pantalla completa. Para todos los clientes.
- Refiere y Gana: "+2 amigos en el mismo mes: ganás 15% por cada uno." y punto 3 "Cuando hace su primer pago, Sau te paga tu comisión al cierre de ese mismo mes."
- Nota: "Te escucho. ¿Qué pasó hoy?" en NoPain era la respuesta del doble de prueba que quedó activo en la pestaña del navegador del app, no el modelo. NoPain real necesita `/api/chat` (Vercel), que no corre con `python3 -m http.server`.

### E9: Engagement Entry — terminado
Commit: (ver git log, "E9")

Hecho:
- 9.1 Mi meta (Hive): texto nuevo siempre visible debajo de "Días por semana", todos los tiers; hexágonos y lógica sin cambios. El texto viejo "Elegí cuántos días…" ya no se muestra.
- 9.2 Encabezado del chat del cliente: "Tu Coach" (único lugar en el app; el mockup de referencia no se tocó).
- 9.3 `api/coach-digest` (cron 9 p. m. CR): `runNudges` para `tier='entry'`, sin churn, sin ocultos y sin la pausa de pago (next_payment_date + 48 h, misma regla que el app). Inactivo = más de 3 días desde el último `workout_sessions` con `plan_day_id` (o desde `client_onboarding.completed_at` si nunca entrenó). Episodio 1: texto "hey hace un par de días…"; siguientes: "parece que otra vez…". Nombre = primer nombre en minúscula. Primero reserva el episodio en `entry_nudges` (único cliente+episodio: si el cron corre dos veces no hay doble mensaje), después inserta el mensaje como de Sau (`sender='coach'`, `status='answered'`) y deja el aviso en `coach_feed`. Los nudges corren aunque no haya nada que reportar en el resumen; el push no se usa para esto.
- 9.4 Banner "Tenés nuevos mensajes de Tu Coach" (solo Entry): en `evPostLoginPopups`, antes de Rate us y la oferta VIP (un solo pop-up por apertura; pausa, churn, tour y Tu Progreso bloqueado ya cortan antes). Vista previa del último mensaje sin leer, "Ver mensaje" abre el chat. Se recuerda el id del último mensaje mostrado en el equipo (`localStorage`), así no vuelve hasta que llega uno más nuevo. VIP no ve nada.
- 9.5 Delivery: fila fija "Coach" arriba de las conversaciones, abre el historial de `coach_feed` (resúmenes y avisos de nudges), solo lectura. El cron guarda cada resumen ahí antes de intentar el push. `coach_feed` no entra en la purga de 7 días.

Probado:
- [x] Cron con node y Supabase simulado: Entry inactivo con entreno viejo y Entry que nunca entrenó → 1 mensaje cada uno; churn, en pausa, reciente y VIP → nada; segunda corrida → nada; vuelve a entrenar y pasan 4 días → episodio 2 con "otra vez". Hilo Coach con los 3 avisos.
- [x] Revisión de sintaxis de todo el JS de `index.html`.
- [ ] Banner y hilo Coach en el navegador: **no probados** (no se pudo abrir la vista previa en esta sesión).
- [ ] No probado en real.

Decisiones:
- Cuenta como entreno solo `workout_sessions` con `plan_day_id` (Run, hábitos, LIFT, comidas y check-in no cuentan).
- "Más de 3 días" = 4 o más días calendario desde el último entreno (en la corrida de las 9 p. m.).
- El banner va antes que Rate us y la oferta VIP.

### E10: Entreno para poco tiempo (solo VIP) — terminado (regla pendiente de aprobación)
Commit: (ver git log, "E10")

Paso 0:
- Run: la versión (completa / reducida 70 % / mínima 50 %) se calcula sobre la sesión planeada y se guarda en `run_sessions.version`.
- Entreno del día: `exercises` del `monthly_plans` del día; circuito = mismo `superset_group` (rondas en `circuit_rounds`), suelto = `sets`.

Hecho:
- Debajo de "Iniciar entreno", botón estilo "Ir a Run": "Entreno para poco tiempo" (solo VIP, oculto para Entry). Al tocarlo cambia a "Poco tiempo activo · Volver al completo". Durante el entreno se ve la etiqueta "Entreno para poco tiempo" y no se puede cambiar.
- Regla (`minWkReduce`, en memoria): de cada circuito, solo el primer ejercicio, con 2 rondas (o menos si el plan tenía menos); ejercicios sueltos con 2 series como máximo. No se escribe nada nuevo en el plan.
- Cuenta como día entrenado: se guardan los mismos `exercise_logs` y la fila normal de `workout_sessions` al terminar.
- Sin columna nueva: la elección se recuerda en el equipo (cliente + día del plan + fecha). Sau no puede ver si el día fue versión mínima; para eso haría falta una columna (`workout_sessions.is_minimal`), no se agregó.

Probado:
- [x] `minWkReduce` con node: circuitos de 2 a 1 ejercicio, rondas 4→2, 1→1; sueltos 5→2, 1→1; el arreglo original no cambia.
- [ ] Navegador y real: **no probados**.

Pendiente de Sau: aprobar la regla; qué hacer con los días que son todo ejercicios sueltos (hoy se quedan todos con 2 series, puede pasar de 15 min).

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

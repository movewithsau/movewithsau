# SQL de Entry / VIP: orden y backup

Claude no ejecuta nada de esto. Lo corre Sau en Supabase > SQL Editor.

## Antes de empezar: backup

1. Supabase > Database > Backups: confirmá que hay un backup de hoy (o descargá uno).
2. `entry-vip-base.sql` ya copia `clients` a `clients_backup_20261123` antes de tocarla.
3. `entry-vip-extra.sql` no toca tablas con datos de clientes. Solo agrega dos columnas vacías a `client_onboarding` (tabla nueva), ajusta el límite de tamaño del bucket nuevo `support-chat` y crea una policy de Storage para ese bucket. Si querés una copia de la configuración del bucket antes, corré:
   `select * from storage.buckets where id = 'support-chat';` y guardá el resultado.

## Orden

| # | Archivo | Qué hace | Estado |
|---|---|---|---|
| 1 | `entry-vip-base.sql` | Columnas nuevas en `clients` (`tier`, `payment_due_date`, `vip_offer_active`, `vip_offer_dismissed_at`, `onboarding_required`, `nopain_accepted_at`), tablas `client_onboarding`, `support_messages`, `entry_lift_habits`, `entry_lift_checkins`, `entry_lift_raffles`, `client_rate_us`, vista `support_messages_purgeable` y bucket privado `support-chat` | Ya corrido por Sau |
| 2 | `entry-vip-extra.sql` | `client_onboarding.completed_at` y `rate_us_dismissed_at`, límite de 15 MB en `support-chat`, policy `support_chat_all_access` | Pendiente |

Los dos archivos se pueden correr más de una vez sin romper nada. Al final de `entry-vip-extra.sql` hay tres `select` de verificación: mandale el resultado a Claude.

## Notas

- `clients.payment_due_date` queda sin uso: la fecha de pago es la columna existente `next_payment_date` (decisión de Sau).
- La bandera de Run es la columna existente `run_module_enabled`: no hay columna nueva.
- El borrado de 7 días del chat (bloque E4) se entrega como archivo aparte y **sin activar**: no está en `vercel.json` hasta que Sau lo decida.

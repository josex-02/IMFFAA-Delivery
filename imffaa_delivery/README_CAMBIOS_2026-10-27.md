# Corrección OTP y diálogos — 2026-10-27

## Código de correo
- La plantilla `supabase/templates/confirmation.html` debe mostrar `{{ .Token }}` y no `{{ .ConfirmationURL }}`.
- `supabase/config.toml` mantiene `otp_length = 6`, confirmación habilitada y apunta a la plantilla personalizada.
- El campo OTP ahora acepta exactamente seis dígitos y se verifica con `verifyOTP(..., type: OtpType.signup)`.
- Se corrigió el botón de reenviar código del registro: ahora usa el correo escrito en el formulario de registro, no el del inicio de sesión.
- Si el correo sigue mostrando “Confirm your account by clicking the link”, la instancia local no ha aplicado esta configuración o se está probando otro proyecto/instancia. Ejecuta `./reiniciar_supabase_otp.ps1` desde la carpeta raíz del proyecto. Después revisa el correo recién generado en Mailpit (`http://127.0.0.1:54324`). Los correos viejos no cambian retroactivamente.
- Para un proyecto alojado en Supabase Cloud, estos archivos locales no cambian el template remoto; hay que copiar la plantilla en Dashboard → Authentication → Email Templates → Confirm signup y configurar el SMTP/proyecto correspondiente.

## Diálogos
- Tema global: alineación centrada, márgenes consistentes y esquinas redondeadas.
- Los formularios de añadir/editar producto del administrador tienen anchura limitada y scroll con altura máxima para evitar que salgan de pantalla.
- La verificación debe probarse con una cuenta nueva/no confirmada y un correo nuevo. Si se desactivó la confirmación en el proyecto remoto/local, Supabase puede devolver una sesión inmediata y no se mostrará el paso OTP.

## Validación pendiente
No hay Flutter/Dart disponible en este entorno de edición, así que ejecuta en Windows:
```powershell
flutter pub get
flutter analyze
flutter test
```

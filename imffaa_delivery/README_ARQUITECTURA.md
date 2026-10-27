# Estructura del código — IMFFAA Delivery

El archivo `lib/main.dart` queda reducido al arranque de Flutter, la carga de `.env` y la inicialización de Supabase. La implementación se distribuye por responsabilidad:

- `lib/app_state.dart`: modelo de producto, catálogo inicial, estado compartido y carga del catálogo.
- `lib/app_shell.dart`: aplicación raíz, tema y rutas.
- `lib/catalog_page.dart`: pantalla del catálogo, vista previa del producto, carrito, checkout y pedidos del cliente.
- `lib/catalog_widgets.dart`: widgets visuales compartidos del catálogo y tarjetas de producto.
- `lib/admin_panel.dart`: panel administrativo, productos, perfiles y gestión de pedidos.
- `lib/auth_dialog.dart`: autenticación y formularios de acceso/registro.
- `lib/models/delivery_order.dart`: modelo de pedido.
- `lib/services/app_notifications.dart`: notificaciones visuales.
- `lib/services/receipt_pdf_service.dart`: generación de comprobantes PDF.
- `lib/widgets/catalog_common_widgets.dart`: componentes comunes reutilizables.

Los archivos de pantalla se conectan actualmente mediante `part` para conservar el comportamiento y evitar romper referencias privadas durante esta reorganización. Esto divide físicamente el código, pero **no es una frontera de seguridad**: los archivos `part` pertenecen a la misma biblioteca Dart. Las credenciales privilegiadas nunca deben estar en Flutter; la clave `anon` de Supabase es pública por diseño y la seguridad real debe imponerse con políticas RLS y validaciones del lado servidor. No publiques el archivo `.env` ni lo subas al repositorio.

Para comprobar el proyecto localmente:

```bash
flutter pub get
flutter analyze
flutter test
```

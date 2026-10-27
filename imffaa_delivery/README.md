# IMFFAA Delivery — Flutter + Supabase

Proyecto Flutter del catálogo IMFFAA Delivery con autenticación Supabase, catálogo leído desde la tabla `products`, pedidos, comprobantes PDF y panel administrativo. El panel permite crear productos con precio, stock, colores, tallas, características e imagen subida a Storage; las tarjetas muestran stock y controles de cantidad.

## Configuración

1. Instala Flutter y una versión reciente de Dart.
2. Revisa `.env`. Configura los valores de tu instancia local en `.env`:

   ```env
   SUPABASE_URL=tu_url_de_supabase
   SUPABASE_ANON_KEY=tu_anon_key
   ```

   `.env` está incluido como asset para que `flutter_dotenv` lo pueda leer. No pongas una `service_role` key en la app. La anon/publishable key se considera pública y debe protegerse con RLS.

3. En el proyecto local de Supabase, ejecuta `supabase/schema.sql` desde el SQL Editor o con la CLI. Crea tablas, políticas, buckets privados y los productos iniciales.
4. Instala dependencias y ejecuta:

   ```bash
   flutter clean
   flutter pub get
   flutter analyze
   flutter run
   ```

## Crear el primer administrador

1. Registra una cuenta desde la app y confirma el correo si Supabase lo requiere.
2. En Supabase SQL Editor, busca el UUID del usuario en Authentication → Users.
3. Asigna el rol manualmente desde SQL:

   ```sql
   update public.profiles
   set role = 'admin'
   where id = 'UUID-REAL-DEL-USUARIO';
   ```

   Nunca permitas que el usuario elija su propio rol desde el formulario. La protección real depende de RLS y de `public.is_admin()`.

## Datos guardados

- Supabase Auth: cuenta y credenciales (contraseña gestionada por Supabase Auth).
- `profiles`: nombre, identidad, teléfono y rol.
- `products`: catálogo, precio, stock, colores, tallas, características, categoría, género y permisos. El catálogo se carga desde Supabase.
- Storage `product-images`: imágenes públicas de productos; la política de subida exige rol admin.
- `orders` y `order_items`: pedido y sus líneas.
- Storage `identity-documents`: documento de identidad en bucket privado.
- Storage `order-receipts`: PDF de comprobante en bucket privado; `orders.receipt_path` guarda su ruta.
- Realtime: el panel vuelve a consultar pedidos cuando cambia la tabla `orders`.

## Límites importantes de esta iteración

- El URL `127.0.0.1` solo apunta al equipo donde corre Supabase. Para probar desde un teléfono físico, cambia `SUPABASE_URL` por la IP LAN de tu PC (o la URL del proyecto remoto) y recompila.
- Los comprobantes PDF se guardan en Storage. En esta iteración el PDF se crea en el cliente; para una tienda real, mueve el cálculo de totales, validación de stock/permisos y la creación definitiva del pedido a una función RPC transaccional o Edge Function. No confíes en el total enviado por Flutter.
- Ejecuta el `supabase/schema.sql` actualizado en el SQL Editor local para añadir `gender`, `features`, el bucket `product-images` y sus políticas. La conexión definida en `.env` se conserva sin cambios.
- La interfaz limita cantidades según el stock que carga del servidor; para prevenir sobreventa con varios clientes simultáneos, el siguiente paso recomendado es validar y descontar el inventario dentro de una función RPC transaccional.
- La foto de identidad es dato sensible. Mantén los buckets privados, limita el acceso por RLS y define una política de retención antes de usar datos reales.
- Nunca uses una `service_role` key en Flutter ni la incluyas en `.env` de cliente.

## Cambios recientes de interfaz y seguridad

- El panel administrativo agrupa Pedidos, Catálogo/Almacén y Usuarios/Roles en secciones desplegables.
- Los avisos de éxito y error usan `toastification`.
- Desde Usuarios/Roles se puede asignar a perfiles existentes uno de los roles que ya admite el esquema: `cliente` o `admin`. Esta acción requiere sesión administrativa y políticas RLS correctas.
- Las contraseñas se gestionan exclusivamente con Supabase Auth. No deben almacenarse en `profiles`, ni cifrarse manualmente desde Flutter. Supabase gestiona su almacenamiento seguro mediante hash.
- Se conserva la configuración existente de `.env` y la inicialización de Supabase.

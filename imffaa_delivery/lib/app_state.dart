part of 'main.dart';

final supabase = Supabase.instance.client;
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

const ink = Color(0xFF202522);
const navy = Color(0xFF238841);      // verde de marca
const slate = Color(0xFF65716A);
const paper = Color(0xFFC9C9CB);     // gris de marca
const line = Color(0xFFB5B7B8);
const lime = Color(0xFFFDED00);      // amarillo de acento
const muted = Color(0xFF62686A);

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.gender,
    required this.price,
    required this.description,
    required this.image,
    this.tag = '',
    this.oldPrice,
    this.requiresAuthorization = false,
    this.features = const <String>[],
    this.colors = const <String>['Verde bosque', 'Negro', 'Gris', 'Arena'],
    this.sizes = const <String>['Única'],
  });

  final int id;
  final String name;
  final String category;
  final String gender;
  final int price;
  final int? oldPrice;
  final String description;
  final String image;
  final String tag;
  // DEMO: reemplazar este indicador por permisos devueltos por el backend.
  final bool requiresAuthorization;
  final List<String> features;
  final List<String> colors;
  final List<String> sizes;
}

/// Estado compartido para esta demostración local. Al conectar Supabase, sustituir
/// estas notificaciones por consultas y streams de la tabla `orders`.
final ValueNotifier<List<DeliveryOrder>> deliveryOrders = ValueNotifier<List<DeliveryOrder>>(<DeliveryOrder>[]);
final ValueNotifier<List<Product>> catalogProducts = ValueNotifier<List<Product>>(<Product>[]);
final ValueNotifier<Map<int, int>> inventoryCounts = ValueNotifier<Map<int, int>>(<int, int>{});
final ValueNotifier<Map<int, int>> productPrices = ValueNotifier<Map<int, int>>(<int, int>{});
int stockFor(Product product) => inventoryCounts.value[product.id] ?? 0;

Future<void> loadProductsFromSupabase() async {
  try {
    final rows = await supabase.from('products').select().eq('active', true).order('id');
    final loaded = <Product>[];
    final stocks = <int, int>{}; final prices = <int, int>{};
    for (final item in rows) {
      final row = Map<String, dynamic>.from(item);
      final id = (row['id'] as num).toInt();
      loaded.add(Product(id: id, name: (row['name'] ?? '').toString(), category: (row['category'] ?? 'Accesorios').toString(), gender: (row['gender'] ?? 'Unisex').toString(), price: (row['price'] as num).toInt(), description: (row['description'] ?? '').toString(), image: (row['image_url'] ?? '').toString(), tag: '', requiresAuthorization: row['requires_authorization'] == true, features: (row['features'] as List? ?? const []).map((e) => e.toString()).toList(), colors: (row['colors'] as List? ?? const ['Negro']).map((e) => e.toString()).toList(), sizes: (row['sizes'] as List? ?? const ['Única']).map((e) => e.toString()).toList()));
      stocks[id] = (row['stock'] as num?)?.toInt() ?? 0; prices[id] = (row['price'] as num).toInt();
    }
    catalogProducts.value = loaded; inventoryCounts.value = stocks; productPrices.value = prices;
  } catch (_) { catalogProducts.value = <Product>[]; inventoryCounts.value = <int, int>{}; productPrices.value = <int, int>{}; }
}
int priceFor(Product product) => productPrices.value[product.id] ?? product.price;

String money(int amount) {
  final raw = amount.toString();
  final out = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
    out.write(raw[i]);
  }
  return 'L ${out.toString()}';
}


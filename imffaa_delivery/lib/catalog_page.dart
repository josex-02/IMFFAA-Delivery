part of 'main.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String category = 'Todo';
  String gender = 'Todos';
  String query = '';
  String sort = 'Destacados';
  final searchController = TextEditingController();
  final Map<int, int> cart = {};
  final Map<int, String> cartColors = {};
  final Map<int, String> cartSizes = {};
  bool searchVisible = false;
  AuthResult? currentUser;
  StreamSubscription<AuthState>? _authSubscription;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    loadProductsFromSupabase().then((_) {
      if (mounted) setState(() {});
    });
    _restoreSession();
    _authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      if (user == null) {
        if (mounted) {
          setState(() {
            currentUser = null;
            _restoringSession = false;
          });
        }
      } else {
        _restoreSession();
      }
    });
  }

  Future<void> _restoreSession() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _restoringSession = false);
      return;
    }
    try {
      final profile = await supabase
          .from('profiles')
          .select('id, full_name, role')
          .eq('id', user.id)
          .maybeSingle();
      final restored = AuthResult(
        name: (profile?['full_name'] ??
                user.userMetadata?['full_name'] ??
                user.email?.split('@').first ??
                'Usuario')
            .toString(),
        email: user.email ?? '',
        idNumber: (user.userMetadata?['id_number'] ?? '').toString(),
        role: (profile?['role'] ?? 'cliente').toString().toLowerCase(),
        userId: user.id,
      );
      if (mounted) {
        setState(() {
          currentUser = restored;
          _restoringSession = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          currentUser = AuthResult(
              name: user.email?.split('@').first ?? 'Usuario',
              email: user.email ?? '',
              idNumber: '',
              role: 'cliente',
              userId: user.id);
          _restoringSession = false;
        });
      }
    }
  }

  void _syncProductRows(List<Map<String, dynamic>> rows) {
    final loaded = <Product>[];
    final stocks = <int, int>{};
    final prices = <int, int>{};
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      final price = (row['price'] as num?)?.toInt() ?? 0;
      loaded.add(Product(
          id: id,
          name: (row['name'] ?? '').toString(),
          category: (row['category'] ?? 'Accesorios').toString(),
          gender: (row['gender'] ?? 'Unisex').toString(),
          price: price,
          description: (row['description'] ?? '').toString(),
          image: (row['image_url'] ?? '').toString(),
          requiresAuthorization: row['requires_authorization'] == true,
          features: (row['features'] as List? ?? const [])
              .map((e) => e.toString())
              .toList(),
          colors: (row['colors'] as List? ?? const ['Negro'])
              .map((e) => e.toString())
              .toList(),
          sizes: (row['sizes'] as List? ?? const ['Única'])
              .map((e) => e.toString())
              .toList()));
      stocks[id] = (row['stock'] as num?)?.toInt() ?? 0;
      prices[id] = price;
    }
    if (mounted) {
      catalogProducts.value = loaded;
      inventoryCounts.value = stocks;
      productPrices.value = prices;
    }
  }

  static const categories = [
    'Todo',
    'Vestimenta',
    'Calzado',
    'Equipo',
    'Accesorios'
  ];
  static const genders = ['Todos', 'Hombre', 'Mujer', 'Unisex'];

  List<Product> get filtered {
    final items = catalogProducts.value.where((p) {
      final matchesCategory = category == 'Todo' || p.category == category;
      final matchesGender = gender == 'Todos' || p.gender == gender;
      final q = query.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          '${p.name} ${p.description} ${p.category}'.toLowerCase().contains(q);
      return matchesCategory && matchesGender && matchesQuery;
    }).toList();
    if (sort == 'Precio menor') {
      items.sort((a, b) => priceFor(a).compareTo(priceFor(b)));
    }
    if (sort == 'Precio mayor') {
      items.sort((a, b) => priceFor(b).compareTo(priceFor(a)));
    }
    return items;
  }

  int get cartCount => cart.values.fold(0, (sum, n) => sum + n);
  int get cartTotal {
    var total = 0;
    for (final p in catalogProducts.value) {
      total += priceFor(p) * (cart[p.id] ?? 0);
    }
    return total;
  }

  Future<void> add(Product product,
      {String? color, String? size, int quantity = 1}) async {
    // El catálogo es público. La sesión se solicita únicamente al intentar comprar.
    if (currentUser == null) {
      final result = await showDialog<AuthResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AuthDialog(),
      );
      if (!mounted || result == null) return;
      await acceptSession(result);
      if (result.role == 'admin') return;
    }

    // Nunca confiar en permisos escritos por el usuario. En producción este
    // permiso debe comprobarse en el servidor para cada producto.
    if (product.requiresAuthorization) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon:
              const Icon(Icons.verified_user_outlined, size: 34, color: slate),
          title: const Text('Autorización necesaria'),
          content: Text(
            'Tu sesión está iniciada, pero ${product.name} requiere un permiso asociado a tu identidad. '
            'Esta demo todavía no está conectada al servidor que valida esos permisos, por lo que no podemos autorizar la compra.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendido')),
          ],
        ),
      );
      return;
    }

    final currentQuantity = cart[product.id] ?? 0;
    final requestedQuantity = quantity.clamp(1, 999).toInt();
    if (currentQuantity + requestedQuantity > stockFor(product)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(stockFor(product) == 0
                ? 'Producto agotado'
                : 'Solo hay ${stockFor(product) - currentQuantity} unidades disponibles'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    setState(() {
      cart[product.id] = currentQuantity + requestedQuantity;
      cartColors[product.id] =
          color ?? (product.colors.isNotEmpty ? product.colors.first : 'Negro');
      cartSizes[product.id] =
          size ?? (product.sizes.isNotEmpty ? product.sizes.first : 'Única');
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(requestedQuantity == 1
            ? '${product.name} añadido al carrito'
            : '$requestedQuantity unidades de ${product.name} añadidas al carrito'),
        duration: const Duration(seconds: 2),
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> acceptSession(AuthResult result) async {
    if (!mounted) return;
    setState(() => currentUser = result);
    showAppToast(context, 'Sesión iniciada correctamente.');
    if (result.role.toLowerCase() == 'admin') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AdminPanelPage(user: result),
      ));
      if (mounted) setState(() {});
    }
  }

  Future<void> openProductDetails(Product product) async {
    final availableColors = <String>['Verde bosque', 'Negro', 'Gris', 'Arena'];
    final sizes = product.category == 'Calzado'
        ? <String>['S (38–39)', 'M (40–41)', 'L (42–43)', 'XL (44–45)']
        : (product.category == 'Vestimenta'
            ? <String>['XS', 'S', 'M', 'L', 'XL', 'XXL']
            : <String>['Única']);
    var selectedColor = cartColors[product.id] ?? availableColors.first;
    var selectedSize =
        cartSizes[product.id] ?? (sizes.contains('M') ? 'M' : sizes.first);
    var previewQuantity =
        stockFor(product) - (cart[product.id] ?? 0) > 0 ? 1 : 0;
    final screenSize = MediaQuery.sizeOf(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: screenSize.height * .82,
              minWidth: 280,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(product.category.toUpperCase(),
                            style: TextStyle(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5))),
                    IconButton(
                        tooltip: 'Cerrar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 4),
                  Center(
                    child: GestureDetector(
                      onTap: () => showImageZoom(
                          dialogContext, product.image, product.name),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.zoomIn,
                        child: Tooltip(
                          message: 'Toca para ampliar la imagen',
                          child: Hero(
                            tag: 'product-${product.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: screenSize.width < 420 ? 190 : 240,
                                height: (screenSize.height * .19)
                                    .clamp(120.0, 175.0)
                                    .toDouble(),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ProductImage(url: product.image),
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: .65),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Padding(
                                          padding: EdgeInsets.all(7),
                                          child: Icon(Icons.zoom_in_rounded,
                                              color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(product.name,
                      style: GoogleFonts.dmSerifDisplay(
                          fontSize: 28,
                          height: 1.1,
                          color:
                              Theme.of(dialogContext).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Text(product.description,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurfaceVariant)),
                  const SizedBox(height: 17),
                  Text('CARACTERÍSTICAS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onSurfaceVariant)),
                  const SizedBox(height: 9),
                  ...product.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: slate, size: 17),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(feature,
                                      style: const TextStyle(
                                          fontSize: 12, height: 1.4))),
                            ]),
                      )),
                  if (product.requiresAuthorization) ...[
                    const SizedBox(height: 5),
                    Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 18, color: navy),
                          SizedBox(width: 9),
                          Expanded(
                              child: Text(
                                  'Este artículo requiere el permiso correspondiente en tu cuenta.',
                                  style: TextStyle(fontSize: 11, height: 1.4)))
                        ])),
                  ],
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: _SelectionDropdown<String>(
                            label: 'COLOR',
                            value: selectedColor,
                            items: availableColors,
                            onChanged: (value) =>
                                setDialogState(() => selectedColor = value))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _SelectionDropdown<String>(
                            label: 'TALLA',
                            value: selectedSize,
                            items: sizes,
                            onChanged: (value) =>
                                setDialogState(() => selectedSize = value))),
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                          child: Text('CANTIDAD',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .onSurfaceVariant))),
                      QuantityButton(
                          icon: Icons.remove,
                          onTap: () => setDialogState(() {
                                if (previewQuantity > 1) previewQuantity--;
                              })),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('$previewQuantity',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15))),
                      QuantityButton(
                          icon: Icons.add,
                          onTap: () => setDialogState(() {
                                if (previewQuantity <
                                    stockFor(product) -
                                        (cart[product.id] ?? 0)) {
                                  previewQuantity++;
                                }
                              })),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('PRECIO',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  letterSpacing: 1.3,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(money(priceFor(product) * previewQuantity),
                              style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(dialogContext)
                                      .colorScheme
                                      .onSurface))
                        ])),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 2,
                        child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: previewQuantity <= 0
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                      add(product,
                                          color: selectedColor,
                                          size: selectedSize,
                                          quantity: previewQuantity);
                                    },
                              style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              icon: const Icon(Icons.shopping_bag_outlined,
                                  size: 17),
                              label: FittedBox(
                                  child: Text(
                                      'AÑADIR $previewQuantity AL CARRITO',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .4))),
                            ))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showAccount() {
    if (currentUser == null) {
      showDialog<AuthResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AuthDialog(),
      ).then((result) {
        if (mounted && result != null) acceptSession(result);
      });
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.account_circle_outlined, size: 36, color: slate),
        title: const Text('Tu cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentUser!.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(currentUser!.email,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text('Sesión vinculada a tu cuenta de IMFFAA Delivery.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await supabase.auth.signOut();
                if (mounted) {
                  setState(() => currentUser = null);
                  showAppToast(context, 'Sesión cerrada correctamente.');
                }
              } catch (e) {
                if (mounted) {
                  showAppToast(context, 'No se pudo cerrar la sesión: $e',
                      isError: true);
                }
              }
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void changeQuantity(Product product, int delta) {
    final current = cart[product.id] ?? 0;
    final next = current + delta;
    final available = stockFor(product);
    if (delta > 0 && next > available) {
      final message = available <= 0
          ? 'Producto agotado'
          : current >= available
              ? 'Ya agregaste todas las unidades disponibles'
              : 'Solo puedes agregar ${available - current} unidades más';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(message), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() {
      if (next <= 0) {
        cart.remove(product.id);
        cartColors.remove(product.id);
        cartSizes.remove(product.id);
      } else {
        cart[product.id] = next;
      }
    });
  }

  Future<void> openCheckout() async {
    if (cart.isEmpty) return;
    if (currentUser == null) {
      final result = await showDialog<AuthResult>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AuthDialog());
      if (!mounted || result == null) return;
      await acceptSession(result);
      if (result.role.toLowerCase() == 'admin') return;
    }

    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    String paymentMethod = 'Efectivo contra entrega';
    String? validationMessage;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 520,
                      maxHeight: MediaQuery.sizeOf(dialogContext).height * .88),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('FINALIZAR PEDIDO',
                                      style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 1.7,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(dialogContext)
                                              .colorScheme
                                              .onSurfaceVariant))),
                              IconButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close_rounded))
                            ]),
                            Text('Opciones de entrega y pago',
                                style:
                                    GoogleFonts.dmSerifDisplay(fontSize: 27)),
                            const SizedBox(height: 6),
                            Text(
                                'Revisa tus datos antes de generar el comprobante.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 20),
                            TextField(
                                controller: addressController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                    labelText: 'Dirección de entrega',
                                    hintText:
                                        'Colonia, calle, punto de referencia',
                                    prefixIcon:
                                        Icon(Icons.location_on_outlined))),
                            const SizedBox(height: 12),
                            TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                    labelText: 'Teléfono de contacto',
                                    prefixIcon: Icon(Icons.phone_outlined))),
                            const SizedBox(height: 16),
                            Text('MÉTODO DE PAGO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(height: 8),
                            ...[
                              'Efectivo contra entrega',
                              'Transferencia bancaria',
                              'Tarjeta (demostración)'
                            ].map((method) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setDialogState(
                                        () => paymentMethod = method),
                                    child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: paymentMethod == method
                                                ? const Color(0xFFEAF0F4)
                                                : Theme.of(dialogContext)
                                                    .colorScheme
                                                    .surface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: paymentMethod == method
                                                    ? const Color(0xFF35495C)
                                                    : Theme.of(dialogContext)
                                                        .colorScheme
                                                        .outlineVariant)),
                                        child: Row(children: [
                                          Icon(
                                              method.startsWith('Efectivo')
                                                  ? Icons.payments_outlined
                                                  : method.startsWith(
                                                          'Transferencia')
                                                      ? Icons
                                                          .account_balance_outlined
                                                      : Icons
                                                          .credit_card_outlined,
                                              size: 19),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Text(method,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700))),
                                          if (paymentMethod == method)
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                size: 18)
                                        ]))))),
                            if (paymentMethod == 'Tarjeta (demostración)')
                              Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Text(
                                      'Modo de demostración: no se realizará ningún cargo. Para aceptar pagos reales se debe integrar un proveedor de pagos.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(dialogContext)
                                              .colorScheme
                                              .onSurfaceVariant))),
                            const SizedBox(height: 12),
                            Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Theme.of(dialogContext)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: .75),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Column(children: [
                                  Row(children: [
                                    const Text('Subtotal'),
                                    const Spacer(),
                                    Text(money(cartTotal))
                                  ]),
                                  const SizedBox(height: 7),
                                  const Row(children: [
                                    Text('Envío'),
                                    Spacer(),
                                    Text('L 80')
                                  ]),
                                  const Divider(height: 20),
                                  Row(children: [
                                    const Text('Total',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900)),
                                    const Spacer(),
                                    Text(money(cartTotal + 80),
                                        style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900))
                                  ])
                                ])),
                            if (validationMessage != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(validationMessage!,
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 12))),
                            const SizedBox(height: 15),
                            SizedBox(
                                width: double.infinity,
                                height: 49,
                                child: FilledButton.icon(
                                    onPressed: () {
                                      if (addressController.text
                                              .trim()
                                              .isEmpty ||
                                          phoneController.text.trim().isEmpty) {
                                        setDialogState(() => validationMessage =
                                            'Completa la dirección y el teléfono para continuar.');
                                        return;
                                      }
                                      final address =
                                          addressController.text.trim();
                                      final phone = phoneController.text.trim();
                                      Navigator.pop(dialogContext);
                                      _placeOrder(
                                          address: address,
                                          phone: phone,
                                          paymentMethod: paymentMethod);
                                    },
                                    icon:
                                        const Icon(Icons.receipt_long_outlined),
                                    label: const Text(
                                        'CONFIRMAR PEDIDO Y GENERAR PDF'))),
                          ])),
                ),
              )),
    );
    addressController.dispose();
    phoneController.dispose();
  }

  Future<void> _placeOrder(
      {required String address,
      required String phone,
      required String paymentMethod}) async {
    final now = DateTime.now();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Inicia sesión para registrar el pedido.')));
      }
      return;
    }
    final orderId = now.microsecondsSinceEpoch.toString().substring(7);
    final lines = catalogProducts.value
        .where((p) => (cart[p.id] ?? 0) > 0)
        .map((p) => DeliveryOrderLine(
              productId: p.id,
              name: p.name,
              price: priceFor(p),
              quantity: cart[p.id]!,
              color: cartColors[p.id] ?? 'Negro',
              size: cartSizes[p.id] ??
                  (p.category == 'Vestimenta' ? 'M' : 'Única'),
            ))
        .toList();
    final unavailable = lines
        .where((line) =>
            (inventoryCounts.value[line.productId] ?? 0) < line.quantity)
        .toList();
    if (unavailable.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Stock insuficiente para ${unavailable.first.name}. Ajusta la cantidad antes de comprar.'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.total);
    var order = DeliveryOrder(
      id: orderId,
      customer: currentUser?.name ?? 'Cliente',
      email: currentUser?.email ?? '',
      phone: phone,
      address: address,
      paymentMethod: paymentMethod,
      lines: lines,
      subtotal: subtotal,
      shipping: 80,
      total: subtotal + 80,
      createdAt: now,
      status: DeliveryOrderStatus.preparing,
    );
    try {
      final savedOrder = await supabase
          .from('orders')
          .insert({
            'user_id': userId,
            'customer_name': order.customer,
            'customer_email': order.email,
            'phone': order.phone,
            'delivery_address': order.address,
            'payment_method': order.paymentMethod,
            'status': 'preparing',
            'subtotal': order.subtotal,
            'shipping': order.shipping,
            'total': order.total,
          })
          .select('id')
          .single();
      final dbOrderId = savedOrder['id'].toString();
      await supabase.from('order_items').insert(lines
          .map((line) => {
                'order_id': dbOrderId,
                'product_id': line.productId,
                'product_name': line.name,
                'unit_price': line.price,
                'quantity': line.quantity,
                'color': line.color,
                'size': line.size,
                'line_total': line.total,
              })
          .toList());
      order = DeliveryOrder(
          id: dbOrderId,
          customer: order.customer,
          email: order.email,
          phone: order.phone,
          address: order.address,
          paymentMethod: order.paymentMethod,
          lines: order.lines,
          subtotal: order.subtotal,
          shipping: order.shipping,
          total: order.total,
          createdAt: order.createdAt,
          status: order.status);
      final bytes = await createReceiptPdf(order);
      final receiptPath = '$userId/$dbOrderId.pdf';
      await supabase.storage.from('order-receipts').uploadBinary(
          receiptPath, bytes,
          fileOptions:
              const FileOptions(contentType: 'application/pdf', upsert: true));
      await supabase
          .from('orders')
          .update({'receipt_path': receiptPath}).eq('id', dbOrderId);
      order = order.copyWith(receiptBytes: bytes);
      deliveryOrders.value = [order, ...deliveryOrders.value];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo guardar el pedido en Supabase: $e')));
      }
      return;
    }
    final updatedStock = Map<int, int>.from(inventoryCounts.value);
    for (final line in lines) {
      updatedStock[line.productId] =
          ((updatedStock[line.productId] ?? 0) - line.quantity)
              .clamp(0, 999999)
              .toInt();
    }
    inventoryCounts.value = updatedStock;
    for (final line in lines) {
      try {
        await supabase.from('products').update(
            {'stock': updatedStock[line.productId]}).eq('id', line.productId);
      } catch (_) {
        /* El stock del servidor se valida también al consultar el catálogo. */
      }
    }
    setState(() {
      cart.clear();
      cartColors.clear();
      cartSizes.clear();
    });
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF2D7565), size: 42),
              title: const Text('Pedido registrado'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedido #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                        'El administrador ya puede ver este pedido en el panel de delivery.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 15),
                    _OrderStatusTimeline(status: order.status),
                  ]),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      showMyOrders();
                    },
                    child: const Text('Ver mis pedidos')),
                FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openReceipt(order);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ver comprobante PDF')),
              ],
            ));
  }

  Future<void> _openReceipt(DeliveryOrder order) async {
    final bytes = order.receiptBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(
        name: 'delivery_pedido_${order.id}.pdf', onLayout: (_) async => bytes);
  }

  Future<void> _refreshMyOrders() async {
    final userId = currentUser?.userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      final parsed = <DeliveryOrder>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final items =
            (row['order_items'] as List? ?? []).cast<Map<String, dynamic>>();
        final statusText =
            (row['status'] ?? 'preparing').toString().toLowerCase();
        final status = (statusText == 'delivered' || statusText == 'entregado')
            ? DeliveryOrderStatus.delivered
            : (statusText == 'shipped' || statusText == 'enviado')
                ? DeliveryOrderStatus.shipped
                : DeliveryOrderStatus.preparing;
        Uint8List? receipt;
        final path = (row['receipt_path'] ?? '').toString();
        if (path.isNotEmpty) {
          try {
            receipt =
                await supabase.storage.from('order-receipts').download(path);
          } catch (_) {}
        }
        parsed.add(DeliveryOrder(
            id: row['id'].toString(),
            customer: (row['customer_name'] ?? '').toString(),
            email: (row['customer_email'] ?? '').toString(),
            phone: (row['phone'] ?? '').toString(),
            address: (row['delivery_address'] ?? '').toString(),
            paymentMethod: (row['payment_method'] ?? '').toString(),
            lines: items
                .map((i) => DeliveryOrderLine(
                    productId: (i['product_id'] as num?)?.toInt() ?? 0,
                    name: (i['product_name'] ?? '').toString(),
                    price: (i['unit_price'] as num).toInt(),
                    quantity: (i['quantity'] as num).toInt(),
                    color: (i['color'] ?? '').toString(),
                    size: (i['size'] ?? '').toString()))
                .toList(),
            subtotal: (row['subtotal'] as num).toInt(),
            shipping: (row['shipping'] as num).toInt(),
            total: (row['total'] as num).toInt(),
            createdAt: DateTime.tryParse(row['created_at'].toString()) ??
                DateTime.now(),
            status: status,
            receiptBytes: receipt));
      }
      final others = deliveryOrders.value
          .where((o) => o.email != currentUser?.email)
          .toList();
      deliveryOrders.value = [...parsed, ...others];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudieron actualizar tus pedidos: $e')));
      }
    }
  }

  void showMyOrders() {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;
    _refreshMyOrders();
    final liveOrders = supabase
        .channel('customer-orders-${currentUser?.userId ?? 'guest'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _refreshMyOrders(),
        )
        .subscribe();

    showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 720, maxHeight: screenSize.height - 48),
                child: SizedBox(
                  width: (screenSize.width - 32).clamp(0.0, 720.0).toDouble(),
                  height: screenSize.height * (isCompact ? .76 : .68),
                  child: ValueListenableBuilder<List<DeliveryOrder>>(
                    valueListenable: deliveryOrders,
                    builder: (context, orders, _) {
                      final mine = orders
                          .where((o) =>
                              currentUser == null ||
                              o.email == currentUser!.email)
                          .toList();
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Mis pedidos',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: mine.isEmpty
                                ? const Center(
                                    child: Text('Todavía no tienes pedidos.'))
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: mine.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final order = mine[index];
                                      return Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Pedido #${order.id}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900),
                                                  ),
                                                ),
                                                Text(
                                                  money(order.total),
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            _OrderStatusTimeline(
                                                status: order.status),
                                            const SizedBox(height: 10),
                                            Text(
                                              '${order.lines.length} tipos de artículo · ${order.paymentMethod}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    _openReceipt(order),
                                                icon: const Icon(
                                                    Icons
                                                        .picture_as_pdf_outlined,
                                                    size: 17),
                                                label: const Text(
                                                    'Comprobante PDF'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            )).whenComplete(() => supabase.removeChannel(liveOrders));
  }

  void clearFilters() {
    setState(() {
      category = 'Todo';
      gender = 'Todos';
      query = '';
      searchController.clear();
      sort = 'Destacados';
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final themeModeToggle = IconButton(
      tooltip: appThemeMode.value == ThemeMode.dark
          ? 'Activar modo claro'
          : 'Activar modo oscuro',
      onPressed: () => appThemeMode.value = appThemeMode.value == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
      icon: Icon(appThemeMode.value == ThemeMode.dark
          ? Icons.light_mode_rounded
          : Icons.dark_mode_rounded),
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: ForjaBrand(onTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }),
        actions: [
          if (!isCompact) themeModeToggle,
          if (currentUser?.role.toLowerCase() == 'admin')
            IconButton(
              tooltip: 'Panel administrativo',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => AdminPanelPage(user: currentUser))),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: currentUser == null ? 'Iniciar sesión' : 'Mi cuenta',
            onPressed: showAccount,
            icon: _restoringSession
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(currentUser == null
                    ? Icons.person_outline_rounded
                    : Icons.account_circle_rounded),
          ),
          IconButton(
            tooltip: 'Buscar productos',
            onPressed: () => setState(() => searchVisible = !searchVisible),
            icon: Icon(
                searchVisible ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Mis pedidos',
            onPressed: showMyOrders,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              tooltip: 'Abrir carrito',
              onPressed: openCart,
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
        bottom: searchVisible || isCompact
            ? PreferredSize(
                preferredSize: Size.fromHeight(
                    (isCompact ? 40.0 : 0.0) + (searchVisible ? 64.0 : 0.0)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompact)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: SizedBox(
                            height: 40,
                            child: themeModeToggle,
                          ),
                        ),
                      ),
                    if (searchVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) => setState(() => query = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar productos...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('products')
              .stream(primaryKey: ['id'])
              .eq('active', true)
              .order('id'),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _syncProductRows(productSnapshot.data!);
              });
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              width: 4,
                              height: 30,
                              decoration: BoxDecoration(
                                  color: navy,
                                  borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 11),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('IMFFAA / CATÁLOGO',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.8,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                                const SizedBox(height: 3),
                                Text('Equipo y vestimenta',
                                    style: GoogleFonts.dmSerifDisplay(
                                        fontSize: 28,
                                        height: 1.1,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                              ])),
                        ]),
                        const SizedBox(height: 8),
                        Text('Diseño funcional. Selección esencial.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final value = categories[i];
                              return ChoiceChip(
                                label: Text(value),
                                selected: category == value,
                                onSelected: (_) =>
                                    setState(() => category = value),
                                selectedColor: navy,
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                labelStyle: TextStyle(
                                  color:
                                      category == value ? Colors.white : slate,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                    color: category == value ? navy : line),
                                shape: const StadiumBorder(),
                                showCheckmark: false,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text('GÉNERO',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 34,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: genders.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (context, i) {
                                    final value = genders[i];
                                    final selected = gender == value;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          setState(() => gender = value),
                                      child: Container(
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 11),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: selected
                                                  ? const Color(0xFFB5C79A)
                                                  : line),
                                        ),
                                        child: Text(value,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('${filtered.length} productos',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                            const Spacer(),
                            Icon(Icons.tune_rounded,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 4),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: sort,
                                isDense: true,
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Destacados',
                                      child: Text('Destacados')),
                                  DropdownMenuItem(
                                      value: 'Precio menor',
                                      child: Text('Precio menor')),
                                  DropdownMenuItem(
                                      value: 'Precio mayor',
                                      child: Text('Precio mayor')),
                                ],
                                onChanged: (value) => setState(
                                    () => sort = value ?? 'Destacados'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 34,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text('No encontramos productos',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Prueba otra búsqueda o cambia los filtros.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12)),
                          TextButton(
                              onPressed: clearFilters,
                              child: const Text('Limpiar filtros')),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = MediaQuery.sizeOf(context).width;
                        final columns = width >= 1000
                            ? 4
                            : width >= 680
                                ? 3
                                : 2;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            mainAxisExtent: width < 370
                                ? 360
                                : width < 600
                                    ? 390
                                    : 420,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => ProductCard(
                                product: filtered[index],
                                quantity: cart[filtered[index].id] ?? 0,
                                onAdd: () => add(filtered[index]),
                                onIncrement: () => add(filtered[index]),
                                onDecrement: () =>
                                    changeQuantity(filtered[index], -1),
                                onOpen: () =>
                                    openProductDetails(filtered[index])),
                            childCount: filtered.length,
                          ),
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: const SizedBox(height: 26)),
              ],
            );
          },
        ),
      ),
    );
  }

  void openCart() {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, modalSetState) {
          void update(Product product, int delta) {
            changeQuantity(product, delta);
            modalSetState(() {});
          }

          final items = catalogProducts.value
              .where((p) => (cart[p.id] ?? 0) > 0)
              .toList();
          return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 720, maxHeight: screenSize.height - 48),
                child: SizedBox(
                  width: (screenSize.width - 32).clamp(0.0, 720.0).toDouble(),
                  height: screenSize.height * (isCompact ? .76 : .68),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TU SELECCIÓN',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 10,
                                          letterSpacing: 1.6,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('Carrito ($cartCount)',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded)),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant),
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(30),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shopping_bag_outlined,
                                          size: 42,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      const Text('Tu carrito está vacío',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16)),
                                      const SizedBox(height: 6),
                                      Text(
                                          'Explora el catálogo y añade lo que necesitas.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 24,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                                itemBuilder: (context, i) {
                                  final product = items[i];
                                  final quantity = cart[product.id] ?? 0;
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 82,
                                          height: 96,
                                          child:
                                              ProductImage(url: product.image),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(product.name,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const SizedBox(height: 4),
                                            Text(money(priceFor(product)),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            const SizedBox(height: 8),
                                            _SelectionDropdown<String>(
                                                label: 'COLOR',
                                                value: cartColors[product.id] ??
                                                    'Verde oliva',
                                                items: const [
                                                  'Verde oliva',
                                                  'Negro',
                                                  'Gris',
                                                  'Arena'
                                                ],
                                                compact: true,
                                                onChanged: (value) {
                                                  setState(() =>
                                                      cartColors[product.id] =
                                                          value);
                                                  modalSetState(() {});
                                                }),
                                            const SizedBox(height: 6),
                                            _SelectionDropdown<String>(
                                                label: 'TALLA',
                                                value: cartSizes[product.id] ??
                                                    (product.category ==
                                                            'Calzado'
                                                        ? 'M (40–41)'
                                                        : product.category ==
                                                                'Vestimenta'
                                                            ? 'M'
                                                            : 'Única'),
                                                items: product.category ==
                                                        'Calzado'
                                                    ? const [
                                                        'S (38–39)',
                                                        'M (40–41)',
                                                        'L (42–43)',
                                                        'XL (44–45)'
                                                      ]
                                                    : product.category ==
                                                            'Vestimenta'
                                                        ? const [
                                                            'XS',
                                                            'S',
                                                            'M',
                                                            'L',
                                                            'XL',
                                                            'XXL'
                                                          ]
                                                        : const ['Única'],
                                                compact: true,
                                                onChanged: (value) {
                                                  setState(() =>
                                                      cartSizes[product.id] =
                                                          value);
                                                  modalSetState(() {});
                                                }),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                QuantityButton(
                                                    icon: Icons.remove,
                                                    onTap: () =>
                                                        update(product, -1)),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  child: Text('$quantity',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                                ),
                                                QuantityButton(
                                                    icon: Icons.add,
                                                    onTap: () =>
                                                        update(product, 1)),
                                                const Spacer(),
                                                IconButton(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    setState(() {
                                                      cart.remove(product.id);
                                                      cartColors
                                                          .remove(product.id);
                                                      cartSizes
                                                          .remove(product.id);
                                                    });
                                                    modalSetState(() {});
                                                  },
                                                  icon: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 19,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      if (items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border(
                                  top: BorderSide(
                                      color: Theme.of(context).dividerColor))),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('Subtotal',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 13)),
                                  const Spacer(),
                                  Text(money(cartTotal),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'El envío y la confirmación se calculan al conectar el proceso de compra.',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 10)),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10))),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    openCheckout();
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      size: 18),
                                  label: const Text('CONTINUAR COMPRA',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ));
        },
      ),
    ).whenComplete(() => setState(() {}));
  }
}

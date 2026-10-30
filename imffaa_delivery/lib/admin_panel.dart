part of 'main.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key, this.user});
  final AuthResult? user;
  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  RealtimeChannel? _ordersChannel;
  List<Map<String, dynamic>> _profiles = [];
  bool _loadingProfiles = false;
  String _ordersQuery = '';
  String _productsQuery = '';
  String _profilesQuery = '';

  Future<void> _loadProfiles() async {
    setState(() => _loadingProfiles = true);
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, full_name, role, created_at')
          .order('created_at', ascending: false);
      if (mounted)
        setState(() {
          _profiles =
              rows.map((row) => Map<String, dynamic>.from(row)).toList();
          _loadingProfiles = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfiles = false);
        showAppToast(context,
            'No se pudieron cargar usuarios. Comprueba los permisos RLS: $e',
            isError: true);
      }
    }
  }

  Future<void> _changeUserRole(
      Map<String, dynamic> profile, String role) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': role}).eq('id', profile['id']);
      if (!mounted) return;
      setState(() {
        profile['role'] = role;
      });
      showAppToast(context,
          'Rol actualizado para ${profile['full_name'] ?? 'el usuario'}.');
    } catch (e) {
      if (mounted)
        showAppToast(context,
            'No se pudo cambiar el rol. Verifica las políticas RLS: $e',
            isError: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOrdersFromSupabase();
    loadProductsFromSupabase().then((_) {
      if (mounted) setState(() {});
    });
    _ordersChannel = supabase
        .channel('admin-orders-live')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (_) => _loadOrdersFromSupabase())
        .subscribe();
  }

  Future<void> _loadOrdersFromSupabase() async {
    try {
      final rows = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false);
      final parsed = <DeliveryOrder>[];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final itemRows =
            (row['order_items'] as List? ?? []).cast<Map<String, dynamic>>();
        final lines = itemRows
            .map((item) => DeliveryOrderLine(
                  productId: (item['product_id'] as num?)?.toInt() ?? 0,
                  name: (item['product_name'] ?? '').toString(),
                  price: (item['unit_price'] as num).toInt(),
                  quantity: (item['quantity'] as num).toInt(),
                  color: (item['color'] ?? '').toString(),
                  size: (item['size'] ?? '').toString(),
                ))
            .toList();
        final statusText = (row['status'] ?? 'preparing').toString();
        final status = statusText == 'delivered'
            ? DeliveryOrderStatus.delivered
            : statusText == 'shipped'
                ? DeliveryOrderStatus.shipped
                : DeliveryOrderStatus.preparing;
        parsed.add(DeliveryOrder(
            id: row['id'].toString(),
            customer: (row['customer_name'] ?? '').toString(),
            email: (row['customer_email'] ?? '').toString(),
            phone: (row['phone'] ?? '').toString(),
            address: (row['delivery_address'] ?? '').toString(),
            paymentMethod: (row['payment_method'] ?? '').toString(),
            lines: lines,
            subtotal: (row['subtotal'] as num).toInt(),
            shipping: (row['shipping'] as num).toInt(),
            total: (row['total'] as num).toInt(),
            createdAt: DateTime.tryParse(row['created_at'].toString()) ??
                DateTime.now(),
            status: status,
            receiptBytes: await _tryDownloadReceipt(
                (row['receipt_path'] ?? '').toString())));
      }
      deliveryOrders.value = parsed;
    } catch (_) {
      /* RLS o conexión no disponible; no se ocultan los errores de acciones */
    }
  }

  Future<Uint8List?> _tryDownloadReceipt(String path) async {
    if (path.isEmpty) return null;
    try {
      return await supabase.storage.from('order-receipts').download(path);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    if (_ordersChannel != null) supabase.removeChannel(_ordersChannel!);
    super.dispose();
  }

  Future<void> _changeStatus(
      DeliveryOrder order, DeliveryOrderStatus status) async {
    try {
      await supabase.from('orders').update({
        'status': status == DeliveryOrderStatus.preparing
            ? 'preparing'
            : status == DeliveryOrderStatus.shipped
                ? 'shipped'
                : 'delivered'
      }).eq('id', order.id);
      deliveryOrders.value = deliveryOrders.value
          .map((item) =>
              item.id == order.id ? item.copyWith(status: status) : item)
          .toList();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo actualizar el pedido: $e')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pedido #${order.id}: ${orderStatusLabel(status)}'),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _createProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController(text: '0');
    final description = TextEditingController();
    final colors = TextEditingController(text: 'Negro, Verde bosque');
    final sizes = TextEditingController(text: 'Única');
    final features = TextEditingController();
    final imageUrl = TextEditingController();
    const categories = <String>[
      'Vestimenta',
      'Calzado',
      'Equipo',
      'Accesorios'
    ];
    String category = 'Accesorios';
    Uint8List? imageBytes;
    String? pickedName;
    bool saving = false;
    bool requiresAuthorization = false;
    int section = 0;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Añadir producto',
                style: GoogleFonts.dmSerifDisplay(fontSize: 24)),
            content: SizedBox(
              width: (MediaQuery.sizeOf(dialogContext).width - 64)
                  .clamp(0.0, 520.0)
                  .toDouble(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * .62),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final entry in ['General', 'Variantes', 'Imágenes']
                            .asMap()
                            .entries)
                          ChoiceChip(
                              label: Text(entry.value),
                              selected: section == entry.key,
                              onSelected: saving
                                  ? null
                                  : (_) => setDialogState(
                                      () => section = entry.key)),
                      ]),
                      const SizedBox(height: 14),
                      if (section == 0) ...[
                        TextField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Nombre del producto *')),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: price,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Precio (L) *'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: stock,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Stock *'))),
                        ]),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            initialValue: category,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Categoría'),
                            items: categories
                                .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null)
                                      setDialogState(() => category = value);
                                  }),
                        const SizedBox(height: 10),
                        TextField(
                            controller: description,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Descripción')),
                        const SizedBox(height: 8),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: requiresAuthorization,
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => requiresAuthorization = value),
                            title: const Text('Requiere autorización'),
                            subtitle: const Text(
                                'Restringe la compra a usuarios autorizados.'),
                            secondary: const Icon(Icons.lock_outline_rounded)),
                      ] else if (section == 1) ...[
                        TextField(
                            controller: colors,
                            decoration: const InputDecoration(
                                labelText: 'Colores',
                                helperText: 'Separados por comas')),
                        const SizedBox(height: 12),
                        TextField(
                            controller: sizes,
                            decoration: const InputDecoration(
                                labelText: 'Tallas',
                                helperText:
                                    'Separadas por comas; usa Única si no aplica')),
                        const SizedBox(height: 12),
                        TextField(
                            controller: features,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                labelText: 'Características',
                                helperText: 'Separadas por comas')),
                      ] else ...[
                        if (imageBytes != null)
                          Text('Imagen seleccionada: ${pickedName ?? 'imagen'}')
                        else
                          const Text(
                              'Puedes pegar una URL o seleccionar una imagen del equipo.'),
                        const SizedBox(height: 10),
                        TextField(
                            controller: imageUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                                labelText: 'URL de imagen (opcional)',
                                hintText: 'https://...')),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final file = await ImagePicker().pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 82,
                                        maxWidth: 1600);
                                    if (file != null) {
                                      imageBytes = await file.readAsBytes();
                                      pickedName = file.name;
                                      setDialogState(() {});
                                    }
                                  },
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Elegir imagen del equipo')),
                      ],
                      if (saving)
                        const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: LinearProgressIndicator()),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar')),
              FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final parsedPrice = int.tryParse(price.text.trim());
                          final parsedStock = int.tryParse(stock.text.trim());
                          if (name.text.trim().isEmpty ||
                              parsedPrice == null ||
                              parsedPrice < 0 ||
                              parsedStock == null ||
                              parsedStock < 0) {
                            showAppToast(context,
                                'Revisa nombre, precio y stock. Deben tener valores válidos.',
                                isError: true);
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            var image = imageUrl.text.trim();
                            if (imageBytes != null) {
                              final rawExtension =
                                  (pickedName ?? 'producto.jpg')
                                      .split('.')
                                      .last
                                      .toLowerCase();
                              final extension = ['jpg', 'jpeg', 'png', 'webp']
                                      .contains(rawExtension)
                                  ? rawExtension
                                  : 'jpg';
                              final path =
                                  'products/${DateTime.now().microsecondsSinceEpoch}.$extension';
                              await supabase.storage
                                  .from('product-images')
                                  .uploadBinary(path, imageBytes!,
                                      fileOptions:
                                          const FileOptions(upsert: false));
                              image = supabase.storage
                                  .from('product-images')
                                  .getPublicUrl(path);
                            }
                            final parsedColors = colors.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final parsedSizes = sizes.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final parsedFeatures = features.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                            final row = await supabase
                                .from('products')
                                .insert({
                                  'name': name.text.trim(),
                                  'description': description.text.trim(),
                                  'category': category,
                                  'gender': 'Unisex',
                                  'image_url': image,
                                  'price': parsedPrice,
                                  'stock': parsedStock,
                                  'colors': parsedColors,
                                  'sizes': parsedSizes,
                                  'features': parsedFeatures,
                                  'requires_authorization':
                                      requiresAuthorization,
                                  'active': true,
                                })
                                .select()
                                .single();
                            final id = (row['id'] as num).toInt();
                            final product = Product(
                                id: id,
                                name: name.text.trim(),
                                category: category,
                                gender: 'Unisex',
                                price: parsedPrice,
                                description: description.text.trim(),
                                image: image,
                                colors: parsedColors,
                                sizes: parsedSizes,
                                features: parsedFeatures,
                                requiresAuthorization: requiresAuthorization);
                            catalogProducts.value = [
                              ...catalogProducts.value,
                              product
                            ];
                            inventoryCounts.value = {
                              ...inventoryCounts.value,
                              id: parsedStock
                            };
                            productPrices.value = {
                              ...productPrices.value,
                              id: parsedPrice
                            };
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              setState(() {});
                              showAppToast(
                                  context, 'Producto guardado correctamente.');
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (mounted)
                              showAppToast(
                                  context, 'No se pudo guardar el producto: $e',
                                  isError: true);
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar producto')),
            ],
          ),
        ),
      );
    } finally {
      for (final controller in [
        name,
        price,
        stock,
        description,
        colors,
        sizes,
        features,
        imageUrl
      ]) {
        controller.dispose();
      }
    }
  }

  Future<void> _editProduct(Product product) async {
    final name = TextEditingController(text: product.name);
    final price = TextEditingController(text: '${priceFor(product)}');
    final stock = TextEditingController(
        text: '${inventoryCounts.value[product.id] ?? 0}');
    final description = TextEditingController(text: product.description);
    final colors = TextEditingController(text: product.colors.join(', '));
    final sizes = TextEditingController(text: product.sizes.join(', '));
    final features = TextEditingController(text: product.features.join(', '));
    final imageUrl = TextEditingController(text: product.image);
    final categories = <String>[
      'Vestimenta',
      'Calzado',
      'Equipo',
      'Accesorios',
      'Otro'
    ];
    String category =
        categories.contains(product.category) ? product.category : 'Otro';
    Uint8List? imageBytes;
    String? pickedName;
    bool saving = false;
    bool requiresAuthorization = product.requiresAuthorization;
    int section = 0;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
                  title: Text('Editar producto',
                      style: GoogleFonts.dmSerifDisplay(fontSize: 24)),
                  content: SizedBox(
                      width: (MediaQuery.sizeOf(dialogContext).width - 64)
                          .clamp(0.0, 520.0)
                          .toDouble(),
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(dialogContext).height *
                                      .62),
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 2),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(spacing: 6, children: [
                                      for (final entry in [
                                        'General',
                                        'Variantes',
                                        'Imágenes'
                                      ].asMap().entries)
                                        ChoiceChip(
                                            label: Text(entry.value),
                                            selected: section == entry.key,
                                            onSelected: (_) => setDialogState(
                                                () => section = entry.key))
                                    ]),
                                    const SizedBox(height: 14),
                                    if (section == 0) ...[
                                      TextField(
                                          controller: name,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Nombre del producto *')),
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        Expanded(
                                            child: TextField(
                                                controller: price,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            'Precio (L) *'))),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: TextField(
                                                controller: stock,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'Stock *')))
                                      ]),
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                          initialValue: category,
                                          isExpanded: true,
                                          decoration: const InputDecoration(
                                              labelText: 'Categoría'),
                                          items: categories
                                              .map((c) => DropdownMenuItem(
                                                  value: c,
                                                  child: Text(c == 'Otro'
                                                      ? 'Otra / personalizada'
                                                      : c)))
                                              .toList(),
                                          onChanged: (v) => setDialogState(
                                              () => category = v ?? category)),
                                      if (category == 'Otro')
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                                'Para una categoría personalizada, usa el campo de descripción para especificarla.',
                                                style:
                                                    TextStyle(fontSize: 11))),
                                      const SizedBox(height: 10),
                                      TextField(
                                          controller: description,
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                              labelText: 'Descripción')),
                                      const SizedBox(height: 8),
                                      SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          value: requiresAuthorization,
                                          onChanged: saving
                                              ? null
                                              : (value) => setDialogState(() =>
                                                  requiresAuthorization =
                                                      value),
                                          title: const Text(
                                              'Requiere autorización'),
                                          subtitle: const Text(
                                              'Restringe la compra a usuarios autorizados.'),
                                          secondary: const Icon(
                                              Icons.lock_outline_rounded)),
                                    ] else if (section == 1) ...[
                                      TextField(
                                          controller: colors,
                                          decoration: const InputDecoration(
                                              labelText: 'Colores',
                                              helperText:
                                                  'Separados por comas: Negro, Verde oliva')),
                                      const SizedBox(height: 12),
                                      TextField(
                                          controller: sizes,
                                          decoration: const InputDecoration(
                                              labelText: 'Tallas',
                                              helperText:
                                                  'Separadas por comas; usa Única si no aplica')),
                                      const SizedBox(height: 12),
                                      TextField(
                                          controller: features,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                              labelText: 'Características',
                                              helperText:
                                                  'Separadas por comas')),
                                    ] else ...[
                                      if (imageBytes != null)
                                        Text(
                                            'Nueva imagen seleccionada: ${pickedName ?? 'imagen'}')
                                      else if (product.image.isNotEmpty)
                                        ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(product.image,
                                                height: 130,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox(
                                                        height: 70,
                                                        child: Center(
                                                            child: Text(
                                                                'No se pudo cargar la imagen actual'))))),
                                      const SizedBox(height: 12),
                                      TextField(
                                          controller: imageUrl,
                                          decoration: const InputDecoration(
                                              labelText: 'URL de imagen',
                                              hintText: 'https://...')),
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                          onPressed: saving
                                              ? null
                                              : () async {
                                                  final file =
                                                      await ImagePicker()
                                                          .pickImage(
                                                              source:
                                                                  ImageSource
                                                                      .gallery,
                                                              imageQuality: 82,
                                                              maxWidth: 1600);
                                                  if (file != null) {
                                                    imageBytes = await file
                                                        .readAsBytes();
                                                    pickedName = file.name;
                                                    setDialogState(() {});
                                                  }
                                                },
                                          icon:
                                              const Icon(Icons.image_outlined),
                                          label: const Text(
                                              'Reemplazar imagen desde el equipo')),
                                    ],
                                    if (saving)
                                      const Padding(
                                          padding: EdgeInsets.only(top: 14),
                                          child: LinearProgressIndicator()),
                                  ])))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar')),
                    FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final parsedPrice =
                                    int.tryParse(price.text.trim());
                                final parsedStock =
                                    int.tryParse(stock.text.trim());
                                if (name.text.trim().isEmpty ||
                                    parsedPrice == null ||
                                    parsedPrice < 0 ||
                                    parsedStock == null ||
                                    parsedStock < 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Revisa nombre, precio y stock.')));
                                  return;
                                }
                                setDialogState(() => saving = true);
                                try {
                                  String image = imageUrl.text.trim();
                                  if (imageBytes != null) {
                                    final extension =
                                        (pickedName ?? 'producto.jpg')
                                            .split('.')
                                            .last
                                            .toLowerCase();
                                    final path =
                                        'products/${product.id}_${DateTime.now().microsecondsSinceEpoch}.$extension';
                                    await supabase.storage
                                        .from('product-images')
                                        .uploadBinary(path, imageBytes!,
                                            fileOptions: const FileOptions(
                                                upsert: true));
                                    image = supabase.storage
                                        .from('product-images')
                                        .getPublicUrl(path);
                                  }
                                  final chosenCategory = category == 'Otro'
                                      ? (product.category == 'Otro'
                                          ? 'Accesorios'
                                          : product.category)
                                      : category;
                                  await supabase.from('products').update({
                                    'name': name.text.trim(),
                                    'description': description.text.trim(),
                                    'category': chosenCategory,
                                    'image_url': image,
                                    'price': parsedPrice,
                                    'stock': parsedStock,
                                    'colors': colors.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                    'sizes': sizes.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                    'features': features.text
                                        .split(',')
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList(),
                                    'requires_authorization':
                                        requiresAuthorization
                                  }).eq('id', product.id);
                                  catalogProducts.value = catalogProducts.value
                                      .map((p) => p.id == product.id
                                          ? Product(
                                              id: p.id,
                                              name: name.text.trim(),
                                              category: chosenCategory,
                                              gender: p.gender,
                                              price: parsedPrice,
                                              oldPrice: p.oldPrice,
                                              description:
                                                  description.text.trim(),
                                              image: image,
                                              tag: p.tag,
                                              requiresAuthorization:
                                                  requiresAuthorization,
                                              features: features.text
                                                  .split(',')
                                                  .map((e) => e.trim())
                                                  .where((e) => e.isNotEmpty)
                                                  .toList(),
                                              colors: colors.text
                                                  .split(',')
                                                  .map((e) => e.trim())
                                                  .where((e) => e.isNotEmpty)
                                                  .toList(),
                                              sizes: sizes.text
                                                  .split(',')
                                                  .map((e) => e.trim())
                                                  .where((e) => e.isNotEmpty)
                                                  .toList())
                                          : p)
                                      .toList();
                                  productPrices.value = {
                                    ...productPrices.value,
                                    product.id: parsedPrice
                                  };
                                  inventoryCounts.value = {
                                    ...inventoryCounts.value,
                                    product.id: parsedStock
                                  };
                                  await loadProductsFromSupabase();
                                  if (mounted) {
                                    Navigator.pop(dialogContext);
                                    setState(() {});
                                    showAppToast(context,
                                        'Producto actualizado correctamente.');
                                  }
                                } catch (e) {
                                  setDialogState(() => saving = false);
                                  if (mounted)
                                    showAppToast(context,
                                        'No se guardaron los cambios: $e',
                                        isError: true);
                                }
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar cambios'))
                  ],
                )));
    for (final c in [
      name,
      price,
      stock,
      description,
      colors,
      sizes,
      features,
      imageUrl
    ]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user?.role.toLowerCase() == 'admin';
    return Scaffold(
        appBar: AppBar(
            title: ForjaBrand(
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst)),
            actions: [
              IconButton(
                  tooltip: 'Volver al catálogo',
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.home_outlined))
            ]),
        body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                      children: [
                        Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF243240),
                                      Color(0xFF405468)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(20)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      color: Color(0xFFDCE6EF),
                                      size: 28),
                                  const SizedBox(height: 18),
                                  const Text('ADMINISTRACIÓN',
                                      style: TextStyle(
                                          color: Color(0xFFDCE6EF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.7)),
                                  const SizedBox(height: 7),
                                  Text('Centro de control',
                                      style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 29, color: Colors.white)),
                                  const SizedBox(height: 7),
                                  Text(
                                      isAdmin
                                          ? 'Sesión: ${widget.user?.name ?? 'Administrador'}'
                                          : 'Vista previa administrativa. En producción el rol debe venir de Supabase y validarse con RLS.',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.5)),
                                ])),
                        const SizedBox(height: 22),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                              initiallyExpanded: true,
                              leading:
                                  const Icon(Icons.local_shipping_outlined),
                              title: const Text('Pedidos en tiempo real',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: const Text(
                                  'Consultar pedidos, PDF y actualizar estados'),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 0, 14, 16),
                                    child:
                                        ValueListenableBuilder<
                                                List<DeliveryOrder>>(
                                            valueListenable: deliveryOrders,
                                            builder: (context, orders, _) {
                                              final visibleOrders = orders
                                                  .where((o) =>
                                                      '${o.id} ${o.customer} ${o.email} ${o.phone} ${o.status.name}'
                                                          .toLowerCase()
                                                          .contains(_ordersQuery
                                                              .toLowerCase()))
                                                  .toList();
                                              return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    TextField(
                                                        onChanged: (v) =>
                                                            setState(() =>
                                                                _ordersQuery =
                                                                    v),
                                                        decoration:
                                                            const InputDecoration(
                                                                prefixIcon:
                                                                    Icon(Icons
                                                                        .search),
                                                                hintText:
                                                                    'Buscar pedidos por número, cliente o estado')),
                                                    const SizedBox(height: 10),
                                                    if (visibleOrders.isEmpty)
                                                      Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(20),
                                                          child: Text(
                                                              orders.isEmpty
                                                                  ? 'Aún no hay pedidos registrados.'
                                                                  : 'No hay pedidos que coincidan con la búsqueda.',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center)),
                                                    ...visibleOrders
                                                        .map(
                                                            (order) =>
                                                                Container(
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            12),
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                            15),
                                                                    decoration: BoxDecoration(
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .surface,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                                16),
                                                                        border: Border.all(
                                                                            color: Theme.of(context)
                                                                                .colorScheme
                                                                                .outlineVariant)),
                                                                    child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Row(children: [
                                                                            Expanded(child: Text('Pedido #${order.id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                                                                            Text(money(order.total),
                                                                                style: const TextStyle(fontWeight: FontWeight.w900))
                                                                          ]),
                                                                          const SizedBox(
                                                                              height: 4),
                                                                          Text(
                                                                              '${order.customer} · ${order.phone}',
                                                                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                                          const SizedBox(
                                                                              height: 4),
                                                                          Text(
                                                                              '${order.lines.length} líneas · ${order.paymentMethod}',
                                                                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                                          const SizedBox(
                                                                              height: 4),
                                                                          Text(
                                                                              'Fecha: ${formatOrderDate(order.createdAt)}',
                                                                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                                                          const SizedBox(
                                                                              height: 12),
                                                                          _OrderStatusTimeline(
                                                                              status: order.status),
                                                                          const SizedBox(
                                                                              height: 12),
                                                                          Wrap(
                                                                              spacing: 8,
                                                                              runSpacing: 8,
                                                                              children: [
                                                                                OutlinedButton.icon(
                                                                                    onPressed: () async {
                                                                                      try {
                                                                                        final bytes = order.receiptBytes ?? await createReceiptPdf(order);
                                                                                        await Printing.layoutPdf(name: 'pedido_${order.id}.pdf', onLayout: (_) async => bytes);
                                                                                      } catch (e) {
                                                                                        if (mounted) showAppToast(context, 'No se pudo abrir el PDF: $e', isError: true);
                                                                                      }
                                                                                    },
                                                                                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                                                                                    label: const Text('Ver PDF')),
                                                                                OutlinedButton(onPressed: order.status == DeliveryOrderStatus.preparing ? () => _changeStatus(order, DeliveryOrderStatus.shipped) : null, child: const Text('Marcar enviado')),
                                                                                FilledButton(onPressed: order.status == DeliveryOrderStatus.shipped ? () => _changeStatus(order, DeliveryOrderStatus.delivered) : null, child: const Text('Marcar entregado')),
                                                                              ]),
                                                                        ])))
                                                  ]);
                                            })),
                              ]),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: const Text('Catálogo y almacén',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text(
                                'Agregar, editar productos e inventario'),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 16),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: _createProduct,
                                        icon: const Icon(Icons.add_rounded,
                                            size: 17),
                                        label: const Text('Añadir producto'),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                        onChanged: (v) =>
                                            setState(() => _productsQuery = v),
                                        decoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.search),
                                            hintText:
                                                'Buscar productos por nombre o categoría')),
                                    const SizedBox(height: 10),
                                    ValueListenableBuilder<Map<int, int>>(
                                      valueListenable: inventoryCounts,
                                      builder: (context, stock, _) => Column(
                                        children: catalogProducts.value
                                            .where((p) =>
                                                '${p.name} ${p.category}'
                                                    .toLowerCase()
                                                    .contains(_productsQuery
                                                        .toLowerCase()))
                                            .map((product) {
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant),
                                            ),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: SizedBox(
                                                    width: 52,
                                                    height: 56,
                                                    child: ProductImage(
                                                        url: product.image),
                                                  ),
                                                ),
                                                const SizedBox(width: 11),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(product.name,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${money(priceFor(product))} · Stock: ${stock[product.id] ?? 0}',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Editar precio y almacén',
                                                  onPressed: () =>
                                                      _editProduct(product),
                                                  icon: const Icon(
                                                      Icons.edit_outlined),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            leading: const Icon(Icons.manage_accounts_outlined),
                            title: const Text('Usuarios y roles',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: const Text(
                                'Asignar rol de cliente o administrador'),
                            onExpansionChanged: (expanded) {
                              if (expanded &&
                                  _profiles.isEmpty &&
                                  !_loadingProfiles) _loadProfiles();
                            },
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                          onChanged: (v) => setState(
                                              () => _profilesQuery = v),
                                          decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.search),
                                              hintText:
                                                  'Buscar usuarios por nombre, correo o rol')),
                                      const SizedBox(height: 10),
                                      _loadingProfiles
                                          ? const Center(
                                              child: Padding(
                                                  padding: EdgeInsets.all(20),
                                                  child:
                                                      CircularProgressIndicator()))
                                          : _profiles
                                                  .where((p) =>
                                                      '${p['full_name'] ?? ''} ${p['id'] ?? ''} ${p['role'] ?? ''}'
                                                          .toLowerCase()
                                                          .contains(_profilesQuery
                                                              .toLowerCase()))
                                                  .isEmpty
                                              ? Column(
                                                  children: [
                                                    const Text(
                                                        'No hay usuarios cargados.'),
                                                    TextButton.icon(
                                                      onPressed: _loadProfiles,
                                                      icon: const Icon(
                                                          Icons.refresh),
                                                      label: const Text(
                                                          'Cargar usuarios'),
                                                    ),
                                                  ],
                                                )
                                              : Column(
                                                  children: _profiles
                                                      .where((p) =>
                                                          '${p['full_name'] ?? ''} ${p['id'] ?? ''} ${p['role'] ?? ''}'
                                                              .toLowerCase()
                                                              .contains(
                                                                  _profilesQuery
                                                                      .toLowerCase()))
                                                      .map((profile) {
                                                    final role = [
                                                      'cliente',
                                                      'admin'
                                                    ].contains(profile['role'])
                                                        ? profile['role']
                                                            as String
                                                        : 'cliente';
                                                    final isCurrentUser =
                                                        profile['id']
                                                                ?.toString() ==
                                                            supabase
                                                                .auth
                                                                .currentUser
                                                                ?.id;
                                                    return ListTile(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      leading: const CircleAvatar(
                                                          child: Icon(Icons
                                                              .person_outline)),
                                                      title: Text((profile[
                                                                  'full_name'] ??
                                                              'Usuario sin nombre')
                                                          .toString()),
                                                      subtitle: Text(
                                                          'ID: ${profile['id']}'),
                                                      trailing: SizedBox(
                                                        width: 145,
                                                        child:
                                                            DropdownButtonFormField<
                                                                String>(
                                                          initialValue: role,
                                                          isExpanded: true,
                                                          decoration:
                                                              const InputDecoration(
                                                            labelText: 'Rol',
                                                            contentPadding:
                                                                EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            8),
                                                          ),
                                                          items: const [
                                                            DropdownMenuItem(
                                                                value:
                                                                    'cliente',
                                                                child: Text(
                                                                    'Cliente')),
                                                            DropdownMenuItem(
                                                                value: 'admin',
                                                                child: Text(
                                                                    'Administrador')),
                                                          ],
                                                          onChanged:
                                                              isCurrentUser
                                                                  ? null
                                                                  : (value) {
                                                                      if (value !=
                                                                              null &&
                                                                          value !=
                                                                              profile['role']) {
                                                                        _changeUserRole(
                                                                            profile,
                                                                            value);
                                                                      }
                                                                    },
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                    ]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: .75),
                                borderRadius: BorderRadius.circular(13)),
                            child: Text(
                                'Pedidos sincronizados con Supabase Realtime. Asegúrate de ejecutar supabase/schema.sql y configurar los buckets privados antes de usar la aplicación.',
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant))),
                      ]))),
        ));
  }
}

class _OrderStatusTimeline extends StatelessWidget {
  const _OrderStatusTimeline({required this.status});
  final DeliveryOrderStatus status;
  @override
  Widget build(BuildContext context) {
    final active = status.index;
    const labels = ['Preparando', 'Enviado', 'Entregado'];
    return Row(
        children: List.generate(labels.length, (index) {
      final complete = index <= active;
      return Expanded(
          child: Row(children: [
        Expanded(
            child: Column(children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeInOutCubic,
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                  color: complete
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: complete
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant)),
              child: Icon(
                  index < active
                      ? Icons.check_rounded
                      : index == 0
                          ? Icons.inventory_2_outlined
                          : index == 1
                              ? Icons.local_shipping_outlined
                              : Icons.check_circle_outline_rounded,
                  color: complete
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 13)),
          const SizedBox(height: 5),
          Text(labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: complete ? FontWeight.w800 : FontWeight.w500,
                  color: complete
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant))
        ])),
        if (index < labels.length - 1)
          Expanded(
              child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 17),
                  color: index < active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant))
      ]));
    }));
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: 19),
        const SizedBox(height: 16),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant))
      ]));
}

class _AdminAction extends StatelessWidget {
  const _AdminAction(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(children: [
                    Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(11)),
                        child: Icon(icon,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 11))
                        ])),
                    Icon(Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)
                  ])))));
}

/// Resultado local para el prototipo. No equivale a una identidad verificada.

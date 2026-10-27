part of 'main.dart';

class _SelectionDropdown<T extends Object> extends StatelessWidget {
  const _SelectionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: compact ? 8 : 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        SizedBox(height: compact ? 3 : 6),
        DropdownButtonFormField<T>(
          value: safeValue,
          isExpanded: true,
          isDense: compact,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
                horizontal: 10, vertical: compact ? 7 : 11),
            filled: true,
            fillColor: scheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: scheme.outlineVariant)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: scheme.outlineVariant)),
          ),
          style: TextStyle(
              fontSize: compact ? 10 : 12,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600),
          items: items
              .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child:
                      Text(item.toString(), overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}

class ForjaBrand extends StatelessWidget {
  const ForjaBrand({super.key, this.light = false, this.onTap});
  final bool light;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(
            4.0), // Un pequeño espacio interno para que el ripple no quede pegado al texto
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            //****************************************************** */
            // ─── REEMPLAZO POR TU LOGO DE IMAGEN ───
            Image.asset(
              'assets/logo_icon-512.png', // O Image.network('url') si viene de internet
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMFFAA',
                    style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                Text('DELIVERY',
                    style: TextStyle(
                        color: light
                            ? Colors.white54
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  const ProductCard(
      {super.key,
      required this.product,
      required this.onAdd,
      required this.onOpen,
      this.quantity = 0,
      this.onIncrement,
      this.onDecrement});
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onOpen;
  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final onAdd = widget.onAdd;
    final onOpen = widget.onOpen;
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _hovered
                    ? scheme.primary.withOpacity(.42)
                    : scheme.outlineVariant.withOpacity(.72),
                width: _hovered ? 1.25 : 1),
            boxShadow: [
              BoxShadow(
                  color: scheme.primary.withOpacity(_hovered ? .10 : .025),
                  blurRadius: _hovered ? 30 : 18,
                  offset: Offset(0, _hovered ? 12 : 5))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                            tag: 'product-${product.id}',
                            child: ProductImage(url: product.image)),
                        if (product.tag.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 5),
                              decoration: BoxDecoration(
                                  color: scheme.surface.withOpacity(.96),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(product.tag.toUpperCase(),
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .5)),
                            ),
                          ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 5),
                            decoration: BoxDecoration(
                                color: ink.withOpacity(.88),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(product.gender.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.category.toUpperCase(),
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1)),
                          const SizedBox(height: 4),
                          Text(product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Expanded(
                              child: Text(product.description,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 9,
                                      height: 1.35,
                                      color: scheme.onSurfaceVariant))),
                          const SizedBox(height: 5),
                          Row(children: [
                            Flexible(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(money(priceFor(product)),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900)))),
                            if (product.oldPrice != null) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(money(product.oldPrice!),
                                          style: TextStyle(
                                              fontSize: 8,
                                              color: scheme.onSurfaceVariant,
                                              decoration: TextDecoration
                                                  .lineThrough)))),
                            ],
                          ]),
                          const SizedBox(height: 7),
                          Row(children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 11,
                                color: stockFor(product) > 0
                                    ? slate
                                    : Colors.redAccent),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(
                                    stockFor(product) > 0
                                        ? '${stockFor(product)} disponibles'
                                        : 'Agotado',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: stockFor(product) > 0
                                            ? slate
                                            : Colors.redAccent,
                                        fontWeight: FontWeight.w700)))
                          ]),
                          const SizedBox(height: 8),
                          SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: FilledButton.icon(
                                  onPressed:
                                      stockFor(product) > 0 ? onAdd : null,
                                  style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      backgroundColor: navy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  icon: const Icon(Icons.shopping_cart_outlined,
                                      size: 15),
                                  label: const FittedBox(
                                      child: Text('AÑADIR AL CARRITO',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .4))))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showImageZoom(
    BuildContext context, String url, String title) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(.82),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                panEnabled: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                    maxHeight: MediaQuery.sizeOf(context).height - 80,
                  ),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white, size: 48),
                    ),
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const SizedBox(
                                width: 52,
                                height: 52,
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2)),
                              ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filledTonal(
                tooltip: 'Cerrar imagen',
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: ink),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              left: 8,
              right: 56,
              bottom: 4,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
            ),
          ],
        ),
      ),
    ),
  );
}

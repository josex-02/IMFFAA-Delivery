import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 34),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        );
      },
    );
  }
}

class QuantityButton extends StatefulWidget {
  const QuantityButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<QuantityButton> createState() => _QuantityButtonState();
}

class _QuantityButtonState extends State<QuantityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: _hovered ? scheme.primary : scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: _hovered ? const Color(0xFFE9EDE4) : scheme.surface,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Icon(widget.icon, size: 15, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class ClosingPanel extends StatelessWidget {
  const ClosingPanel({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MENOS RUIDO. MÁS PROPÓSITO.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('Lo esencial, bien elegido.', style: GoogleFonts.dmSerifDisplay(fontSize: 25, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('RESTABLECER CATÁLOGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}


String formatOrderDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year · $hour:$minute';
}


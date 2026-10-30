part of 'main.dart';

class IMFFAADeliveryApp extends StatefulWidget {
  const IMFFAADeliveryApp({super.key});

  @override
  State<IMFFAADeliveryApp> createState() => _IMFFAADeliveryAppState();
}

class _IMFFAADeliveryAppState extends State<IMFFAADeliveryApp> {
  ThemeData _buildTheme({bool dark = false}) {
    const green = Color(0xFF238841);
    const grey = Color(0xFFC9C9CB);
    const yellow = Color(0xFFFDED00);
    const darkBg = Color(0xFF171B18);
    const darkSurface = Color(0xFF222923);
    const darkText = Color(0xFFF4F6F4);
    const lightText = Color(0xFF202522);
    final scheme = dark
        ? ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark)
            .copyWith(
            primary: const Color(0xFF67D184),
            onPrimary: const Color(0xFF092D14),
            secondary: yellow,
            onSecondary: const Color(0xFF262600),
            surface: darkSurface,
            onSurface: darkText,
            surfaceContainerHighest: const Color(0xFF303A33),
            onSurfaceVariant: const Color(0xFFD0D8D1),
            outline: const Color(0xFF647168),
            outlineVariant: const Color(0xFF465249),
          )
        : ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light)
            .copyWith(
            primary: green,
            onPrimary: Colors.white,
            secondary: yellow,
            onSecondary: lightText,
            surface: Colors.white,
            onSurface: lightText,
            surfaceContainerHighest: const Color(0xFFE9E9EA),
            onSurfaceVariant: const Color(0xFF4C5550),
            outline: const Color(0xFF9FA5A0),
            outlineVariant: const Color(0xFFC9C9CB),
          );
    final foreground = dark ? darkText : lightText;
    final surface = dark ? darkSurface : Colors.white;
    final background = dark ? darkBg : const Color(0xFFF5F5F5);
    const radius = 14.0;
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      textTheme: GoogleFonts.interTextTheme(
              dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme)
          .apply(bodyColor: foreground, displayColor: foreground),
      appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          surfaceTintColor: Colors.transparent),
      dividerColor: scheme.outlineVariant,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: green, width: 1.7)),
      ),
      chipTheme: ChipThemeData(
          backgroundColor:
              dark ? const Color(0xFF303A33) : grey.withValues(alpha: .25),
          selectedColor: dark
              ? green.withValues(alpha: .42)
              : green.withValues(alpha: .16),
          labelStyle: TextStyle(color: foreground),
          secondaryLabelStyle: TextStyle(color: foreground),
          side: BorderSide(color: scheme.outlineVariant),
          checkmarkColor: darkText),
      dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: foreground),
          menuStyle:
              MenuStyle(backgroundColor: WidgetStatePropertyAll(surface))),
      filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 300),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? scheme.outlineVariant
                : green),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: WidgetStatePropertyAll(yellow.withValues(alpha: .22)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)))),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(foreground),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)))),
      )),
      dialogTheme: const DialogThemeData(
        alignment: Alignment.center,
        insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18))),
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'IMFFAA Delivery',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          darkTheme: _buildTheme(dark: true),
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 420),
          themeAnimationCurve: Curves.easeInOutCubic,
          home: const CatalogPage(),
          routes: {'/admin': (context) => const AdminPanelPage()},
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/app_notifications.dart';
import 'widgets/catalog_common_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/delivery_order.dart';
import 'services/receipt_pdf_service.dart';
import 'package:toastification/toastification.dart';

part 'app_state.dart';
part 'app_shell.dart';
part 'catalog_page.dart';
part 'catalog_widgets.dart';
part 'admin_panel.dart';
part 'auth_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const IMFFAADeliveryApp());
}

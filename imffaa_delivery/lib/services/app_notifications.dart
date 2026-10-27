import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void showAppToast(BuildContext context, String message,
    {bool isError = false}) {
  toastification.show(
    context: context,
    type: isError ? ToastificationType.error : ToastificationType.success,
    style: ToastificationStyle.flatColored,
    title: Text(isError ? 'Ocurrió un problema' : 'Listo'),
    description: Text(message),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    showProgressBar: false,
  );
}

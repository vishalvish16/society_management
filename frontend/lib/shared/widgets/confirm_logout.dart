import 'package:flutter/material.dart';
import 'show_app_sheet.dart';

Future<bool> showLogoutConfirmSheet(
  BuildContext context, {
  String title = 'Logout',
  String message = 'Are you sure you want to logout?',
  String confirmLabel = 'Logout',
  String cancelLabel = 'Cancel',
}) {
  return showConfirmSheet(
    context: context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
  );
}


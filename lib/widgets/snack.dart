import 'package:flutter/material.dart';

import '../services/api.dart';

/// Friendly snackbar for any error from [Api]. Demo-mode writes get the
/// standard "Connect to a server to do this" message.
void showApiError(BuildContext context, Object error) {
  final msg = switch (error) {
    DemoModeException() => DemoModeException.message,
    ApiException(:final message) => message,
    _ => 'Something went wrong. Please try again.',
  };
  showMessage(context, msg);
}

void showMessage(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg)));

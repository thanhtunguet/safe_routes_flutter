import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

/// A provider that handles toast notifications using toastification
class ToastNotifier extends StateNotifier<void> {
  ToastNotifier() : super(null);

  void showSuccess(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.fillColored,
      title: 'Success',
      description: message,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void showError(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      title: 'Error',
      description: message,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void showInfo(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.fillColored,
      title: 'Information',
      description: message,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  void showWarning(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.fillColored,
      title: 'Warning',
      description: message,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }
}

final toastProvider = StateNotifierProvider<ToastNotifier, void>(
  (ref) => ToastNotifier(),
);

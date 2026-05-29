import 'package:flutter/material.dart';
import '../utils/theme.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: isDestructive
              ? ElevatedButton.styleFrom(backgroundColor: kAccent)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

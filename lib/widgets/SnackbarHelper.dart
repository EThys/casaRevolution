import 'package:flutter/material.dart';

class SnackBarHelper {
  static void show(
      BuildContext context,
      String message, {
        bool isError = false,
        Color? successColor,
      }) {
    final Color defaultSuccessColor = Colors.green[600]!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Colors.red[600]
            : (successColor ?? defaultSuccessColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(20),
      ),
    );
  }
}

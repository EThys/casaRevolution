import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SnackbarHelper {
  const SnackbarHelper._();

  static final _key = GlobalKey<ScaffoldMessengerState>();

  static GlobalKey<ScaffoldMessengerState> get key => _key;

  static void showSnackBar(String? message, {bool isError = false}) {
    Color backgroundColor = isError ? Colors.red : Colors.green;

    _key.currentState
      ?..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Center(
            child: Text(
              message!,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.white),
            ),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: backgroundColor, // Change background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Rounded corners
          ),
          action: SnackBarAction(
            label: 'X',
            textColor: Colors.white,
            onPressed: () {
              // Code to execute when the action is pressed
            },
          ),
        ),
      );
  }
}

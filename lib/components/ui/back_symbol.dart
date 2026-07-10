import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BackSymbol extends StatelessWidget {
  final Color? color;
  final double size;

  const BackSymbol({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '>',
      style: GoogleFonts.roboto(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color ?? Colors.white,
      ),
    );
  }
}

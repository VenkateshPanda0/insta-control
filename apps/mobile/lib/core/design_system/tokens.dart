import 'package:material_ui/material_ui.dart';

abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class Radii {
  static const card = 20.0;
  static const control = 14.0;
  static const pill = 999.0;
}

abstract final class Brand {
  /// Calm sage green; every other color derives from it.
  static const seed = Color(0xFF3F6B5E);
}

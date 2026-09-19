import 'package:flutter/material.dart';

class AppCustomIcons {
  static Widget download({double size = 24, Color? color}) {
    return Image.asset(
      'assets/icons/download.png',
      width: size,
      height: size,
      color: color,
    );
  }

  static Widget upload({double size = 24, Color? color}) {
    return Image.asset(
      'assets/icons/upload.png',
      width: size,
      height: size,
      color: color,
    );
  }

  static Widget syncIcon({double size = 24, Color? color}) {
    return Image.asset(
      'assets/icons/sync.png',
      width: size,
      height: size,
      color: color,
    );
  }
}

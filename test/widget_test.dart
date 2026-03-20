import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repzeno/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppTheme exposes a dark theme', () {
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
  });
}

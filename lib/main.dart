import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/settings_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Implemented robust global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 [Flutter Error]: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('💥 [Uncaught Async Error]: $error');
    debugPrint(stack.toString());
    return true; // Prevents app from hard crashing
  };

  // Immediate protection against memory leaks for extensive image galleries
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB max limit

  // Web/Desktop sqflite unsupported with secure AES storage
  
  final prefs = await SharedPreferences.getInstance();
  
  // Secure Storage / DB Encryption Initialization
  const secureStorage = FlutterSecureStorage();
  final dbKey = await DatabaseHelper.instance.getEncryptionKey();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(secureStorage),
        dbEncryptionKeyProvider.overrideWithValue(dbKey),
      ],
      child: const RepZenoApp(),
    ),
  );
}

class RepZenoApp extends StatelessWidget {
  const RepZenoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RepZeno',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

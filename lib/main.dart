import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/ui/home/screen/home_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'service/http/http_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(title: 'Miraprint', center: true);
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Miraprint',
      theme: _buildTheme(),
      home: BlocProvider(
        create: (context) => ServerBloc(HttpService()),
        child: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const seedColor = Color(0xFF2563EB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: AppBarTheme(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }
}

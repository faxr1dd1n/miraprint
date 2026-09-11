import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/ui/home/screen/home_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'service/http/http_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLogging();
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
    const borderRadius = 12.0;
    final radius = BorderRadius.circular(borderRadius);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 11, 105, 255),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color.fromARGB(255, 241, 246, 255),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
    );
  }
}

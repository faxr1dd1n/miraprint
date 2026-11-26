import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:miraprint/bloc/arca_bloc/arca_bloc.dart';
import 'package:miraprint/bloc/server_bloc/server_bloc.dart';
import 'package:miraprint/core/app_logger.dart';
import 'package:miraprint/core/app_theme.dart';
import 'package:miraprint/core/trusted_certificates.dart';
import 'package:miraprint/service/arca/arca_bridge_server.dart';
import 'package:miraprint/service/arca/certificate_service.dart';
import 'package:miraprint/service/locale/locale_service.dart';
import 'package:miraprint/service/window/app_window_service.dart';
import 'package:miraprint/ui/home/screen/home_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'service/http/http_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Installer: `miraprint.exe --generate-cert "<papka>"` — faqat Arca uchun
  // sertifikat yaratib chiqib ketadi (oyna ochilmaydi).
  final certIndex = args.indexOf('--generate-cert');
  if (certIndex >= 0) {
    final dir = certIndex + 1 < args.length
        ? Directory(args[certIndex + 1])
        : null;
    await CertificateService.ensure(dir: dir);
    exit(0);
  }

  await setupLogging();
  await loadTrustedCertificates();

  final localizationDelegate = await createLocalizationDelegate();

  // pos_app'dagi kabi: oyna o'lchami va uni ko'rsatish butunlay native
  // tomonga (macOS — MainFlutterWindow.swift, NSScreen.main.visibleFrame)
  // qoldirilgan — bu yerda `show()`/`maximize()` chaqirilmaydi, chunki
  // window_manager'ning o'z ichidagi "isMaximized bo'lsa unmaximize qil"
  // logikasi (`waitUntilReadyToShow`) allaqachon to'liq ekranga o'rnatilgan
  // oynani "maximized" deb noto'g'ri hisoblab, uni orqaga (~96%) qisib
  // qo'yadi. `ensureInitialized()` esa faqat pastda `AppWindowService`ning
  // tray/`onWindowClose` funksiyalari ishlashi uchun kerak — vizual ta'siri
  // yo'q.
  await windowManager.ensureInitialized();
  await AppWindowService().init();
  runApp(
    LocalizedApp(localizationDelegate, MyApp(arcaServer: ArcaBridgeServer())),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.arcaServer});

  final ArcaBridgeServer arcaServer;

  @override
  Widget build(BuildContext context) {
    final localizationDelegate = LocalizedApp.of(context).delegate;

    return ValueListenableBuilder<int>(
      valueListenable: localeTick,
      builder: (context, _, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Miraprint',
          theme: buildAppTheme(),
          locale: localizationDelegate.currentLocale,
          supportedLocales: localizationDelegate.supportedLocales,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            localizationDelegate,
          ],
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => ServerBloc(HttpService())),
              BlocProvider(create: (context) => ArcaBloc(arcaServer)),
            ],
            child: HomeScreen(arcaServer: arcaServer),
          ),
        );
      },
    );
  }
}

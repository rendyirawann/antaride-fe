import 'package:antaride_auth/antaride_auth.dart';
import 'package:antaride_ui/antaride_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'features/auth/welcome_screen.dart';
import 'features/home/merchant_shell.dart';

/// Akar aplikasi merchant.
class AntarideMerchantApp extends StatelessWidget {
  const AntarideMerchantApp({super.key, required this.services});

  final AntarideServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AntarideServices>.value(value: services),
        ChangeNotifierProvider<SessionController>.value(
          value: services.session,
        ),
      ],
      child: MaterialApp(
        title: 'Antaride Merchant',
        debugShowCheckedModeBanner: false,
        theme: ClayTheme.light(),
        darkTheme: ClayTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _Gerbang(),
      ),
    );
  }
}

class _Gerbang extends StatelessWidget {
  const _Gerbang();

  @override
  Widget build(BuildContext context) {
    final SessionStage tahap = context.select<SessionController, SessionStage>(
      (SessionController s) => s.stage,
    );

    return switch (tahap) {
      SessionStage.unknown || SessionStage.loadingProfile => const Scaffold(
        body: ClayLoader(message: 'Menyiapkan Antaride Merchant…'),
      ),
      SessionStage.signedOut => const MerchantWelcomeScreen(),
      SessionStage.signedIn => const MerchantShell(),
    };
  }
}

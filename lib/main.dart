import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/store.dart';
import 'src/storage.dart';
import 'src/ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(Storage());
  runApp(
    ChangeNotifierProvider.value(
      value: store..init(),
      child: const FilStockApp(),
    ),
  );
}

class FilStockApp extends StatelessWidget {
  const FilStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tokens = store.tokens;
    final scale = store.settings.fontSize / 100;
    return MaterialApp(
      title: 'FilStock',
      debugShowCheckedModeBanner: false,
      theme: tokens.toThemeData(),
      builder: (context, child) {
        // Échelle de police globale (réglage utilisateur).
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}

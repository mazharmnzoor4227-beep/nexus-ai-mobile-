import 'package:flutter/material.dart';
import 'core/store.dart';
import 'core/files.dart';
import 'core/retrieval.dart';
import 'core/vault.dart';
import 'core/gateway.dart';
import 'core/session.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.init();
  final vault = Vault();
  final files = Files(store);
  await files.init();
  final gateway = Gateway(vault, store);
  await gateway.cache();
  files.retrieval = Retrieval(gateway, store);
  runApp(NexusApp(session: Session(store, vault, gateway, files)));
}

class NexusApp extends StatelessWidget {
  final Session session;
  const NexusApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Nexus AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff131315),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffadc6ff),
        brightness: Brightness.dark,
        surface: const Color(0xff131315),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff131315),
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff222226),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xff131315),
      ),
    ),
    home: Home(session: session),
  );
}

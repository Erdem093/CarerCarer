import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load all API keys from .env before anything else
  await AppConfig.load();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Sign in anonymously so sessions save to Supabase even without a login flow
  if (Supabase.instance.client.auth.currentUser == null) {
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed (enable it in Supabase dashboard): $e');
    }
  }

  runApp(
    const ProviderScope(
      child: CuraApp(),
    ),
  );
}

class CuraApp extends StatelessWidget {
  const CuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cura',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

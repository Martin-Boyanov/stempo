import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/theme/app_theme.dart';
import '../state/auth_providers.dart';
import 'app_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = AuthScope.read(context);
    _router = AppRouter.createRouter(auth);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light,
    );
  }
}

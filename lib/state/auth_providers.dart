import 'package:flutter/widgets.dart';

import '../controllers/auth_controller.dart';

class AuthScope extends InheritedNotifier<SpotifyAuthController> {
  const AuthScope({
    super.key,
    required SpotifyAuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static SpotifyAuthController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope not found in widget tree.');
    return scope!.notifier!;
  }

  static SpotifyAuthController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AuthScope>();
    final scope = element?.widget as AuthScope?;
    assert(scope != null, 'AuthScope not found in widget tree.');
    return scope!.notifier!;
  }
}

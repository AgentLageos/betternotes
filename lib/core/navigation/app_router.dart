import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveLastRoute(String route) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastRoute', route);
}

Future<String?> loadLastRoute() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('lastRoute');
}


class RouteSaver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final name = route.settings.name ?? route.settings.name;
    if (name != null) {
      saveLastRoute(name);
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final name = previousRoute?.settings.name;
    if (name != null) {
      saveLastRoute(name);
    }
    super.didPop(route, previousRoute);
  }
}
import 'package:flutter/material.dart';

import '../screens/data_entry/data_entry_screen.dart';
import '../screens/distributors/distributors_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/manager/manager_dashboard_screen.dart';
import '../screens/president/president_dashboard_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/users/users_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String dataEntry = '/data-entry';
  static const String manager = '/manager';
  static const String president = '/president';
  static const String distributors = '/distributors';
  static const String users = '/users';
  static const String reports = '/reports';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    dataEntry: (_) => const DataEntryScreen(),
    manager: (_) => const ManagerDashboardScreen(),
    president: (_) => const PresidentDashboardScreen(),
    distributors: (_) => const DistributorsScreen(),
    users: (_) => const UsersScreen(),
    reports: (_) => const ReportsScreen(),
  };
}
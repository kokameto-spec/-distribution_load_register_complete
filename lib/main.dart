import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'controllers/audit_log_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/distributor_controller.dart';
import 'controllers/load_records_controller.dart';
import 'controllers/station_controller.dart';
import 'controllers/station_report_controller.dart';
import 'controllers/user_management_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('ar');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProvider<DistributorController>(
          create: (_) => DistributorController(),
        ),
        ChangeNotifierProvider<LoadRecordsController>(
          create: (_) => LoadRecordsController(),
        ),
        ChangeNotifierProvider<StationController>(
          create: (_) => StationController(),
        ),
        ChangeNotifierProvider<StationReportController>(
          create: (_) => StationReportController(),
        ),
        ChangeNotifierProvider<UserManagementController>(
          create: (_) => UserManagementController(),
        ),
        ChangeNotifierProvider<AuditLogController>(
          create: (_) => AuditLogController(),
        ),
      ],
      child: const DistributionLoadRegisterApp(),
    ),
  );
}

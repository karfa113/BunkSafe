import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  // Fire-and-forget plugin init; AppState will arm/cancel the reminder
  // once the service is ready.
  NotificationService.instance.init();
  runApp(AttendanceApp(storage: storage));
}

class AttendanceApp extends StatelessWidget {
  final StorageService storage;
  const AttendanceApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(storage),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'BunkSafe',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

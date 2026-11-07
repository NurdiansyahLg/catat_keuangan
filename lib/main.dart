import 'package:flutter/material.dart';

import 'app.dart';
import 'core/providers/theme_controller.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await NotificationService.instance.init();
  SyncService.instance.init();
  runApp(const PencatatKeuanganApp());
}



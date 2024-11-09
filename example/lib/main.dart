import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  final format = DateFormat('HH:mm:ss');
  // configure logs for debugging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (record.loggerName != 'listview_screenshot') {
      return;
    }
    debugPrint(
        '${format.format(record.time)}: ${record.loggerName}: ${record.level.name} ${record.message}');
  });

  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());

  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(MyApp(settingsController: settingsController));
}

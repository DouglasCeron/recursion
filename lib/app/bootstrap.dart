import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/save_game/infrastructure/shared_preferences_save_repository.dart';
import 'app.dart';
import 'app_container.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final preferences = await SharedPreferences.getInstance();
  final container = await createAppContainer(
    SharedPreferencesSaveRepository(preferences),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RecursionApp(),
    ),
  );
}

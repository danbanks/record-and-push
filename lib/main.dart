import 'package:flutter/material.dart';

import 'dictation/config.dart';
import 'dictation/ui/widget/dictation_material_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize application config
  await setupDependencyInjection();

  runApp(createDictationMaterialApp());
}

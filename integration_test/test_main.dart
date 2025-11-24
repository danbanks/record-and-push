import 'package:flutter/material.dart';
import 'package:record_and_push/dictation/ui/widget/dictation_material_app.dart';

import 'dependency_setup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize application config
  setupTestDependencies();

  runApp(await createDictationMaterialApp());
}
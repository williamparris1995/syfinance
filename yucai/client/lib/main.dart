import 'package:flutter/material.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const YuCaiApp());
}

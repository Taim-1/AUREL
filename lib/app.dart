import 'package:material_ui/material_ui.dart';

import 'core/theme/aurel_theme.dart';
import 'presentation/app_shell.dart';

class AurelApp extends StatelessWidget {
  const AurelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUREL',
      debugShowCheckedModeBanner: false,
      theme: AurelTheme.dark,
      home: const AppShell(),
    );
  }
}

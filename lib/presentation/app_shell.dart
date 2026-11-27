import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/theme/aurel_theme.dart';
import '../data/services/aurel_controller.dart';
import 'screens/downloads_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/aurel_glass_panel.dart';
import 'widgets/mini_player.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    DownloadsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.download_rounded, 'Downloads'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<AurelController>().selectedTab;

    return Scaffold(
      backgroundColor: AurelColors.background,
      body: IndexedStack(index: selected, children: _screens),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AurelColors.background,
            border: Border(top: BorderSide(color: AurelColors.divider)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              AurelGlassPanel(
                margin: const EdgeInsets.fromLTRB(9, 3, 9, 5),
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
                radius: 21,
                blur: 17,
                tint: const Color(0xC00F1014),
                shadowOpacity: 0.07,
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    children: List.generate(_items.length, (index) {
                    final item = _items[index];
                    final active = selected == index;
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            context.read<AurelController>().selectTab(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.$1,
                                size: 21,
                                color: active
                                    ? AurelColors.champagne
                                    : AurelColors.muted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.$2,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? AurelColors.champagne
                                      : AurelColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _clientController;
  late final TextEditingController _lyricsKeyController;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AurelController>();
    _clientController = TextEditingController(
      text: controller.jamendo.clientId,
    );
    _lyricsKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _lyricsKeyController.dispose();
    super.dispose();
  }

  Future<void> _openSettings(AurelController controller) async {
    var savingClient = false;
    var savingLyrics = false;
    var showLyricsKey = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  22,
                  20,
                  24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AurelColors.muted.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 21),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AurelColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.offline_pin_rounded,
                          color: AurelColors.champagne,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Offline mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Only show and play music saved inside AUREL.',
                                style: TextStyle(
                                  color: AurelColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: controller.offlineMode,
                          activeThumbColor: AurelColors.champagneLight,
                          onChanged: (value) =>
                              controller.setOfflineMode(value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Music catalogue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Jamendo currently powers independent music discovery and streaming. Add your own application client ID here.',
                    style: TextStyle(
                      color: AurelColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Jamendo client ID',
                      hintText: 'Enter your app client ID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: savingClient
                          ? null
                          : () async {
                              setSheetState(() => savingClient = true);
                              try {
                                await controller.saveJamendoClientId(
                                  _clientController.text,
                                );
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Music service settings saved',
                                        ),
                                      ),
                                    );
                                }
                              } catch (error) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(error.toString()),
                                      ),
                                    );
                                }
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => savingClient = false);
                                }
                              }
                            },
                      child: savingClient
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save music settings'),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Licensed lyrics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'AUREL uses Musixmatch licensed lyrics. Synchronized subtitles depend on the provider and account plan.',
                    style: TextStyle(
                      color: AurelColors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    controller.hasLyricsApiKey
                        ? 'API key saved securely on this device'
                        : 'No lyrics API key configured',
                    style: TextStyle(
                      color: controller.hasLyricsApiKey
                          ? AurelColors.champagneLight
                          : AurelColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lyricsKeyController,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: !showLyricsKey,
                    decoration: InputDecoration(
                      labelText: 'Musixmatch API key',
                      hintText: 'Paste your personal API key',
                      suffixIcon: IconButton(
                        tooltip: showLyricsKey ? 'Hide key' : 'Show key',
                        onPressed: () => setSheetState(
                          () => showLyricsKey = !showLyricsKey,
                        ),
                        icon: Icon(
                          showLyricsKey
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AurelColors.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: savingLyrics
                          ? null
                          : () async {
                              setSheetState(() => savingLyrics = true);
                              try {
                                await controller.saveLyricsApiKey(
                                  _lyricsKeyController.text,
                                );
                                _lyricsKeyController.clear();
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lyrics key saved securely',
                                        ),
                                      ),
                                    );
                                }
                              } catch (error) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(error.toString()),
                                      ),
                                    );
                                }
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => savingLyrics = false);
                                }
                              }
                            },
                      child: savingLyrics
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save lyrics key'),
                    ),
                  ),
                  if (controller.hasLyricsApiKey)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await controller.clearLyricsApiKey();
                          _lyricsKeyController.clear();
                          if (sheetContext.mounted) {
                            setSheetState(() {});
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Lyrics key removed'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                        ),
                        label: const Text('Remove saved lyrics key'),
                        style: TextButton.styleFrom(
                          foregroundColor: AurelColors.muted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'Your AUREL library stays on this device. Provider credentials are never committed to GitHub.',
                    style: TextStyle(
                      color: AurelColors.muted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAppearance(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Appearance'),
        content: const Text(
          'AUREL Champagne Noir is the official visual identity: deep black surfaces, champagne highlights, warm silver details and the approved ribbon-A mark.',
          style: TextStyle(
            color: AurelColors.muted,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Notifications'),
        content: const Text(
          'AUREL uses Android media notifications for the current song, album artwork and playback controls. Their visibility is also controlled by your Android notification settings.',
          style: TextStyle(
            color: AurelColors.muted,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPremiumFeatures(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Premium Features'),
        content: const Text(
          'The AUREL listening experience in this release is free to use. Playback, playlists, favourites, licensed lyrics and permitted offline downloads are available without an in-app premium subscription.',
          style: TextStyle(
            color: AurelColors.muted,
            height: 1.5,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Lovely'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AUREL',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/branding/aurel_app_icon.jpg',
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      ),
      children: const [
        Text('Feel the Music'),
        SizedBox(height: 8),
        Text(
          'A refined music experience with discovery, private offline listening and a carefully crafted player.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AurelColors.champagne.withValues(alpha: 0.18),
            ),
          ),
          child: const Column(
            children: [
              CircleAvatar(
                radius: 39,
                backgroundColor: Color(0xFF3B3025),
                child: Icon(
                  Icons.nightlight_round,
                  size: 34,
                  color: AurelColors.champagneLight,
                ),
              ),
              SizedBox(height: 13),
              Text(
                'TAIM 👑',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Music Lover ♫',
                style: TextStyle(color: AurelColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _ProfileMenuItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Premium Features',
          subtitle: 'Free Forever',
          onTap: () => _showPremiumFeatures(context),
        ),
        _ProfileMenuItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Offline mode, music services and lyrics',
          onTap: () => _openSettings(controller),
        ),
        _ProfileMenuItem(
          icon: Icons.palette_outlined,
          title: 'Appearance',
          subtitle: 'Champagne Noir',
          onTap: () => _showAppearance(context),
        ),
        _ProfileMenuItem(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: 'Playback and lock-screen controls',
          onTap: () => _showNotifications(context),
        ),
        _ProfileMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'About AUREL',
          subtitle: 'Version 1.0.0 • Feel the Music',
          onTap: () => _showAbout(context),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your AUREL collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${controller.favoriteTracks.length} liked • ${controller.downloadedTracks.length} offline',
                style: const TextStyle(
                  color: AurelColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(icon, color: AurelColors.champagne, size: 21),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AurelColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AurelColors.muted,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../screens/account_screen.dart';

class AurelSettingsSheet extends StatefulWidget {
  const AurelSettingsSheet({super.key});

  @override
  State<AurelSettingsSheet> createState() => _AurelSettingsSheetState();
}

class _AurelSettingsSheetState extends State<AurelSettingsSheet> {
  late final TextEditingController _jamendoController;
  late final TextEditingController _lyricsController;
  bool _savingMusic = false;
  bool _savingLyrics = false;
  bool _showLyricsKey = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AurelController>();
    _jamendoController = TextEditingController(
      text: controller.jamendo.clientId,
    );
    _lyricsController = TextEditingController();
  }

  @override
  void dispose() {
    _jamendoController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _saveMusic() async {
    setState(() => _savingMusic = true);
    try {
      await context
          .read<AurelController>()
          .saveJamendoClientId(_jamendoController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Music settings saved')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMusic = false);
    }
  }

  Future<void> _saveLyrics() async {
    setState(() => _savingLyrics = true);
    try {
      await context
          .read<AurelController>()
          .saveLyricsApiKey(_lyricsController.text);
      _lyricsController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lyrics key saved securely')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLyrics = false);
    }
  }

  Future<void> _removeLyrics() async {
    await context.read<AurelController>().clearLyricsApiKey();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            23,
            20,
            26 + MediaQuery.viewInsetsOf(context).bottom,
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
            const SizedBox(height: 22),
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
                          'Play music saved inside AUREL without a connection.',
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
                    onChanged: controller.setOfflineMode,
                  ),
                ],
              ),
            ),
            Material(
              color: AurelColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        color: AurelColors.champagneLight,
                        size: 21,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account & Sync',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Google, email and listening history',
                              style: TextStyle(
                                color: AurelColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AurelColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Music source',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Jamendo currently powers independent music discovery and streaming. Use your own application client ID when you have one.',
              style: TextStyle(
                color: AurelColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: _jamendoController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Jamendo client ID',
                hintText: 'Enter your app client ID',
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savingMusic ? null : _saveMusic,
                child: _savingMusic
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save music settings'),
              ),
            ),
            const SizedBox(height: 24),
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
              'AUREL uses Musixmatch licensed lyrics. Availability and synchronization depend on the provider plan.',
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
            const SizedBox(height: 11),
            TextField(
              controller: _lyricsController,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: !_showLyricsKey,
              decoration: InputDecoration(
                labelText: 'Musixmatch API key',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showLyricsKey = !_showLyricsKey),
                  icon: Icon(
                    _showLyricsKey
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savingLyrics ? null : _saveLyrics,
                child: _savingLyrics
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
                  onPressed: _removeLyrics,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: const Text('Remove saved lyrics key'),
                  style: TextButton.styleFrom(
                    foregroundColor: AurelColors.muted,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'AUREL never stores private API credentials in the GitHub repository.',
              style: TextStyle(
                color: AurelColors.muted,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

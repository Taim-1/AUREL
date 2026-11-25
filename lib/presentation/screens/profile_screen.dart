import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/aurel_mark.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _clientController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(
      text: context.read<AurelController>().jamendo.clientId,
    );
  }

  @override
  void dispose() {
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _saveClientId() async {
    setState(() => _saving = true);
    try {
      await context
          .read<AurelController>()
          .saveJamendoClientId(_clientController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Music service settings saved')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AurelColors.champagne.withValues(alpha: 0.18)),
          ),
          child: const Column(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Color(0xFF3B3025),
                child: Icon(
                  Icons.headphones_rounded,
                  size: 32,
                  color: AurelColors.champagneLight,
                ),
              ),
              SizedBox(height: 13),
              AurelMark(compact: true),
              SizedBox(height: 9),
              Text(
                'Your music space',
                style: TextStyle(color: AurelColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AurelColors.divider),
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
                    context.read<AurelController>().setOfflineMode(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Music source',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Jamendo provides discovery and streaming from independent artists. You can use your own application client ID.',
          style: TextStyle(color: AurelColors.muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 13),
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
            onPressed: _saving ? null : _saveClientId,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save music settings'),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'AUREL',
          style: TextStyle(
            color: AurelColors.champagne,
            fontSize: 11,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        _SettingRow(
          icon: Icons.favorite_outline_rounded,
          title: 'Liked tracks',
          value: '${controller.favoriteTracks.length}',
        ),
        _SettingRow(
          icon: Icons.download_done_rounded,
          title: 'Offline tracks',
          value: '${controller.downloadedTracks.length}',
        ),
        const SizedBox(height: 18),
        const Text(
          'AUREL saves downloads inside its private app storage. It does not scan or import audio from other apps on your phone.',
          style: TextStyle(color: AurelColors.muted, fontSize: 11, height: 1.55),
        ),
        const SizedBox(height: 12),
        const Text(
          'Version 1.0.0 • Feel the Music',
          textAlign: TextAlign.center,
          style: TextStyle(color: AurelColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AurelColors.champagne),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: Text(value,
          style: const TextStyle(color: AurelColors.muted, fontSize: 12)),
    );
  }
}

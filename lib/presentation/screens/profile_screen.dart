import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import 'account_screen.dart';
import '../widgets/aurel_settings_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurelColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const AurelSettingsSheet(),
    );
  }

  void _showAppearance(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: const Text('Appearance'),
        content: const Text(
          'AUREL uses its approved Champagne Noir identity: deep black surfaces, champagne highlights, warm silver details and the ribbon-A mark.',
          style: TextStyle(
            color: AurelColors.muted,
            fontSize: 13,
            height: 1.5,
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
          'AUREL uses Android media notifications for the current song, artwork and playback controls. You can also manage notification permission in Android settings.',
          style: TextStyle(
            color: AurelColors.muted,
            fontSize: 13,
            height: 1.5,
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
          'AUREL’s current listening features are free to use. Account sync, playlists, favourites, licensed lyrics and permitted offline downloads are part of the listening experience.',
          style: TextStyle(
            color: AurelColors.muted,
            fontSize: 13,
            height: 1.5,
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
          'A refined music experience with discovery, playback, account sync and private offline listening.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final user = controller.account.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 19),
          decoration: BoxDecoration(
            color: AurelColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AurelColors.champagne.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 39,
                backgroundColor: const Color(0xFF3B3025),
                backgroundImage:
                    user?.photoURL == null ? null : NetworkImage(user!.photoURL!),
                child: user?.photoURL == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 34,
                        color: AurelColors.champagneLight,
                      )
                    : null,
              ),
              const SizedBox(height: 13),
              Text(
                '${controller.account.userName} 👑',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Music Lover ♫',
                style: TextStyle(color: AurelColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        _ProfileMenuItem(
          icon: Icons.cloud_sync_rounded,
          title: 'Account & Sync',
          subtitle: user == null
              ? 'Connect Google or email and save your library'
              : 'Signed in as ${controller.account.userName}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AccountScreen(),
            ),
          ),
        ),
        _ProfileMenuItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Premium Features',
          subtitle: 'Free Forever',
          onTap: () => _showPremiumFeatures(context),
        ),
        _ProfileMenuItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Music, offline mode and lyrics',
          onTap: () => _openSettings(context),
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
        const SizedBox(height: 18),
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

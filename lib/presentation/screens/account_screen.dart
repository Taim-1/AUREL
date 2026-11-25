import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  bool _creatingAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    final account = context.read<AurelController>().account;
    _usernameController = TextEditingController(text: account.userName);
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyAuthError(error));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Check the email address and try again.',
      'user-disabled' => 'This account is currently disabled.',
      'user-not-found' => 'No account was found for this email.',
      'wrong-password' || 'invalid-credential' =>
        'The email or password is incorrect.',
      'email-already-in-use' => 'An account already uses this email. Sign in instead.',
      'weak-password' => 'Choose a stronger password with at least 6 characters.',
      'network-request-failed' => 'Connection failed. Check your internet and try again.',
      'account-exists-with-different-credential' =>
        'This email is already connected using another sign-in method.',
      'credential-already-in-use' =>
        'This Google or email login is already connected to another account.',
      _ => error.message ?? 'Sign-in failed. Please try again.',
    };
  }

  Future<void> _afterAuthentication() async {
    final controller = context.read<AurelController>();
    final account = controller.account;
    // Never replace the username chosen by the listener with a Google
    // profile name. New Google users can choose their AUREL name below.
    _usernameController.text = await account.loadUserName();
    await controller.restoreCloudLibrary();
    controller.notifyAccountChanged();
    if (mounted) {
      setState(() {
        _message = 'Your AUREL library is connected and ready to sync.';
        _error = null;
      });
    }
  }

  Future<void> _signInGoogle() => _run(() async {
        await context.read<AurelController>().account.signInWithGoogle();
        await _afterAuthentication();
      });

  Future<void> _submitEmail() => _run(() async {
        final controller = context.read<AurelController>();
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        if (_creatingAccount) {
          await controller.account.createEmailAccount(
            email: email,
            password: password,
            username: _usernameController.text,
          );
          await _afterAuthentication();
          if (mounted) {
            setState(() {
              _message =
                  'Account created. Check your email for the verification message.';
            });
          }
        } else {
          await controller.account.signInWithEmail(
            email: email,
            password: password,
          );
          await _afterAuthentication();
        }
      });

  Future<void> _saveUsername() => _run(() async {
        final controller = context.read<AurelController>();
        await controller.account.setUserName(_usernameController.text);
        controller.notifyAccountChanged();
        if (mounted) {
          setState(() => _message = 'Your username has been saved.');
        }
      });

  Future<void> _syncNow() => _run(() async {
        await context.read<AurelController>().syncCloudLibrary();
        if (mounted) {
          setState(() => _message = 'Your listening history and library are synced.');
        }
      });

  Future<void> _signOut() => _run(() async {
        final controller = context.read<AurelController>();
        await controller.account.signOut();
        controller.notifyAccountChanged();
        if (mounted) {
          setState(() {
            _message = 'You have signed out. Your music saved on this device remains here.';
            _error = null;
          });
        }
      });

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    await _run(() async {
      await context.read<AurelController>().account.sendPasswordReset(email);
      if (mounted) setState(() => _message = 'Password reset email sent.');
    });
  }

  Future<void> _linkGoogle() => _run(() async {
        await context.read<AurelController>().account.linkGoogle();
        if (mounted) {
        setState(() {
          _message = 'Google is now linked to your AUREL account.';
        });
      }
      });

  Future<void> _linkEmail() async {
    final email = TextEditingController();
    final password = TextEditingController();
    var linking = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AurelColors.surfaceRaised,
          title: const Text('Link an email address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(
                  dialogError!,
                  style: const TextStyle(
                    color: Color(0xFFE7A0A0),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: linking ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: linking
                  ? null
                  : () async {
                      setDialogState(() {
                        linking = true;
                        dialogError = null;
                      });
                      try {
                        await context.read<AurelController>().account.linkEmail(
                              email: email.text,
                              password: password.text,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          setState(() => _message = 'Email sign-in is now linked.');
                        }
                      } on FirebaseAuthException catch (error) {
                        setDialogState(() {
                          dialogError = _friendlyAuthError(error);
                          linking = false;
                        });
                      } catch (error) {
                        setDialogState(() {
                          dialogError = error.toString();
                          linking = false;
                        });
                      }
                    },
              child: linking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Link email'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final account = controller.account;
    final user = account.currentUser;

    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(title: const Text('Account & Sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          if (!account.isConfigured)
            _ConfigurationNotice(
              message: account.initializationError,
              usernameController: _usernameController,
              onSaveUsername: () => _run(() async {
                await account.setUserName(_usernameController.text);
                controller.notifyAccountChanged();
                if (mounted) {
                  setState(() => _message = 'Your username has been saved on this device.');
                }
              }),
              busy: _busy,
            )
          else if (user == null)
            _SignedOutCard(
              usernameController: _usernameController,
              emailController: _emailController,
              passwordController: _passwordController,
              creatingAccount: _creatingAccount,
              busy: _busy,
              showPassword: _showPassword,
              googleAvailable: account.isGoogleAvailable,
              onToggleMode: () => setState(() {
                _creatingAccount = !_creatingAccount;
                _error = null;
                _message = null;
              }),
              onGoogle: account.isGoogleAvailable ? _signInGoogle : null,
              onEmail: _submitEmail,
              onResetPassword: _resetPassword,
              onTogglePassword: () =>
                  setState(() => _showPassword = !_showPassword),
            )
          else
            _SignedInCard(
              user: user,
              usernameController: _usernameController,
              linkedProviders: account.linkedProviders,
              googleAvailable: account.isGoogleAvailable,
              busy: _busy,
              onSaveUsername: _saveUsername,
              onLinkGoogle: account.isGoogleAvailable ? _linkGoogle : null,
              onLinkEmail: _linkEmail,
              onSync: _syncNow,
              onSignOut: _signOut,
              onVerifyEmail: () => _run(
                () => account.sendVerificationEmail(),
              ),
              onRefreshUsername: () async {
                _usernameController.text = await account.loadUserName();
                if (mounted) setState(() {});
              },
            ),
          if (_error != null) ...[
            const SizedBox(height: 13),
            _StatusMessage(message: _error!, isError: true),
          ],
          if (_message != null) ...[
            const SizedBox(height: 13),
            _StatusMessage(message: _message!, isError: false),
          ],
          const SizedBox(height: 20),
          const Text(
            'WHAT SYNC DOES',
            style: TextStyle(
              color: AurelColors.champagne,
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          const _SyncFeature(
            icon: Icons.history_rounded,
            title: 'Listening history',
            description: 'Your recently played songs return when you sign in again.',
          ),
          const _SyncFeature(
            icon: Icons.favorite_border_rounded,
            title: 'Liked songs & playlists',
            description: 'Your saved music lists follow your AUREL account.',
          ),
          const _SyncFeature(
            icon: Icons.download_for_offline_outlined,
            title: 'Downloaded audio',
            description:
                'Audio files stay on this device. After reinstall, AUREL can restore track details and download again only where the provider allows it.',
          ),
        ],
      ),
    );
  }
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice({
    required this.message,
    required this.usernameController,
    required this.onSaveUsername,
    required this.busy,
  });

  final String? message;
  final TextEditingController usernameController;
  final VoidCallback onSaveUsername;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AurelColors.champagne.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_sync_rounded,
            color: AurelColors.champagneLight,
            size: 31,
          ),
          const SizedBox(height: 13),
          const Text(
            'Connect your AUREL account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Google and email sign-in are implemented, but this build still needs the AUREL Firebase project settings and Google OAuth client ID before account creation can be activated.',
            style: TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: usernameController,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Choose your username',
              prefixIcon: Icon(Icons.person_outline_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onSaveUsername,
              child: const Text('Save username on this device'),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: const TextStyle(
                color: AurelColors.champagneLight,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.creatingAccount,
    required this.busy,
    required this.showPassword,
    required this.googleAvailable,
    required this.onToggleMode,
    required this.onGoogle,
    required this.onEmail,
    required this.onResetPassword,
    required this.onTogglePassword,
  });

  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool creatingAccount;
  final bool busy;
  final bool showPassword;
  final bool googleAvailable;
  final VoidCallback onToggleMode;
  final VoidCallback? onGoogle;
  final VoidCallback onEmail;
  final VoidCallback onResetPassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurelColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.account_circle_outlined,
            color: AurelColors.champagneLight,
            size: 35,
          ),
          const SizedBox(height: 10),
          Text(
            creatingAccount ? 'Create your AUREL account' : 'Welcome back',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            creatingAccount
                ? 'Choose a username and keep your music library with you.'
                : 'Sign in to restore your listening history and collections.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 19),
          if (creatingAccount) ...[
            TextField(
              controller: usernameController,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Choose a username',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
            ),
            const SizedBox(height: 11),
          ],
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: passwordController,
            obscureText: !showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: busy ? null : onEmail,
              child: busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(creatingAccount ? 'Create account' : 'Sign in with email'),
            ),
          ),
          if (!creatingAccount)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : onResetPassword,
                child: const Text('Forgot password?'),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Divider(color: AurelColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: AurelColors.muted.withValues(alpha: 0.8),
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AurelColors.divider)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 25),
            label: Text(
              googleAvailable ? 'Continue with Google' : 'Google setup required',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AurelColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: busy ? null : onToggleMode,
            child: Text(
              creatingAccount
                  ? 'Already have an account? Sign in'
                  : 'New to AUREL? Create an account',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.user,
    required this.usernameController,
    required this.linkedProviders,
    required this.googleAvailable,
    required this.busy,
    required this.onSaveUsername,
    required this.onLinkGoogle,
    required this.onLinkEmail,
    required this.onSync,
    required this.onSignOut,
    required this.onVerifyEmail,
    required this.onRefreshUsername,
  });

  final User user;
  final TextEditingController usernameController;
  final List<String> linkedProviders;
  final bool googleAvailable;
  final bool busy;
  final VoidCallback onSaveUsername;
  final VoidCallback? onLinkGoogle;
  final VoidCallback onLinkEmail;
  final VoidCallback onSync;
  final VoidCallback onSignOut;
  final VoidCallback onVerifyEmail;
  final VoidCallback onRefreshUsername;

  @override
  Widget build(BuildContext context) {
    final googleLinked = linkedProviders.contains('google.com');
    final emailLinked = linkedProviders.contains('password');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurelColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFF3B3025),
            backgroundImage:
                user.photoURL == null ? null : NetworkImage(user.photoURL!),
            child: user.photoURL == null
                ? const Icon(
                    Icons.person_rounded,
                    color: AurelColors.champagneLight,
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(height: 11),
          Text(
            user.email ?? 'AUREL member',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your account is connected',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurelColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: usernameController,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your AUREL username',
              prefixIcon: Icon(Icons.person_outline_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: 9),
          OutlinedButton(
            onPressed: busy ? null : onSaveUsername,
            child: const Text('Save username'),
          ),
          const SizedBox(height: 18),
          const Text(
            'CONNECTED SIGN-IN METHODS',
            style: TextStyle(
              color: AurelColors.champagne,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          _ProviderStatus(
            icon: Icons.g_mobiledata_rounded,
            title: 'Google',
            connected: googleLinked,
          ),
          if (!googleLinked && googleAvailable)
            TextButton.icon(
              onPressed: busy ? null : onLinkGoogle,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Link Google'),
            ),
          _ProviderStatus(
            icon: Icons.mail_outline_rounded,
            title: 'Email & password',
            connected: emailLinked,
          ),
          if (!emailLinked)
            TextButton.icon(
              onPressed: busy ? null : onLinkEmail,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Link email'),
            ),
          if (emailLinked && user.emailVerified == false) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy ? null : onVerifyEmail,
              child: const Text('Send email verification'),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 47,
            child: FilledButton.icon(
              onPressed: busy ? null : onSync,
              icon: const Icon(Icons.cloud_sync_rounded),
              label: const Text('Sync my AUREL library'),
            ),
          ),
          const SizedBox(height: 9),
          TextButton(
            onPressed: busy ? null : onRefreshUsername,
            child: const Text('Refresh account details'),
          ),
          TextButton(
            onPressed: busy ? null : onSignOut,
            child: const Text(
              'Sign out',
              style: TextStyle(color: AurelColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStatus extends StatelessWidget {
  const _ProviderStatus({
    required this.icon,
    required this.title,
    required this.connected,
  });

  final IconData icon;
  final String title;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: AurelColors.champagneLight, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            connected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: connected ? AurelColors.champagneLight : AurelColors.muted,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connected' : 'Not linked',
            style: const TextStyle(
              color: AurelColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncFeature extends StatelessWidget {
  const _SyncFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AurelColors.champagne, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AurelColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: (isError ? const Color(0xFFE7A0A0) : AurelColors.champagne)
              .withValues(alpha: 0.26),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? const Color(0xFFE7A0A0) : AurelColors.champagneLight,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }
}

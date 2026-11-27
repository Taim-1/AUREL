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
  late final TextEditingController _confirmPasswordController;

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
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      if (mounted) {
        setState(() => _error = _friendlyAuthError(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
      'provider-already-linked' => 'This sign-in method is already connected.',
      'no-such-provider' => 'This sign-in method is not connected to this account.',
      'requires-recent-login' => 'Sign in again before changing this security setting.',
      'too-many-requests' => 'Too many attempts. Wait a little and try again.',
      'operation-not-allowed' => 'This sign-in method is not enabled in Firebase yet.',
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
      final syncError = controller.cloudSyncError;
      setState(() {
        _message = syncError == null
            ? 'Signed in. Your AUREL library has been restored and synced.'
            : 'Signed in successfully. Your saved library is still on this device, but cloud restore needs attention.';
        _error = syncError;
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
        final at = email.indexOf('@');
        final dot = email.lastIndexOf('.');
        if (email.contains(' ') ||
            at <= 0 ||
            dot <= at + 1 ||
            dot >= email.length - 1) {
          throw const FormatException('Enter a valid email address.');
        }
        if (password.isEmpty) {
          throw const FormatException('Enter your password.');
        }

        if (_creatingAccount) {
          if (password.length < 8) {
            throw const FormatException(
              'Choose a password with at least 8 characters.',
            );
          }
          if (password != _confirmPasswordController.text) {
            throw const FormatException('The passwords do not match.');
          }
          if (_usernameController.text.trim().length < 2) {
            throw const FormatException(
              'Choose a username with at least 2 characters.',
            );
          }
          await controller.account.createEmailAccount(
            email: email,
            password: password,
            username: _usernameController.text,
          );
          await _afterAuthentication();
          _passwordController.clear();
          _confirmPasswordController.clear();
          if (mounted) {
            setState(() {
              _message = controller.account.emailVerificationNotice ??
                  'Account created. Check your inbox to verify your email address.';
            });
          }
        } else {
          await controller.account.signInWithEmail(
            email: email,
            password: password,
          );
          await _afterAuthentication();
          _passwordController.clear();
          _confirmPasswordController.clear();
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
        await controller.onAccountSignedOut();
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
      if (mounted) {
        setState(() => _message = 'Password reset email sent.');
      }
    });
  }

  Future<void> _refreshAccount() => _run(() async {
        final controller = context.read<AurelController>();
        final user = await controller.account.refreshCurrentUser();
        _usernameController.text = await controller.account.loadUserName();
        controller.notifyAccountChanged();
        if (mounted) {
          setState(() {
            _message = user.emailVerified
                ? 'Account refreshed. Your email address is verified.'
                : 'Account refreshed. Your email address still needs verification.';
          });
        }
      });

  Future<void> _changePassword() async {
    final account = context.read<AurelController>().account;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirmation = TextEditingController();
    var saving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AurelColors.surfaceRaised,
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password (8+ characters)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Color(0xFFE7A0A0), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (next.text.length < 8) {
                        setDialogState(() => dialogError =
                            'Choose a new password with at least 8 characters.');
                        return;
                      }
                      if (next.text != confirmation.text) {
                        setDialogState(() => dialogError = 'The new passwords do not match.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await account.changePassword(
                          currentPassword: current.text,
                          newPassword: next.text,
                        );
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() {
                          _message = 'Your password has been changed.';
                        });
                      } on FirebaseAuthException catch (error) {
                        setDialogState(() {
                          dialogError = _friendlyAuthError(error);
                          saving = false;
                        });
                      } catch (error) {
                        setDialogState(() {
                          dialogError = error.toString().replaceFirst('Exception: ', '');
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update password'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirmation.dispose();
  }

  Future<void> _changeEmail({required bool passwordLinked}) async {
    final account = context.read<AurelController>().account;
    final email = TextEditingController();
    final password = TextEditingController();
    var saving = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AurelColors.surfaceRaised,
          title: const Text('Change email address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'New email address'),
              ),
              if (passwordLinked) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
              ],
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(
                  dialogError!,
                  style: const TextStyle(color: Color(0xFFE7A0A0), fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      try {
                        await account.requestEmailChange(
                          newEmail: email.text,
                          currentPassword: passwordLinked ? password.text : null,
                        );
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() {
                          _message =
                              'A verification link was sent to the new address. Your AUREL email changes after verification.';
                        });
                      } on FirebaseAuthException catch (error) {
                        setDialogState(() {
                          dialogError = _friendlyAuthError(error);
                          saving = false;
                        });
                      } catch (error) {
                        setDialogState(() {
                          dialogError = error.toString().replaceFirst('Exception: ', '');
                          saving = false;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send verification'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
  }

  Future<void> _unlinkProvider(String providerId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AurelColors.surfaceRaised,
        title: Text('Disconnect $label?'),
        content: const Text(
          'This removes this sign-in method from your AUREL account. At least one other sign-in method must remain connected.',
          style: TextStyle(color: AurelColors.muted, fontSize: 12, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep connected'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    final controller = context.read<AurelController>();
    await _run(() async {
      await controller.account.unlinkProvider(providerId);
      controller.notifyAccountChanged();
      if (mounted) {
        setState(() {
          _message = '$label has been disconnected.';
        });
      }
    });
  }

  Future<void> _linkGoogle() => _run(() async {
        final controller = context.read<AurelController>();
        await controller.account.linkGoogle();
        controller.notifyAccountChanged();
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
                        final controller = context.read<AurelController>();
                        await controller.account.linkEmail(
                          email: email.text,
                          password: password.text,
                        );
                        controller.notifyAccountChanged();
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() {
                          _message = controller.account.emailVerificationNotice ??
                              'Email sign-in is now linked. Verify the address to finish setup.';
                        });
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
    if (mounted) {
      setState(() {});
    }
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
              confirmPasswordController: _confirmPasswordController,
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
              onRefreshAccount: _refreshAccount,
              onChangePassword: _changePassword,
              onChangeEmail: () => _changeEmail(
                passwordLinked: account.linkedProviders.contains('password'),
              ),
              onUnlinkGoogle: () => _unlinkProvider('google.com', 'Google'),
              onUnlinkEmail: () => _unlinkProvider('password', 'Email & password'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 13),
            _StatusMessage(message: _error!, isError: true),
          ],
          if (_message != null) ...[
            const SizedBox(height: 13),
            _StatusMessage(message: _message!, isError: false),
          ],
          if (_error == null && controller.cloudSyncError != null) ...[
            const SizedBox(height: 13),
            _StatusMessage(
              message:
                  'Cloud sync needs attention: ${controller.cloudSyncError}',
              isError: true,
            ),
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
                'Your previous download list returns with your account. Audio files remain private to this device and can be downloaded again when the source still permits it.',
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
    required this.confirmPasswordController,
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
  final TextEditingController confirmPasswordController;
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
          if (creatingAccount) ...[
            const SizedBox(height: 11),
            TextField(
              controller: confirmPasswordController,
              obscureText: !showPassword,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
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
    required this.onRefreshAccount,
    required this.onChangePassword,
    required this.onChangeEmail,
    required this.onUnlinkGoogle,
    required this.onUnlinkEmail,
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
  final VoidCallback onRefreshAccount;
  final VoidCallback onChangePassword;
  final VoidCallback onChangeEmail;
  final VoidCallback onUnlinkGoogle;
  final VoidCallback onUnlinkEmail;

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
          if (emailLinked) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  user.emailVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
                  color: user.emailVerified ? AurelColors.champagneLight : const Color(0xFFE5B879),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  user.emailVerified ? 'Email verified' : 'Email not verified',
                  style: TextStyle(
                    color: user.emailVerified ? AurelColors.champagneLight : const Color(0xFFE5B879),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
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
            )
          else if (googleLinked && emailLinked)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onUnlinkGoogle,
                icon: const Icon(Icons.link_off_rounded, size: 17),
                label: const Text('Disconnect Google'),
                style: TextButton.styleFrom(foregroundColor: AurelColors.muted),
              ),
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
            )
          else if (googleLinked)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onUnlinkEmail,
                icon: const Icon(Icons.link_off_rounded, size: 17),
                label: const Text('Disconnect email'),
                style: TextButton.styleFrom(foregroundColor: AurelColors.muted),
              ),
            ),
          if (emailLinked && user.emailVerified == false) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: busy ? null : onVerifyEmail,
              child: const Text('Resend verification email'),
            ),
          ],
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACCOUNT SECURITY',
              style: TextStyle(
                color: AurelColors.champagne,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: busy ? null : onChangeEmail,
            icon: const Icon(Icons.alternate_email_rounded, size: 18),
            label: const Text('Change email address'),
          ),
          if (emailLinked)
            OutlinedButton.icon(
              onPressed: busy ? null : onChangePassword,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Change password'),
            ),
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
            onPressed: busy ? null : onRefreshAccount,
            child: const Text('Refresh account & verification status'),
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

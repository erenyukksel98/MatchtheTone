import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../providers/game_provider.dart';

/// Multiplayer lobby — host gets a code; joiners enter one.
class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  const MultiplayerLobbyScreen({super.key, this.sessionCode});
  final String? sessionCode;

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyState();
}

class _MultiplayerLobbyState extends ConsumerState<MultiplayerLobbyScreen> {
  final _codeController = TextEditingController();
  bool _isHost = false;
  String? _sessionCode;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.sessionCode != null) {
      _sessionCode = widget.sessionCode;
      _isHost = true;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PLAY WITH FRIENDS'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              if (_sessionCode == null) ...[
                // Choose: host or join
                Text('Start or join a session', style: AppTextStyles.headingMedium)
                    .animate().fadeIn(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Everyone who joins gets the exact same five tones.',
                  style: AppTextStyles.bodyMedium,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.xl),

                // Host button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _createSession,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Session'),
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: AppSpacing.md),
                const Center(child: Text('or', style: TextStyle(color: AppColors.textDisabled))),
                const SizedBox(height: AppSpacing.md),

                // Join input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: AppConstants.sessionCodeLength,
                        decoration: const InputDecoration(
                          hintText: 'Enter 6-character code',
                          counterText: '',
                        ),
                        style: AppTextStyles.freqReadout.copyWith(letterSpacing: 4),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: _loading ? null : _joinSession,
                      child: const Text('Join'),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.scoreBad)),
                ],
              ] else ...[
                // Lobby view with code display
                _LobbyView(
                  sessionCode: _sessionCode!,
                  isHost: _isHost,
                  onStart: _startGame,
                  loading: _loading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSession() async {
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });
    try {
      final code = await ref.read(gameNotifierProvider.notifier).joinOrCreateMultiplayerSession(
        code: null,
        isHost: true,
      );
      if (mounted) {
        setState(() {
          _sessionCode = code;
          _isHost = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != AppConstants.sessionCodeLength) {
      setState(() => _error = 'Code must be ${AppConstants.sessionCodeLength} characters.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(gameNotifierProvider.notifier).joinOrCreateMultiplayerSession(
        code: code,
        isHost: false,
      );
      if (result == null) {
        setState(() { _error = 'Session not found. Check the code.'; _loading = false; });
        return;
      }
      if (mounted) {
        setState(() {
          _sessionCode = result;
          _isHost = false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _startGame() async {
    HapticFeedback.heavyImpact();
    final game = ref.read(gameNotifierProvider);
    if (game == null) return;
    context.pushReplacement('/play/memorize', extra: {
      'seed': game.seed,
      'mode': game.mode,
      'sessionCode': _sessionCode,
    });
  }
}

// ── Lobby view (code displayed, player list) ──────────────────────────────────

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.sessionCode,
    required this.isHost,
    required this.onStart,
    required this.loading,
  });

  final String sessionCode;
  final bool isHost;
  final VoidCallback onStart;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('SESSION CODE', style: AppTextStyles.labelLarge).animate().fadeIn(),
          const SizedBox(height: AppSpacing.md),

          // Code display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            ),
            child: Text(
              sessionCode,
              style: AppTextStyles.displayLarge.copyWith(letterSpacing: 12),
            ),
          ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.9, 0.9)),

          const SizedBox(height: AppSpacing.md),

          // Copy & share buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: sessionCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!'), backgroundColor: AppColors.surface),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Code'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () {
                  // In production: Share via system share sheet
                },
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: AppSpacing.lg),
          Text(
            'Share the code with friends.\nEveryone hears the same five tones.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),

          const Spacer(),

          if (isHost) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onStart,
                child: loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                    : const Text('Start Game'),
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'All players hear tones simultaneously when you start.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Waiting for host to start...', style: AppTextStyles.bodyMedium),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

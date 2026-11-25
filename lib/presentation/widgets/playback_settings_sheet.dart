import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../../data/services/playback_controller.dart';

class PlaybackSettingsSheet extends StatefulWidget {
  const PlaybackSettingsSheet({super.key});

  @override
  State<PlaybackSettingsSheet> createState() => _PlaybackSettingsSheetState();
}

class _PlaybackSettingsSheetState extends State<PlaybackSettingsSheet> {
  AndroidEqualizerParameters? _parameters;
  String? _equalizerError;
  bool _loadingEqualizer = false;

  @override
  void initState() {
    super.initState();
    _loadEqualizer();
  }

  Future<void> _loadEqualizer() async {
    setState(() {
      _loadingEqualizer = true;
      _equalizerError = null;
    });
    try {
      final value = await context
          .read<AurelController>()
          .playback
          .loadEqualizerParameters();
      if (!mounted) return;
      setState(() => _parameters = value);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _equalizerError =
            'Equalizer bands become available after audio playback starts.';
      });
    } finally {
      if (mounted) setState(() => _loadingEqualizer = false);
    }
  }

  String _formatTimer(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _presetLabel(AurelEqualizerPreset value) => switch (value) {
        AurelEqualizerPreset.balanced => 'Balanced',
        AurelEqualizerPreset.bass => 'Bass',
        AurelEqualizerPreset.vocal => 'Vocal',
        AurelEqualizerPreset.treble => 'Treble',
        AurelEqualizerPreset.acoustic => 'Acoustic',
      };

  String _frequencyLabel(double value) {
    if (value >= 1000) {
      final khz = value / 1000;
      return '${khz.toStringAsFixed(khz >= 10 ? 0 : 1)} kHz';
    }
    return '${value.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<AurelController>().playback;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AurelColors.muted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Sound & playback',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Fine-tune the way AUREL sounds and plays.',
                style: TextStyle(color: AurelColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 23),
              const _SectionTitleText('PLAYBACK SPEED'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                  final selected = (playback.speed - speed).abs() < 0.01;
                  return ChoiceChip(
                    label: Text('${speed}×'),
                    selected: selected,
                    onSelected: (_) => playback.setSpeed(speed),
                    selectedColor: AurelColors.champagne,
                    backgroundColor: AurelColors.surface,
                    side: BorderSide(
                      color: selected
                          ? AurelColors.champagne
                          : AurelColors.divider,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? AurelColors.background : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: _SectionTitleText('SLEEP TIMER')),
                  if (playback.sleepTimerRemaining != null)
                    Text(
                      _formatTimer(playback.sleepTimerRemaining!),
                      style: const TextStyle(
                        color: AurelColors.champagne,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (15, '15 min'),
                  (30, '30 min'),
                  (45, '45 min'),
                  (60, '1 hour'),
                ].map((option) {
                  return OutlinedButton(
                    onPressed: () => playback.setSleepTimer(
                      Duration(minutes: option.$1),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AurelColors.champagne,
                      side: const BorderSide(color: AurelColors.divider),
                    ),
                    child: Text(option.$2),
                  );
                }).toList(),
              ),
              if (playback.sleepTimerRemaining != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => playback.setSleepTimer(null),
                    child: const Text('Cancel sleep timer'),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: _SectionTitleText('EQUALIZER')),
                  Switch(
                    value: playback.isEqualizerEnabled,
                    activeThumbColor: AurelColors.champagneLight,
                    onChanged: (value) async {
                      if (_parameters == null) await _loadEqualizer();
                      if (!mounted || _parameters == null) return;
                      await playback.toggleEqualizer();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_loadingEqualizer)
                const LinearProgressIndicator(
                  color: AurelColors.champagne,
                  backgroundColor: AurelColors.surface,
                )
              else if (_equalizerError != null)
                Text(
                  _equalizerError!,
                  style: const TextStyle(
                    color: AurelColors.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                )
              else if (_parameters != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: AurelEqualizerPreset.values.map((preset) {
                    return ActionChip(
                      label: Text(_presetLabel(preset)),
                      onPressed: () => playback.applyEqualizerPreset(preset),
                      backgroundColor: AurelColors.surface,
                      side: const BorderSide(color: AurelColors.divider),
                      labelStyle: const TextStyle(
                        color: AurelColors.champagneLight,
                        fontSize: 11,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                ..._parameters!.bands.map((band) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          _frequencyLabel(band.centerFrequency),
                          style: const TextStyle(
                            color: AurelColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: _parameters!.minDecibels,
                          max: _parameters!.maxDecibels,
                          value: band.gain
                              .clamp(
                                _parameters!.minDecibels,
                                _parameters!.maxDecibels,
                              )
                              .toDouble(),
                          onChanged: (value) =>
                              playback.setEqualizerBand(band.index, value),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          '${band.gain.toStringAsFixed(1)} dB',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: AurelColors.muted,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitleText extends StatelessWidget {
  const _SectionTitleText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: AurelColors.champagne,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

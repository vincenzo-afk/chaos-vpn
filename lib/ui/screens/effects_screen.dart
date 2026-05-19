import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/effect_settings.dart';
import '../../models/preset.dart';
import '../../providers/effect_settings_provider.dart';
import '../../providers/chaos_state_provider.dart';
import '../../services/preset_service.dart';
import '../widgets/effect_slider_card.dart';
import '../widgets/spectrogram_painter.dart';
import '../../utils/logger.dart';

/// Effects configuration screen with debounced real-time slider updates,
/// preset selector, randomize button, and all DSP effect controls.
class EffectsScreen extends ConsumerStatefulWidget {
  const EffectsScreen({super.key});

  @override
  ConsumerState<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends ConsumerState<EffectsScreen> {
  Timer? _debounceTimer;
  Timer? _spectrogramTimer;
  Preset? _selectedPreset;

  final _presetService = PresetService();
  final _spectrogramAnalyzer = SpectrogramAnalyzer();

  /// Debounced update: waits 50ms after last change before syncing to native.
  void _updateSettings(EffectSettings newSettings) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      ref.read(effectSettingsProvider.notifier).update(newSettings);
    });
  }

  /// Load a preset into the current settings.
  void _applyPreset(Preset? preset) {
    if (preset == null) return;
    setState(() => _selectedPreset = preset);
    final settings = _presetService.presetToSettings(preset);
    ref.read(effectSettingsProvider.notifier).update(settings);
    ref.read(chaosStateProvider.notifier).setPresetName(preset.name);
    AppLogger.info('[Effects] Applied preset: ${preset.name}');
  }

  /// Randomize all effect parameters.
  void _randomize() {
    final randomSettings = _presetService.randomize();
    setState(() => _selectedPreset = null);
    ref.read(effectSettingsProvider.notifier).update(randomSettings);
    ref.read(chaosStateProvider.notifier).setPresetName(null);
    AppLogger.info('[Effects] Randomized all parameters');
  }

  /// Export current preset as JSON to clipboard.
  Future<void> _exportPresetToClipboard() async {
    final settings = ref.read(effectSettingsProvider);
    final json = jsonEncode(settings.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preset copied to clipboard', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
          backgroundColor: Color(0xFF1A1A1A),
          duration: Duration(seconds: 2),
        ),
      );
      AppLogger.info('[Effects] Exported preset to clipboard');
    }
  }

  /// Import preset from clipboard JSON.
  Future<void> _importPresetFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
              backgroundColor: Color(0xFF1A1A1A),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      final json = jsonDecode(data.text!) as Map<String, dynamic>;
      final settings = EffectSettings.fromJson(json);
      ref.read(effectSettingsProvider.notifier).update(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preset imported from clipboard', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: Color(0xFF1A1A1A),
            duration: Duration(seconds: 2),
          ),
        );
      }
      AppLogger.info('[Effects] Imported preset from clipboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid preset data: $e', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: const Color(0xFFFF0033).withOpacity(0.2),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show save preset dialog.
  Future<void> _showSavePresetDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SAVE PRESET',
              style: TextStyle(
                color: Color(0xFFFF4500),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Preset name',
                hintStyle: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A2A))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A2A2A))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF4500))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('SAVE', style: TextStyle(color: Color(0xFFFF4500), fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final settings = ref.read(effectSettingsProvider);
      final preset = _presetService.settingsToPreset(name, settings, description: descController.text.trim());
      await _presetService.savePreset(preset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved preset: $name', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            backgroundColor: const Color(0xFF1A1A1A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Start feeding simulated frequency data to the spectrogram visualizer.
  /// Generates realistic-looking audio spectra with voice-like formants.
  void _startSpectrogramSimulation() {
    _spectrogramTimer?.cancel();
    final rng = math.Random();

    // Pre-fill with neutral spectrum
    for (int i = 0; i < 20; i++) {
      final neutralSamples = List<double>.generate(256, (_) => rng.nextDouble() * 0.01);
      _spectrogramAnalyzer.feedSamples(neutralSamples);
    }

    _spectrogramTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) return;
      final settings = ref.read(effectSettingsProvider);

      if (settings.masterEnabled && settings.activeCount > 0) {
        // Generate voice-like spectrum with simulated formants
        final t = DateTime.now().microsecondsSinceEpoch / 1000000.0;
        final samples = List<double>.generate(256, (i) {
          // Simulate a voice-like spectrum with pitch harmonics
          final freq = i / 256.0; // normalized frequency
          final formant1 = math.exp(-((freq - 0.08) * 20).abs()); // ~300 Hz formant
          final formant2 = math.exp(-((freq - 0.25) * 15).abs()); // ~1 kHz formant
          final formant3 = math.exp(-((freq - 0.50) * 10).abs()); // ~2 kHz formant
          final pitchHarmonic = math.sin(i * 0.5 + t * 5) * 0.15;
          final noise = rng.nextDouble() * 0.03;
          final wobble = math.sin(t * 2 + i * 0.01) * 0.1;
          return (formant1 * 0.6 + formant2 * 0.4 + formant3 * 0.3 + pitchHarmonic + noise) * (0.5 + wobble);
        });
        _spectrogramAnalyzer.feedSamples(samples);
      } else {
        // Idle: feed near-silence to let spectrogram fade
        final idleSamples = List<double>.generate(256, (_) => rng.nextDouble() * 0.005);
        _spectrogramAnalyzer.feedSamples(idleSamples);
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _startSpectrogramSimulation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _spectrogramTimer?.cancel();
    _spectrogramAnalyzer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(effectSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text(
          '// EFFECTS',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF050505),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Text(
            '${settings.activeCount}/${EffectSettings.totalEffects}',
            style: const TextStyle(
              color: Color(0xFFFF4500),
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ═══════════════════════════════════════════════════════════
          // PRESET SELECTOR + RANDOMIZE BAR
          // ═══════════════════════════════════════════════════════════
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark, size: 14, color: Color(0xFFFF4500)),
                const SizedBox(width: 8),
                const Text(
                  'PRESET',
                  style: TextStyle(
                    color: Color(0xFFFF4500),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<List<Preset>>(
                    future: _presetService.getAllPresets(),
                    builder: (context, snapshot) {
                      final presets = snapshot.data ?? Preset.builtIns;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<Preset>(
                          value: _selectedPreset,
                          hint: const Text(
                            'Load...',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'monospace'),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A1A),
                          style: const TextStyle(
                            color: Color(0xFFFF4500),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFF4500), size: 16),
                          items: presets.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: _applyPreset,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // Randomize button
                IconButton(
                  onPressed: _randomize,
                  icon: const Icon(Icons.shuffle, size: 16),
                  color: const Color(0xFFFF4500),
                  tooltip: 'Randomize all effects',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // Export (copy to clipboard)
                IconButton(
                  onPressed: _exportPresetToClipboard,
                  icon: const Icon(Icons.copy, size: 16),
                  color: const Color(0xFFFF4500),
                  tooltip: 'Copy preset to clipboard',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // Import (from clipboard)
                IconButton(
                  onPressed: _importPresetFromClipboard,
                  icon: const Icon(Icons.paste, size: 16),
                  color: const Color(0xFFFF4500),
                  tooltip: 'Import preset from clipboard',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // Save button
                IconButton(
                  onPressed: _showSavePresetDialog,
                  icon: const Icon(Icons.save, size: 16),
                  color: const Color(0xFFFF4500),
                  tooltip: 'Save current as preset',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ═══════════════════════════════════════════════════════════
          // DSP Pipeline Order (matches README.md & README2.MD):
          // 1. Gain → 2. Graphic EQ → 3. Radio Filter → 4. Bit Crush
          // 5. Soft Clip → 6. Hard Clip → 7. Chorus/Flanger → 8. Echo
          // 9. Reverb (Schroeder) → 9b. Convolution Reverb → 10. Crackle
          // 11. Dropout → 11b. Formant Shifter → 12. Pitch Wobble
          // ═══════════════════════════════════════════════════════════

          // ── Spectrogram Visualizer ──
          _buildSpectrogramSection(settings),

          // ── Stage 1: Volume Gain ──
          EffectSliderCard(
            label: 'GAIN BOOST',
            icon: Icons.volume_up,
            value: settings.gainBoost,
            min: 1.0,
            max: 8.0,
            displayValue: '${settings.gainBoost.toStringAsFixed(1)}x',
            enabled: settings.gainEnabled && settings.gainBoost > 0,
            onChanged: (v) => _updateSettings(settings.copyWith(gainBoost: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(gainEnabled: v)),
          ),

          // ── Stage 2: 5-Band Graphic EQ ──
          // Each band: 80Hz, 300Hz, 1kHz, 3.4kHz, 8kHz with +/-12 dB gain
          _buildEqSection(settings),

          // ── Stage 3: Radio / Telephone Filter ──
          EffectSliderCard(
            label: 'RADIO FILTER',
            icon: Icons.radio,
            value: 1,
            min: 0,
            max: 1,
            divisions: 1,
            displayValue: settings.radioFilterEnabled ? '300–3400 Hz' : 'OFF',
            enabled: settings.radioFilterEnabled,
            onChanged: (_) {},
            onToggle: (v) => _updateSettings(settings.copyWith(radioFilterEnabled: v)),
          ),

          // ── Stage 4: Bit Crusher ──
          EffectSliderCard(
            label: 'BIT CRUSHER',
            icon: Icons.grid_on,
            value: settings.bitCrushDepth.toDouble(),
            min: 2,
            max: 16,
            divisions: 14,
            displayValue: '${settings.bitCrushDepth}-bit',
            enabled: settings.bitCrushEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(bitCrushDepth: v.round())),
            onToggle: (v) => _updateSettings(settings.copyWith(bitCrushEnabled: v)),
          ),

          // ── Stage 5: Soft Clip / Overdrive (Fuzz Distortion) ──
          EffectSliderCard(
            label: 'FUZZ / SOFT CLIP',
            icon: Icons.waves,
            value: settings.fuzzDrive,
            min: 1.0,
            max: 10.0,
            displayValue: '${settings.fuzzDrive.toStringAsFixed(1)}x',
            enabled: settings.fuzzEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(fuzzDrive: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(fuzzEnabled: v)),
          ),

          // ── Stage 6: Hard Clip Threshold ──
          EffectSliderCard(
            label: 'HARD CLIP',
            icon: Icons.flash_on,
            value: settings.clipThreshold,
            min: 0.1,
            max: 1.0,
            divisions: 90,
            displayValue: '${(settings.clipThreshold * 100).round()}%',
            enabled: settings.clipEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(clipThreshold: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(clipEnabled: v)),
          ),

          // ── Stage 7: Chorus / Flanger (Phase Modulation) ──
          _buildChorusSection(settings),

          // ── Stage 8: Echo Delay (Multi-tap) ──
          EffectSliderCard(
            label: 'ECHO DELAY',
            icon: Icons.repeat,
            value: settings.echoDelay,
            min: 20.0,
            max: 500.0,
            divisions: 96,
            displayValue: '${settings.echoDelay.round()}ms',
            enabled: settings.echoEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(echoDelay: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(echoEnabled: v)),
          ),
          // Echo Decay sub-slider
          if (settings.echoEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 68, right: 52),
              child: Row(
                children: [
                  Text(
                    'DECAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey.withOpacity(0.5),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.grey.withOpacity(0.3),
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                        thumbColor: Colors.grey,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: settings.echoDecay,
                        min: 0.0,
                        max: 0.9,
                        divisions: 90,
                        onChanged: (v) => _updateSettings(settings.copyWith(echoDecay: v)),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(settings.echoDecay * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Color(0xFFFF4500),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Stage 9: Room Reverb (Schroeder Network) ──
          EffectSliderCard(
            label: 'ROOM REVERB',
            icon: Icons.meeting_room,
            value: settings.reverbRoomSize,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            displayValue: '${(settings.reverbRoomSize * 100).round()}% wet',
            enabled: settings.reverbEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(reverbRoomSize: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(reverbEnabled: v)),
          ),

          // ── Stage 9b: Convolution Reverb (FFT-based) ──
          EffectSliderCard(
            label: 'CONVOLUTION REVERB',
            icon: Icons.blur_on,
            value: settings.convolutionReverbMix,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            displayValue: '${(settings.convolutionReverbMix * 100).round()}% wet',
            enabled: settings.convolutionReverbEnabled,
            onChanged: (v) => _updateSettings(
                settings.copyWith(convolutionReverbMix: v)),
            onToggle: (v) => _updateSettings(
                settings.copyWith(convolutionReverbEnabled: v)),
          ),

          // ── Stage 10: Crackle / Static Noise ──
          EffectSliderCard(
            label: 'CRACKLE / STATIC',
            icon: Icons.bolt,
            value: settings.crackleIntensity,
            min: 0.0,
            max: 0.15,
            divisions: 150,
            displayValue: '${(settings.crackleIntensity * 100).round()}%',
            enabled: settings.crackleEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(crackleIntensity: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(crackleEnabled: v)),
          ),

          // ── Stage 11: Voice Dropout ──
          EffectSliderCard(
            label: 'VOICE DROPOUT',
            icon: Icons.signal_wifi_off,
            value: settings.dropoutRate,
            min: 0.0,
            max: 0.20,
            divisions: 200,
            displayValue: '${(settings.dropoutRate * 100).round()}%',
            enabled: settings.dropoutEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(dropoutRate: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(dropoutEnabled: v)),
          ),

          // ── Stage 11b: Formant Shifter (LPC-based) ──
          _buildFormantShifterSection(settings),

          // ── Stage 12: Pitch Wobble ──
          EffectSliderCard(
            label: 'PITCH WOBBLE',
            icon: Icons.tune,
            value: settings.pitchWobbleRange,
            min: 0.0,
            max: 12.0,
            divisions: 120,
            displayValue: '±${settings.pitchWobbleRange.toStringAsFixed(1)} st',
            enabled: settings.pitchWobbleEnabled,
            onChanged: (v) => _updateSettings(settings.copyWith(pitchWobbleRange: v)),
            onToggle: (v) => _updateSettings(settings.copyWith(pitchWobbleEnabled: v)),
          ),

          const SizedBox(height: 16),

          // ── Reset Button ──
          Center(
            child: TextButton.icon(
              onPressed: () {
                ref.read(effectSettingsProvider.notifier).reset();
                setState(() => _selectedPreset = null);
                ref.read(chaosStateProvider.notifier).setPresetName(null);
                AppLogger.info('[Effects] Reset to defaults');
              },
              icon: const Icon(Icons.restart_alt, color: Color(0xFFFF0033)),
              label: const Text(
                'RESET TO DEFAULT',
                style: TextStyle(
                  color: Color(0xFFFF0033),
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build the spectrogram visualizer section.
  Widget _buildSpectrogramSection(EffectSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: settings.masterEnabled
              ? const Color(0xFFFF4500).withOpacity(0.08)
              : const Color(0xFF1A1A1A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF41).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.wifi_tethering, size: 18, color: Color(0xFF00FF41)),
              ),
              const SizedBox(width: 12),
              const Text(
                'SPECTROGRAM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'REAL-TIME',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: const Color(0xFF00FF41).withOpacity(0.5),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF080808),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CustomPaint(
                painter: SpectrogramPainter(
                  spectrogramData: _spectrogramAnalyzer.data,
                  isActive: settings.masterEnabled && settings.activeCount > 0,
                ),
                size: const Size(double.infinity, 100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the formant shifter controls.
  Widget _buildFormantShifterSection(EffectSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: settings.formantShifterEnabled
              ? const Color(0xFFFF4500).withOpacity(0.15)
              : const Color(0xFF1A1A1A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: settings.formantShifterEnabled
                      ? const Color(0xFFFF4500).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.record_voice_over,
                  size: 18,
                  color: settings.formantShifterEnabled
                      ? const Color(0xFFFF4500)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FORMANT SHIFTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                        color: settings.formantShifterEnabled
                            ? Colors.white
                            : Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: settings.formantShifterEnabled,
                activeColor: const Color(0xFFFF4500),
                onChanged: (v) => _updateSettings(
                    settings.copyWith(formantShifterEnabled: v)),
              ),
            ],
          ),
          // Sub-controls (only when enabled)
          if (settings.formantShifterEnabled) ...[
            const SizedBox(height: 6),
            _buildSubSlider(
              label: 'SHIFT',
              value: settings.formantShiftFactor,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              displayValue: '${settings.formantShiftFactor.toStringAsFixed(2)}x',
              color: const Color(0xFFFF4500),
              onChanged: (v) => _updateSettings(
                  settings.copyWith(formantShiftFactor: v)),
            ),
            _buildSubSlider(
              label: 'MIX',
              value: settings.formantShiftMix,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              displayValue: '${(settings.formantShiftMix * 100).round()}%',
              color: const Color(0xFFFF4500),
              onChanged: (v) => _updateSettings(
                  settings.copyWith(formantShiftMix: v)),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the 5-band Graphic EQ controls.
  Widget _buildEqSection(EffectSettings settings) {
    const eqLabels = ['80 Hz', '300 Hz', '1 kHz', '3.4 kHz', '8 kHz'];
    final eqGains = List<double>.from(settings.eqBandGains);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFF4500).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.graphic_eq, size: 18, color: Color(0xFFFF4500)),
              ),
              const SizedBox(width: 12),
              const Text(
                'GRAPHIC EQ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Individual band sliders
          ...List.generate(5, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      eqLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: eqGains[i] >= 0
                            ? const Color(0xFFFF4500)
                            : const Color(0xFF0088FF),
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                        thumbColor: eqGains[i] >= 0
                            ? const Color(0xFFFF4500)
                            : const Color(0xFF0088FF),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: eqGains[i],
                        min: -12.0,
                        max: 12.0,
                        divisions: 24,
                        onChanged: (v) {
                          final newGains = List<double>.from(eqGains);
                          newGains[i] = v;
                          _updateSettings(settings.copyWith(eqBandGains: newGains));
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${eqGains[i] >= 0 ? '+' : ''}${eqGains[i].toStringAsFixed(1)} dB',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: eqGains[i] >= 0
                            ? const Color(0xFFFF4500)
                            : const Color(0xFF0088FF),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Reset EQ button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _updateSettings(
                settings.copyWith(eqBandGains: [0.0, 0.0, 0.0, 0.0, 0.0]),
              ),
              child: const Text(
                'FLAT',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 9,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the Chorus / Flanger controls.
  Widget _buildChorusSection(EffectSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: settings.chorusEnabled
              ? const Color(0xFFFF4500).withOpacity(0.15)
              : const Color(0xFF1A1A1A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: settings.chorusEnabled
                      ? const Color(0xFFFF4500).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.layers,
                  size: 18,
                  color: settings.chorusEnabled
                      ? const Color(0xFFFF4500)
                      : Colors.grey.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CHORUS / FLANGER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            letterSpacing: 1,
                            color: settings.chorusEnabled
                                ? Colors.white
                                : Colors.grey.withOpacity(0.5),
                          ),
                        ),
                        const Spacer(),
                        // Mode toggle buttons
                        _buildModeButton('CHORUS', settings, () {
                          _updateSettings(settings.copyWith(
                            chorusEnabled: true,
                            chorusRate: 0.25,
                            chorusDepth: 10.0,
                            chorusWetMix: 0.6,
                          ));
                        }, settings.chorusRate <= 0.5),
                        const SizedBox(width: 4),
                        _buildModeButton('FLANGER', settings, () {
                          _updateSettings(settings.copyWith(
                            chorusEnabled: true,
                            chorusRate: 1.5,
                            chorusDepth: 4.0,
                            chorusWetMix: 0.4,
                          ));
                        }, settings.chorusRate > 0.5),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: settings.chorusEnabled,
                activeColor: const Color(0xFFFF4500),
                onChanged: (v) => _updateSettings(settings.copyWith(chorusEnabled: v)),
              ),
            ],
          ),
          // Sub-controls (only when enabled)
          if (settings.chorusEnabled) ...[
            const SizedBox(height: 6),
            _buildSubSlider(
              label: 'RATE',
              value: settings.chorusRate,
              min: 0.1,
              max: 4.0,
              divisions: 78,
              displayValue: '${settings.chorusRate.toStringAsFixed(1)} Hz',
              color: const Color(0xFFFF4500),
              onChanged: (v) => _updateSettings(settings.copyWith(chorusRate: v)),
            ),
            _buildSubSlider(
              label: 'DEPTH',
              value: settings.chorusDepth,
              min: 1.0,
              max: 20.0,
              divisions: 38,
              displayValue: '${settings.chorusDepth.toStringAsFixed(1)} ms',
              color: const Color(0xFFFF4500),
              onChanged: (v) => _updateSettings(settings.copyWith(chorusDepth: v)),
            ),
            _buildSubSlider(
              label: 'WET MIX',
              value: settings.chorusWetMix,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              displayValue: '${(settings.chorusWetMix * 100).round()}%',
              color: const Color(0xFFFF4500),
              onChanged: (v) => _updateSettings(settings.copyWith(chorusWetMix: v)),
            ),
          ],
        ],
      ),
    );
  }

  /// Small helper for chorus sub-sliders.
  Widget _buildSubSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: Colors.grey.withOpacity(0.5),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color.withOpacity(0.5),
                inactiveTrackColor: const Color(0xFF2A2A2A),
                thumbColor: color,
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Small helper for chorus/flanger mode toggle pills.
  Widget _buildModeButton(String label, EffectSettings settings, VoidCallback onPressed, bool isActive) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFF4500).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isActive ? const Color(0xFFFF4500).withOpacity(0.3) : const Color(0xFF2A2A2A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFFFF4500) : Colors.grey.withOpacity(0.5),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

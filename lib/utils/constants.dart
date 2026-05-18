/// Central audio configuration constants for ChaosVoice.
/// All magic numbers related to audio processing belong here.
class AudioConstants {
  AudioConstants._();

  // ─── Audio Format ───
  static const int sampleRate = 16000;
  static const int channelCount = 1; // Mono
  static const int bitDepth = 16;

  // ─── Buffer Sizes ───
  static const int bufferSizeSmall = 160;  // 10ms at 16kHz
  static const int bufferSizeDefault = 320; // 20ms at 16kHz
  static const int bufferSizeLarge = 640;   // 40ms at 16kHz

  // ─── DSP Thresholds ───
  static const double maxInt16 = 32767.0;
  static const double maxInt16Neg = -32768.0;
  static const double defaultGain = 4.0;
  static const double defaultCrackleProb = 0.03;
  static const double defaultDropoutProb = 0.06;
  static const double defaultSoftDrive = 4.0;
  static const int defaultBitDepth = 6;
  static const double defaultHardClipThreshold = 0.60;
  static const double defaultReverbMix = 0.45;

  // ─── Bandpass ───
  static const double bandpassLowHz = 300.0;
  static const double bandpassHighHz = 3400.0;

  // ─── Echo ───
  static const int echoDelay100ms = 100;
  static const int echoDelay250ms = 250;
  static const int echoMaxDelayMs = 500;
  static const double echoMixDry = 0.70;
  static const double echoMix100 = 0.40;
  static const double echoMix250 = 0.25;

  // ─── Reverb ───
  static const double reverbCombDecay = 0.84;
  static const double reverbApDecay = 0.7;
  static const List<double> reverbCombDelays = [29.7, 37.1, 41.1, 43.7];

  // ─── Pitch Wobble ───
  static const double pitchMinSemitones = -3.0;
  static const double pitchMaxSemitones = 3.0;
  static const double pitchGlideFactor = 0.05;
  static const int pitchIntervalMinMs = 200;
  static const int pitchIntervalMaxMs = 600;

  // ─── Hard Clip ───
  static const double hardClipThreshold = 0.60;

  // ─── Crackle ───
  static const double crackleImpulseStrength = 0.85;

  // ─── Foreground Task ───
  static const int healthCheckIntervalMs = 5000;

  // ─── Channels ───
  static const String methodChannel = 'com.chaosvoice/audio';
  static const String notificationChannelId = 'chaosvoice_channel';
  static const int notificationId = 1001;
}

/// Method channel names used by NativeAudioBridge.
class ChannelNames {
  ChannelNames._();
  static const String audioBridge = 'com.chaosvoice/audio';
}

/// Method channel method constants.
class ChannelMethods {
  ChannelMethods._();
  static const String startService = 'startService';
  static const String stopService = 'stopService';
  static const String isRunning = 'isRunning';
  static const String updateParams = 'updateParams';
}

/// Default DSP effect parameters used by EffectEngine.
class EffectDefaults {
  EffectDefaults._();

  static const double gainBoost = 4.0;
  static const double crackleIntensity = 0.03;
  static const double dropoutRate = 0.06;
  static const double fuzzDrive = 4.0;
  static const int bitCrushDepth = 6;
  static const double clipThreshold = 0.60;
  static const double reverbRoomSize = 0.45;
  static const double echoDelay = 100.0;
  static const double echoDecay = 1.0;
  static const double echoMixDry = 0.70;
  static const double echoMix100 = 0.40;
  static const double echoMix250 = 0.25;
}

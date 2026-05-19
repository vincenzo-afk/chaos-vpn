# Impulse Response Files

Place your convolution reverb impulse response WAV files here.

## Format Requirements
- Sample rate: 16000 Hz (or match the app's configured sample rate)
- Bit depth: 16-bit
- Channels: Mono
- Format: WAV (PCM)

## Usage
The `impulse_response.wav` file will be loaded by the convolution reverb
module (Phase 3 of the roadmap) for realistic room simulation.

Currently, ChaosVoice uses a Schroeder reverb network (4 comb + 2 all-pass)
as the default reverb algorithm. Replace this placeholder with a real IR
file to enable convolution reverb support.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final file = File('assets/sounds/whistle.wav');
  if (!file.parent.existsSync()) {
    file.parent.createSync(recursive: true);
  }

  const int sampleRate = 44100;
  const int durationSeconds = 2;
  const int numSamples = sampleRate * durationSeconds;
  const int numChannels = 1;
  const int byteRate = sampleRate * numChannels * 2; // 16-bit
  const int blockAlign = numChannels * 2;

  final ByteData data = ByteData(44 + numSamples * 2);

  // RIFF Chunk
  _writeString(data, 0, 'RIFF');
  data.setUint32(4, 36 + numSamples * 2, Endian.little);
  _writeString(data, 8, 'WAVE');

  // fmt Chunk
  _writeString(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // Subchunk1Size
  data.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
  data.setUint16(22, numChannels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, 16, Endian.little); // BitsPerSample

  // data Chunk
  _writeString(data, 36, 'data');
  data.setUint32(40, numSamples * 2, Endian.little);

  // Generate Sine Wave (High Pitch - 3000Hz approx whistle)
  // Modulate volume for "pew pew" or generic whistle effect? 
  // Let's do a simple 3000Hz alert tone that pulses.
  
  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    // Frequency modulation for a "siren" or "whistle" effect
    // 2000Hz to 4000Hz fast ramp
    double freq = 2000 + 2000 * (sin(t * 10 * pi)); 
    
    double sample = sin(2 * pi * freq * t);
    // Amplitude modulation
    final int value = (sample * 32767).toInt();
    data.setInt16(44 + i * 2, value, Endian.little);
  }

  file.writeAsBytesSync(data.buffer.asUint8List());
  print('Whistle generated at ${file.path}');
}

void _writeString(ByteData data, int offset, String value) {
  for (int i = 0; i < value.length; i++) {
    data.setUint8(offset + i, value.codeUnitAt(i));
  }
}

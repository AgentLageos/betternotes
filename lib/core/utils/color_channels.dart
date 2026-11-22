import 'dart:ui';

/// 8-bit (0..255) channel values of a [Color].
/// Replacement for the deprecated `Color.red/green/blue/alpha` getters.
extension ColorChannels on Color {
  int get red8 => (r * 255.0).round().clamp(0, 255);
  int get green8 => (g * 255.0).round().clamp(0, 255);
  int get blue8 => (b * 255.0).round().clamp(0, 255);
  int get alpha8 => (a * 255.0).round().clamp(0, 255);
}

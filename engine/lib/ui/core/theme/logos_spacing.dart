import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// **This is a convention, not a transcription.** The reference application exposes no
/// spacing tokens — its `--bible-study-theme-*` set contains colours, border widths and
/// radii, but nothing for gaps. So these values are this application's own 4dp
/// lattice, and the distinction is recorded here so nobody later mistakes them for
/// measured facts.
///
/// A 4dp lattice is used rather than the reference's scattered pixel values because
/// the clone adds layouts the reference does not have (a bottom navigation bar, a
/// drawer sidebar). Without a scale, every new surface invents its own padding and the
/// spacing drifts apart screen by screen.
@immutable
class LogosSpacing {
  const LogosSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class DartboardConstants {
  DartboardConstants._();

  // Board geometry (mm)
  static const double bullseyeInnerRadius = 6.35;
  static const double bullseyeOuterRadius = 15.9;
  static const double tripleInnerRadius = 99.0;
  static const double tripleOuterRadius = 107.0;
  static const double doubleInnerRadius = 162.0;
  static const double doubleOuterRadius = 170.0;
  static const double boardRadius = 170.0;

  // Wedge layout
  static const List<int> wedgeValues = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
    3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];
  static const double wedgeAngleDegrees = 18.0;

  // Game defaults
  static const int defaultGameType = 501;
  static const int maxDartsPerTurn = 3;

  // Board detection — color-based (Tier 1)
  static const int greenHueMin = 70;
  static const int greenHueMax = 150;
  static const int greenSatMin = 15;
  static const int greenValMin = 10;
  static const int greenValMax = 55;

  static const int redHueMax = 20;
  static const int redHueMin = 340;
  static const int redSatMin = 25;
  static const int redValMin = 10;
  static const int redValMax = 55;

  static const double minBoardColorRatio = 0.015;
  static const double centerSampleRatio = 0.4;

  // Board detection — brightness fallback (Tier 2)
  static const int boardBrightnessThreshold = 60;
  static const double minBoardAreaRatio = 0.02;
  static const int minBoardRadiusPx = 30;
  static const int boardEdgeDropThreshold = 15;

  // Board detection — center fallback (Tier 3)
  static const double centerFallbackRadiusRatio = 0.35;

  // Dart detection thresholds
  static const int imageDiffThreshold = 40;
  static const int minBlobArea = 15;
  static const int maxDetectedBlobs = 3;
}

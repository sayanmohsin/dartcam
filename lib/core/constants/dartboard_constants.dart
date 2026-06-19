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

  // Board detection thresholds
  static const int boardBrightnessThreshold = 80;
  static const double minBoardAreaRatio = 0.05;
  static const int minBoardRadiusPx = 50;
  static const int boardEdgeDropThreshold = 25;

  // Dart detection thresholds
  static const int imageDiffThreshold = 50;
  static const int minBlobArea = 50;
  static const int maxDetectedBlobs = 3;
  static const double minDartAspectRatio = 2.0;
}

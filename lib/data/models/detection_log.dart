class DetectionLog {
  final DateTime timestamp;
  final String? imagePath;
  final int? imageSizeBytes;
  final int rawBoxCount;
  final int nmsBoxCount;
  final Map<int, int> classDistribution;
  final int dartTipCount;
  final List<int> calibrationPointIds;
  final String status;
  final double confidenceThreshold;

  const DetectionLog({
    required this.timestamp,
    this.imagePath,
    this.imageSizeBytes,
    required this.rawBoxCount,
    required this.nmsBoxCount,
    required this.classDistribution,
    required this.dartTipCount,
    required this.calibrationPointIds,
    required this.status,
    required this.confidenceThreshold,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
        'imageSizeBytes': imageSizeBytes,
        'rawBoxCount': rawBoxCount,
        'nmsBoxCount': nmsBoxCount,
        'classDistribution':
            classDistribution.map((k, v) => MapEntry(k.toString(), v)),
        'dartTipCount': dartTipCount,
        'calibrationPointIds': calibrationPointIds,
        'status': status,
        'confidenceThreshold': confidenceThreshold,
      };

  factory DetectionLog.fromJson(Map<String, dynamic> json) => DetectionLog(
        timestamp: DateTime.parse(json['timestamp'] as String),
        imagePath: json['imagePath'] as String?,
        imageSizeBytes: json['imageSizeBytes'] as int?,
        rawBoxCount: json['rawBoxCount'] as int,
        nmsBoxCount: json['nmsBoxCount'] as int,
        classDistribution: (json['classDistribution'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
        dartTipCount: json['dartTipCount'] as int,
        calibrationPointIds:
            List<int>.from(json['calibrationPointIds'] as List),
        status: json['status'] as String,
        confidenceThreshold: (json['confidenceThreshold'] as num).toDouble(),
      );
}

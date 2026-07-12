class CloudCredentials {
  final String serverUrl;
  final String apiKey;
  final String email;
  final DateTime registeredAt;

  const CloudCredentials({
    required this.serverUrl,
    required this.apiKey,
    required this.email,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'apiKey': apiKey,
        'email': email,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory CloudCredentials.fromJson(Map<String, dynamic> json) =>
      CloudCredentials(
        serverUrl: json['serverUrl'] as String,
        apiKey: json['apiKey'] as String,
        email: json['email'] as String,
        registeredAt: DateTime.parse(json['registeredAt'] as String),
      );
}

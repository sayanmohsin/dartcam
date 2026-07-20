import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/constants/env_config.dart';
import '../../data/models/cloud_credentials.dart';
import '../../services/cloud_auth_service.dart';
import '../../services/cloud_usage_service.dart';
import '../../services/thingd_service.dart';

class CloudSettingsScreen extends StatefulWidget {
  final ThingdService thingd;

  const CloudSettingsScreen({super.key, required this.thingd});

  @override
  State<CloudSettingsScreen> createState() => _CloudSettingsScreenState();
}

class _CloudSettingsScreenState extends State<CloudSettingsScreen> {
  late CloudAuthService _auth;
  CloudCredentials? _creds;
  bool _isChecking = true;
  bool _isConnected = false;
  bool _isTesting = false;
  bool _isFromEnv = false;
  String? _error;
  String? _userEmail;
  bool _emailSaving = false;

  final _serverUrlController = TextEditingController(
    text: EnvConfig.cloudUrl,
  );
  final _apiKeyController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _auth = CloudAuthService(widget.thingd);
    _load();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final creds = await _auth.loadCredentials();
    final fromEnv = await _auth.isUsingEnvConfig();
    final email = await widget.thingd.getUserEmail();
    if (mounted) {
      setState(() {
        _creds = creds;
        _isFromEnv = fromEnv;
        _isChecking = false;
        _userEmail = email;
        _emailController.text = email ?? '';
      });
    }
    if (creds != null) {
      _serverUrlController.text = creds.serverUrl;
      await _checkConnection(creds);
    }
  }

  Future<void> _checkConnection(CloudCredentials creds) async {
    setState(() => _isTesting = true);
    final ok = await _auth.pingServer(creds.serverUrl, apiKey: creds.apiKey);
    if (mounted) {
      setState(() {
        _isConnected = ok;
        _isTesting = false;
      });
    }
  }

  Future<void> _save() async {
    final serverUrl = _serverUrlController.text.trim();
    var apiKey = _apiKeyController.text.trim();

    if (serverUrl.isEmpty) {
      setState(() => _error = 'Server URL is required');
      return;
    }

    // Use existing API key if new one is empty
    if (apiKey.isEmpty && _creds != null) {
      apiKey = _creds!.apiKey;
    }

    if (apiKey.isEmpty) {
      setState(() => _error = 'API key is required');
      return;
    }

    setState(() {
      _error = null;
      _isTesting = true;
    });

    // Test connection
    final ok = await _auth.pingServer(serverUrl, apiKey: apiKey);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _error = 'Could not connect to $serverUrl. Check URL and API key.';
        _isTesting = false;
      });
      return;
    }

    final creds = CloudCredentials(
      serverUrl: serverUrl,
      apiKey: apiKey,
      email: 'env',
      registeredAt: DateTime.now(),
    );

    await _auth.saveCredentials(creds);

    if (mounted) {
      setState(() {
        _creds = creds;
        _isFromEnv = false;
        _isConnected = true;
        _isTesting = false;
        _error = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to thingd.cloud'),
            backgroundColor: Color(0xFF006400),
          ),
        );
      }
    }
  }

  Future<void> _saveEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _emailSaving = true);
    await widget.thingd.saveUserEmail(email);
    if (mounted) {
      setState(() {
        _userEmail = email;
        _emailSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email saved'),
          backgroundColor: Color(0xFF006400),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _auth.clearCredentials();
    if (mounted) {
      setState(() {
        _creds = null;
        _isConnected = false;
        _isFromEnv = EnvConfig.hasCloudConfig;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
        title: const Text('Cloud Settings',
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isChecking
                          ? Colors.grey[700]!
                          : _isConnected
                              ? const Color(0xFF006400)
                              : _isFromEnv
                                  ? const Color(0xFFFF6D00)
                                  : Colors.grey[700]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isChecking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white38,
                            strokeWidth: 2,
                          ),
                        )
                      else if (_isConnected)
                        const Icon(Icons.cloud_done,
                            color: Color(0xFF006400), size: 20)
                      else if (_isFromEnv)
                        const Icon(Icons.cloud_outlined,
                            color: Color(0xFFFF6D00), size: 20)
                      else
                        const Icon(Icons.cloud_off,
                            color: Colors.white38, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _isChecking
                            ? 'Checking...'
                            : _isConnected
                                ? 'Connected to thingd.cloud'
                                : _isFromEnv
                                    ? 'Env configured — test connection'
                                    : 'Not configured',
                        style: TextStyle(
                          color: _isConnected
                              ? const Color(0xFF006400)
                              : _isFromEnv
                                  ? const Color(0xFFFF6D00)
                                  : Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Env config badge
              if (_isFromEnv && !_isConnected)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: Color(0xFFFF6D00), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cloud URL and API key loaded from environment variables.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Server URL
              const Text(
                'Server URL',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://api.thingd.cloud',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: kInputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kNeonOrange),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // API Key
              const Text(
                'API Key',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: _creds != null
                      ? '•••••••• (saved)'
                      : EnvConfig.hasCloudConfig
                          ? '•••••••• (from env)'
                          : 'Enter your API key',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: kInputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: kNeonOrange),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Email
              const Text(
                'Your Email',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: kInputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: kNeonOrange),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _emailSaving ? null : _saveEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeonOrange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _emailSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Info text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey[800]!),
                ),
                child: const Text(
                  'Game data stays on your device. Match results and player '
                  'stats are pushed to the cloud for leaderboard and history.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[900]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[700]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Buttons
              if (_creds != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isTesting ? null : _disconnect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[300],
                          side: BorderSide(color: Colors.red[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Disconnect'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isTesting ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNeonOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Reconnect'),
                      ),
                    ),
                  ],
                )
              else if (_isFromEnv)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Test Connection'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeonOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Connect'),
                  ),
                ),

              if (_isConnected && _creds != null) ...[
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                const Text(
                  'Usage Sync',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _CloudUsageStatus(creds: _creds!, auth: _auth, email: _userEmail ?? ''),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudUsageStatus extends StatefulWidget {
  final CloudCredentials creds;
  final CloudAuthService auth;
  final String email;

  const _CloudUsageStatus({
    required this.creds,
    required this.auth,
    required this.email,
  });

  @override
  State<_CloudUsageStatus> createState() => _CloudUsageStatusState();
}

class _CloudUsageStatusState extends State<_CloudUsageStatus> {
  int? _matchCount;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final svc = CloudUsageService(widget.auth);
    final history = await svc.fetchMatchHistory(widget.creds, widget.email);
    if (mounted) {
      setState(() => _matchCount = history.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _matchCount != null ? Icons.cloud_done : Icons.cloud_outlined,
            color: _matchCount != null && _matchCount! > 0
                ? const Color(0xFFFF6D00)
                : Colors.grey[500],
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            _matchCount != null
                ? '$_matchCount match result${_matchCount == 1 ? '' : 's'} synced'
                : 'Checking cloud stats...',
            style: TextStyle(
                color: _matchCount != null ? Colors.white54 : Colors.grey[500],
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

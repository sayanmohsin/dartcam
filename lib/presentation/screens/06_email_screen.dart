import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/thingd_service.dart';

class EmailScreen extends StatefulWidget {
  final ThingdService thingd;
  const EmailScreen({super.key, required this.thingd});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _controller.text.trim();
    if (email.isEmpty) return;
    setState(() => _saving = true);
    await widget.thingd.saveUserEmail(email);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupScreen(thingd: widget.thingd),
      ),
    );
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupScreen(thingd: widget.thingd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Icon(Icons.cloud_outlined, color: kNeonOrange, size: 64),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cloud Sync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your email to sync match results and stats across devices. '
                'Your data is scoped to this email in the shared cloud store.',
                style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNeonOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip — I don\'t want cloud sync',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

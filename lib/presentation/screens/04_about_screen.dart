import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isLaunching = false;

  Future<void> _openGithub() async {
    if (_isLaunching) return;
    _isLaunching = true;
    final uri = Uri.parse('https://github.com/sayanmohsin');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    _isLaunching = false;
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Image.asset(
                  'assets/icon.png',
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: 20),
                Text(
                  'DARTCAM',
                  style: TextStyle(
                    color: kNeonOrange,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Snap. Score. Win.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v0.1.0 Beta',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(color: kNeonOrange, width: 3),
                    ),
                  ),
                  child: const Text(
                    'Made for dart nights with friends.\nNo servers, no accounts —\njust you, the board, and the game.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Built by',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sayan Mohsin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _openGithub,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kCardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset(
                        'assets/github.svg',
                        colorFilter: const ColorFilter.mode(
                          Colors.white70,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'DARTCAM',
                  style: TextStyle(
                    color: Colors.white12,
                    fontSize: 11,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

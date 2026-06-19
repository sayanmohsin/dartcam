import 'package:flutter/material.dart';

const kNeonOrange = Color(0xFFFF6D00);
const kNeonOrangeGlow = Color(0xFFFF9100);

class ScoreBadge extends StatelessWidget {
  final int score;
  final String label;
  final VoidCallback? onTap;

  const ScoreBadge({
    super.key,
    required this.score,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: onTap != null ? kNeonOrange : const Color(0xFF424242),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? kNeonOrangeGlow : const Color(0xFF616161),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/dartboard_constants.dart';

const kNeonOrange = Color(0xFFFF6D00);
const kNeonOrangeGlow = Color(0xFFFF9100);

class ManualPickerResult {
  final int score;
  final int multiplier;
  final String label;

  const ManualPickerResult({
    required this.score,
    required this.multiplier,
    required this.label,
  });
}

class ManualPickerGrid extends StatefulWidget {
  final int initialScore;
  final String initialLabel;

  const ManualPickerGrid({
    super.key,
    required this.initialScore,
    required this.initialLabel,
  });

  @override
  State<ManualPickerGrid> createState() => _ManualPickerGridState();
}

class _ManualPickerGridState extends State<ManualPickerGrid> {
  late int _selectedMultiplier;
  late int? _selectedScore;
  bool _isBull = false;

  @override
  void initState() {
    super.initState();
    _selectedMultiplier = _parseMultiplier(widget.initialLabel);
    _selectedScore = _parseScore(widget.initialLabel);
    _isBull = widget.initialLabel == 'BULL' || _selectedScore == 50 || _selectedScore == 25;
  }

  int _parseMultiplier(String label) {
    if (label.startsWith('T')) return 3;
    if (label.startsWith('D')) return 2;
    return 1;
  }

  int? _parseScore(String label) {
    if (label == 'BULL') return 50;
    if (label == '25') return 25;
    final cleaned = label.replaceAll(RegExp(r'^[DT]'), '');
    return int.tryParse(cleaned);
  }

  bool get _isMultiplierValid {
    if (_isBull && _selectedScore == 50) return _selectedMultiplier == 1;
    if (_isBull && _selectedScore == 25) return _selectedMultiplier == 1;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Multiplier',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: [
              _selectedMultiplier == 1,
              _selectedMultiplier == 2,
              _selectedMultiplier == 3,
            ],
            onPressed: (index) {
              final newMultiplier = index + 1;
              if (_isBull && _selectedScore == 50 && newMultiplier != 1) return;
              if (_isBull && _selectedScore == 25 && newMultiplier != 1) return;
              setState(() {
                _selectedMultiplier = newMultiplier;
              });
            },
            color: Colors.white70,
            selectedColor: kNeonOrange,
            borderColor: Colors.grey[600],
            selectedBorderColor: kNeonOrangeGlow,
            disabledColor: Colors.grey[800],
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Single'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Double'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Triple'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScoreButton(50, 'BULL', isSpecial: true),
              _buildScoreButton(25, '25', isSpecial: true),
              ...DartboardConstants.wedgeValues.map(
                (value) => _buildScoreButton(value, '$value'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isMultiplierValid)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Bullseye can only be Single',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedScore != null && _isMultiplierValid)
                  ? () {
                      final label = _buildLabel(_selectedScore!, _selectedMultiplier);
                      Navigator.of(context).pop(ManualPickerResult(
                        score: _selectedScore!,
                        multiplier: _selectedMultiplier,
                        label: label,
                      ));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm Selection'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreButton(int score, String label, {bool isSpecial = false}) {
    final isSelected = _selectedScore == score;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedScore = score;
          _isBull = isSpecial;
          if (isSpecial) {
            _selectedMultiplier = 1;
          }
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? kNeonOrange : const Color(0xFF424242),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kNeonOrangeGlow : Colors.grey[600]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSpecial ? const Color(0xFFFFD700) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _buildLabel(int score, int multiplier) {
    if (score == 50) return 'BULL';
    if (score == 25) return '25';
    switch (multiplier) {
      case 3:
        return 'T$score';
      case 2:
        return 'D$score';
      default:
        return '$score';
    }
  }
}

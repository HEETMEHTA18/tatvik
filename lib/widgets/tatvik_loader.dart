import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

class TatvikLoader extends StatefulWidget {
  final String? baseText;

  const TatvikLoader({super.key, this.baseText});

  @override
  State<TatvikLoader> createState() => _TatvikLoaderState();
}

class _TatvikLoaderState extends State<TatvikLoader> {
  int _currentIndex = 0;
  Timer? _timer;

  final List<String> _phrases = [
    'Tatvik is reasoning...',
    'Tatvik is connecting the knowledge graph...',
    'Tatvik is predicting trends...',
    'Tatvik is checking security advisories...',
    'Tatvik is analyzing repositories...',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _phrases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              widget.baseText ?? _phrases[_currentIndex],
              key: ValueKey<int>(_currentIndex),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

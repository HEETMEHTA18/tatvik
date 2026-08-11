import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

class AnimatedCopyButton extends StatefulWidget {
  final String text;
  final double size;
  final Color? color;
  final Color? successColor;

  const AnimatedCopyButton({
    super.key,
    required this.text,
    this.size = 18.0,
    this.color,
    this.successColor,
  });

  @override
  State<AnimatedCopyButton> createState() => _AnimatedCopyButtonState();
}

class _AnimatedCopyButtonState extends State<AnimatedCopyButton>
    with SingleTickerProviderStateMixin {
  bool _isCopied = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    if (_isCopied || widget.text.isEmpty) return;

    await _controller.forward();
    await Clipboard.setData(ClipboardData(text: widget.text));

    setState(() {
      _isCopied = true;
    });

    await _controller.reverse();

    // Revert back after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.color ?? AppTheme.textSecondary;
    final activeColor = widget.successColor ?? AppTheme.success;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.size + 12,
          minHeight: widget.size + 12,
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: _isCopied
              ? Icon(
                  Icons.check_circle_outline_rounded,
                  key: const ValueKey('copied'),
                  size: widget.size,
                  color: activeColor,
                )
              : Icon(
                  Icons.copy_rounded,
                  key: const ValueKey('copy'),
                  size: widget.size,
                  color: defaultColor,
                ),
        ),
        onPressed: _handleCopy,
        tooltip: _isCopied ? 'Copied!' : 'Copy to clipboard',
      ),
    );
  }
}

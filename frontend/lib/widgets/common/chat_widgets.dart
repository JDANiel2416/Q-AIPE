import 'dart:async';
import 'package:flutter/material.dart';

class TypingMessage extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onComplete;

  const TypingMessage({
    super.key,
    required this.text,
    required this.style,
    this.onComplete,
  });

  @override
  State<TypingMessage> createState() => _TypingMessageState();
}

class _TypingMessageState extends State<TypingMessage> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    // Velocidad de tipeo: 20ms por caracter
    _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
        widget.onComplete?.call();
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
    return Text(_displayedText, style: widget.style);
  }
}

class StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredItem({super.key, required this.index, required this.child});

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Delay escalonado: 150ms * index
    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.2),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

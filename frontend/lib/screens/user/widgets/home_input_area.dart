import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../home_colors.dart';

class HomeInputArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final bool isLoading;
  final bool isTyping;
  final VoidCallback onSubmitted;
  final Function(String path) onVoiceRecorded;

  const HomeInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.isLoading,
    required this.isTyping,
    required this.onSubmitted,
    required this.onVoiceRecorded,
  });

  @override
  State<HomeInputArea> createState() => _HomeInputAreaState();
}

class _HomeInputAreaState extends State<HomeInputArea>
    with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isCancelled = false; // Add this
  int _recordDuration = 0;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _isCancelled = false;
          _recordDuration = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
          if (_recordDuration >= 30) {
            _stopRecording();
          }
        });
      }
    } catch (e) {
      print("Error recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    if (!_isRecording) return;

    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null && !_isCancelled) {
      widget.onVoiceRecorded(path);
    }
    _isCancelled = false;
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    // Si arrastra hacia arriba más de 60px
    if (details.localOffsetFromOrigin.dy < -60) {
      if (!_isCancelled) {
        setState(() => _isCancelled = true);
      }
    } else {
      if (_isCancelled) {
        setState(() => _isCancelled = false);
      }
    }
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final showSendButton = widget.isTyping && !widget.isLoading;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: _isCancelled
                ? Colors.red.withOpacity(0.1)
                : HomeColors.surface(context).withOpacity(0.7),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: HomeColors.shadowMedium(context).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: _isRecording
                  ? (_isCancelled ? Colors.red : Colors.red.withOpacity(0.5))
                  : Colors.white.withOpacity(0.2),
              width: _isRecording ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: _isRecording ? _buildRecordingView() : _buildTextField(),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onLongPressStart: showSendButton
                    ? null
                    : (_) => _startRecording(),
                onLongPressMoveUpdate: showSendButton
                    ? null
                    : _handleLongPressMoveUpdate,
                onLongPressEnd: showSendButton ? null : (_) => _stopRecording(),
                child: Container(
                  margin: const EdgeInsets.only(right: 6, bottom: 6, top: 6),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording && !_isCancelled
                            ? 1.0 + (_animController.value * 0.2)
                            : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? (_isCancelled ? Colors.red : Colors.red)
                                : (showSendButton || widget.isLoading
                                      ? HomeColors.primary(context)
                                      : HomeColors.surfaceVariant(context)),
                            shape: BoxShape.circle,
                            boxShadow:
                                (showSendButton ||
                                    widget.isLoading ||
                                    _isRecording)
                                ? [
                                    BoxShadow(
                                      color: _isRecording
                                          ? Colors.red.withOpacity(0.4)
                                          : HomeColors.primary(
                                              context,
                                            ).withOpacity(0.3),
                                      blurRadius: _isRecording ? 12 : 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: IconButton(
                            icon: widget.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _isCancelled
                                        ? Icons.delete_outline
                                        : (showSendButton
                                              ? Icons.arrow_upward_rounded
                                              : Icons.mic_rounded),
                                    color: (showSendButton || _isRecording)
                                        ? Colors.white
                                        : HomeColors.textMuted(context),
                                    size: 20,
                                  ),
                            onPressed: showSendButton
                                ? widget.onSubmitted
                                : () {
                                    // Hint logic if tapped instead of held?
                                  },
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Scrollbar(
      controller: widget.scrollController,
      thumbVisibility: false,
      radius: const Radius.circular(8),
      thickness: 4,
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: widget.scrollController,
        enabled: !widget.isLoading,
        maxLines: 5,
        minLines: 1,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: TextStyle(
          color: widget.isLoading
              ? HomeColors.textMuted(context)
              : HomeColors.textPrimary(context),
          fontSize: 15,
          height: 1.4,
        ),
        cursorColor: HomeColors.primary(context),
        decoration: InputDecoration(
          hintText: widget.isLoading ? "Buscando..." : "Escribe tu pedido...",
          hintStyle: TextStyle(
            color: HomeColors.textMuted(context).withOpacity(0.5),
            fontSize: 15,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 14,
          ),
          isDense: true,
          fillColor: Colors.transparent,
          filled: true,
        ),
        onSubmitted: null,
      ),
    );
  }

  Widget _buildRecordingView() {
    if (_isCancelled) {
      return Container(
        height: 52,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(
              "Soltar para cancelar",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          FadeTransition(
            opacity: _animController,
            child: const Icon(
              Icons.fiber_manual_record,
              color: Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Grabando... ${_formatDuration(_recordDuration)} / 00:30",
            style: TextStyle(
              color: HomeColors.textPrimary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    "Desliza arriba",
                    style: TextStyle(
                      color: HomeColors.textMuted(context),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: HomeColors.textMuted(context),
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

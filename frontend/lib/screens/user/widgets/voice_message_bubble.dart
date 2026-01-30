import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../home_colors.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioPath;
  final bool isUser;

  const VoiceMessageBubble({
    Key? key,
    required this.audioPath,
    required this.isUser,
  }) : super(key: key);

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Listen to state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setSourceDeviceFile(widget.audioPath);
      final d = await _audioPlayer.getDuration();
      if (d != null && mounted) {
        setState(() => _duration = d);
      }
    } catch (e) {
      print("Error loading audio duration: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isUser
        ? HomeColors.primary(context)
        : HomeColors.surface(context);
    final textColor = widget.isUser
        ? Colors.white
        : HomeColors.textPrimary(context);
    final iconColor = widget.isUser
        ? Colors.white
        : HomeColors.primary(context);

    // Calculate progress for slider
    double progress = 0.0;
    if (_duration.inMilliseconds > 0) {
      progress = _position.inMilliseconds / _duration.inMilliseconds;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(widget.isUser ? 20 : 0),
          bottomRight: Radius.circular(widget.isUser ? 0 : 20),
        ),
        boxShadow: widget.isUser
            ? [
                BoxShadow(
                  color: HomeColors.primary(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            ),
            color: iconColor,
            iconSize: 32,
            onPressed: _togglePlay,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          SizedBox(
            width: 120, // Fixed width for slider
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: widget.isUser
                    ? Colors.white
                    : HomeColors.primary(context),
                inactiveTrackColor: widget.isUser
                    ? Colors.white.withOpacity(0.3)
                    : HomeColors.textSecondary(context).withOpacity(0.2),
                thumbColor: widget.isUser
                    ? Colors.white
                    : HomeColors.primary(context),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 2,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (v) {
                  final newPos = Duration(
                    milliseconds: (v * _duration.inMilliseconds).toInt(),
                  );
                  _audioPlayer.seek(newPos);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_position),
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;
  final String time;
  final bool isRead;

  const VoiceMessageBubble({
    Key? key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
    required this.time,
    this.isRead = false,
  }) : super(key: key);

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF3D9DF2);
  static const Color primaryRed = Color(0xFFD94350);

  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late AnimationController _waveController;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _duration = Duration(seconds: widget.durationSeconds);

    _positionSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
        if (state == PlayerState.playing) {
          _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
          if (state == PlayerState.completed) {
            setState(() => _position = Duration.zero);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final bubbleColor = widget.isMe ? primaryBlue : Colors.grey.shade200;
    final iconColor = widget.isMe ? Colors.white : primaryBlue;
    final textColor = widget.isMe ? Colors.white : Colors.black87;
    final subTextColor =
        widget.isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade600;
    final sliderActiveColor = widget.isMe ? Colors.white : primaryBlue;
    final sliderInactiveColor = widget.isMe
        ? Colors.white.withOpacity(0.35)
        : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(20),
      ),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.25)
                        : primaryBlue.withOpacity(0.12),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: iconColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isPlaying
                        ? AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return _WaveformPainterWidget(
                                progress: _progress,
                                color: iconColor,
                                animationValue: _waveController.value,
                              );
                            },
                          )
                        : _WaveformPainterWidget(
                            progress: _progress,
                            color: iconColor,
                            animationValue: 0.0,
                          ),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: sliderActiveColor,
                        inactiveTrackColor: sliderInactiveColor,
                        thumbColor: sliderActiveColor,
                        overlayColor: sliderActiveColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _progress,
                        onChanged: (value) async {
                          final newPos = Duration(
                            milliseconds:
                                (value * _duration.inMilliseconds).round(),
                          );
                          await _player.seek(newPos);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position.inMilliseconds > 0
                      ? _position
                      : _duration),
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
                Row(
                  children: [
                    Text(
                      widget.time,
                      style: TextStyle(fontSize: 10, color: subTextColor),
                    ),
                    if (widget.isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        widget.isRead ? Icons.done_all : Icons.done,
                        size: 13,
                        color: widget.isRead
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainterWidget extends StatelessWidget {
  final double progress;
  final Color color;
  final double animationValue;

  const _WaveformPainterWidget({
    required this.progress,
    required this.color,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(
        painter: _WaveformPainter(
          progress: progress,
          color: color,
          animValue: animationValue,
        ),
        size: const Size(double.infinity, 28),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double animValue;
  static final List<double> _bars = _generateBars();

  static List<double> _generateBars() {
    final rng = Random(42);
    return List.generate(28, (_) => 0.2 + rng.nextDouble() * 0.8);
  }

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _bars.length;
    final barWidth = size.width / (barCount * 1.8);
    final gap = barWidth * 0.8;
    final totalWidth = barCount * (barWidth + gap) - gap;
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < barCount; i++) {
      final x = startX + i * (barWidth + gap);
      final barFraction = i / barCount;
      final isPast = barFraction <= progress;

      double height = _bars[i] * size.height;
      if (isPast && animValue > 0) {
        final wave = sin(animValue * pi * 2 + i * 0.5) * 0.2;
        height = (height * (1 + wave)).clamp(size.height * 0.15, size.height);
      }

      final paint = Paint()
        ..color = isPast ? color : color.withOpacity(0.35)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      final top = (size.height - height) / 2;
      canvas.drawLine(
        Offset(x + barWidth / 2, top),
        Offset(x + barWidth / 2, top + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.animValue != animValue ||
      old.color != color;
}

class VoiceRecordingOverlay extends StatelessWidget {
  final Duration duration;
  final double dragOffset;
  final Animation<double> pulseAnimation;

  static const Color primaryRed = Color(0xFFD94350);
  static const Color primaryBlue = Color(0xFF3D9DF2);

  const VoiceRecordingOverlay({
    Key? key,
    required this.duration,
    required this.dragOffset,
    required this.pulseAnimation,
  }) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final cancelOpacity = (dragOffset.abs() / 80).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryRed
                      .withOpacity(0.4 + 0.6 * pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color:
                          primaryRed.withOpacity(0.3 * pulseAnimation.value),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(duration),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedOpacity(
              opacity: cancelOpacity,
              duration: const Duration(milliseconds: 100),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_ios_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Glisser pour annuler',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.mic_rounded, color: primaryRed, size: 22),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_fx.dart';
import '../theme/colors.dart';

class WalkingLoader extends StatefulWidget {
  const WalkingLoader({
    super.key,
    this.title = 'Walk to your rhythm',
    this.subtitle,
    this.compact = false,
    this.center = true,
  });

  final String title;
  final String? subtitle;
  final bool compact;
  final bool center;

  @override
  State<WalkingLoader> createState() => _WalkingLoaderState();
}

class _WalkingLoaderState extends State<WalkingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _slideAnim = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationHeight = widget.compact ? 132.0 : 200.0;
    final titleSize = widget.compact ? 24.0 : 32.0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: animationHeight,
          child: Lottie.asset(
            'assets/animations/walking.json',
            repeat: true,
            animate: true,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _slideAnim,
          builder: (_, __) {
            final t = _slideAnim.value;
            return ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment(t, 0),
                  end: Alignment(t + 2, 0),
                  tileMode: TileMode.mirror,
                  colors: const [
                    Color(0xFF3AFF8C),
                    Color(0xFF1DB954),
                    Color(0xFF0D4C23),
                    Color(0xFF1DB954),
                    Color(0xFF3AFF8C),
                  ],
                ).createShader(rect);
              },
              blendMode: BlendMode.srcATop,
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );

    if (widget.center) {
      return Center(child: content);
    }
    return content;
  }
}

class WalkingLoadingScreen extends StatelessWidget {
  const WalkingLoadingScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = AppColors.primary,
    this.secondaryAccent = AppColors.accent,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Color secondaryAccent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: AtmosphereBackground(
            accent: accent,
            secondaryAccent: secondaryAccent,
            child: const SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: WalkingLoader(
              title: title,
              subtitle: subtitle,
            ),
          ),
        ),
      ],
    );
  }
}

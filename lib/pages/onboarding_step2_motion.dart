import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../ui/widgets/primary_button.dart';

class OnboardingMotion extends StatefulWidget {
  const OnboardingMotion({super.key});

  @override
  State<OnboardingMotion> createState() => _OnboardingMotionState();
}

class _OnboardingMotionState extends State<OnboardingMotion>
    with TickerProviderStateMixin {
  bool _animate = false;

  late final AnimationController rippleController;
  late final Animation<double> rippleT;
  late final Animation<double> rippleOpacity;

  late final AnimationController bounceController;
  late final Animation<double> bounceScale;

  final GlobalKey _syncKey = GlobalKey();
  final GlobalKey _paintKey = GlobalKey();

  Offset _syncCenter = Offset.zero;
  bool _centerUpdateScheduled = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _animate = true);
    });

    bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(bounceController);

    rippleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            rippleController.forward(from: 0);
            bounceController.forward(from: 0);
          }
        });

    rippleT = CurvedAnimation(
      parent: rippleController,
      curve: Curves.easeOutCubic,
    );

    rippleOpacity = Tween<double>(
      begin: 0.50,
      end: 0.0,
    ).animate(CurvedAnimation(parent: rippleController, curve: Curves.easeOut));

    bounceController.addListener(_scheduleCenterUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSyncCenter();
      rippleController.forward(from: 0);
      bounceController.forward(from: 0);
    });
  }

  void _scheduleCenterUpdate() {
    if (_centerUpdateScheduled) return;
    _centerUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerUpdateScheduled = false;
      _updateSyncCenter();
    });
  }

  void _updateSyncCenter() {
    if (!mounted) return;

    final syncObj = _syncKey.currentContext?.findRenderObject();
    final paintObj = _paintKey.currentContext?.findRenderObject();

    if (syncObj is! RenderParagraph || paintObj is! RenderBox) return;

    final boxes = syncObj.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 4),
      boxHeightStyle: ui.BoxHeightStyle.tight,
      boxWidthStyle: ui.BoxWidthStyle.tight,
    );

    if (boxes.isEmpty) return;

    Rect rect = boxes.first.toRect();
    for (var i = 1; i < boxes.length; i++) {
      rect = rect.expandToInclude(boxes[i].toRect());
    }

    final localGlyphCenter = rect.center.translate(0, 0);

    final globalPoint = syncObj.localToGlobal(localGlyphCenter);
    final centerInPaint = paintObj.globalToLocal(globalPoint);

    if (centerInPaint != _syncCenter) {
      setState(() => _syncCenter = centerInPaint);
    }
  }

  @override
  void dispose() {
    bounceController.removeListener(_scheduleCenterUpdate);
    rippleController.dispose();
    bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: _paintKey,
                    painter: AnimatedRipplePainter(
                      t: rippleT,
                      opacity: rippleOpacity,
                      center: _syncCenter,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSlide(
                          offset: _animate ? Offset.zero : const Offset(0, 0.2),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: _animate ? 1 : 0,
                            child: Column(
                              children: [
                                const Text(
                                  "Let's",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedBuilder(
                                  animation: bounceController,
                                  builder: (_, __) {
                                    return Transform.scale(
                                      scale: bounceScale.value,
                                      child: Text(
                                        "sync",
                                        key: _syncKey,
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "your steps.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimatedSlide(
                          offset: _animate ? Offset.zero : const Offset(0, 0.3),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _animate ? 1 : 0,
                            duration: const Duration(milliseconds: 700),
                            child: const Text(
                              "We'll use motion sensors to track your walking rhythm (steps per minute).",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: _animate ? 1 : 0.8),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: PrimaryButton(
                            text: "Allow Motion Access",
                            onPressed: () => context.push('/pace'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: _animate ? 1 : 0.8),
                          duration: const Duration(milliseconds: 550),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: PrimaryButton(
                            text: "Skip for now",
                            color: const Color(0xFF3A3A3A),
                            onPressed: () => context.push('/pace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AnimatedRipplePainter extends CustomPainter {
  final Animation<double> t;
  final Animation<double> opacity;
  final Offset center;

  AnimatedRipplePainter({
    required this.t,
    required this.opacity,
    required this.center,
  }) : super(repaint: Listenable.merge([t, opacity]));

  @override
  void paint(Canvas canvas, Size size) {
    if (center == Offset.zero) return;

    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    double maxDist = 0;
    for (final c in corners) {
      maxDist = math.max(maxDist, (c - center).distance);
    }

    final radius = (maxDist * 1.10) * t.value;

    final o = opacity.value.clamp(0.0, 1.0);
    final fogAlpha = (o * 0.35).clamp(0.0, 1.0);

    final fog = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10)
      ..color = Colors.greenAccent.withValues(alpha: fogAlpha);

    final crisp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..isAntiAlias = true
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3)
      ..color = Colors.greenAccent.withValues(alpha: o);

    canvas.drawCircle(center, radius, fog);
    canvas.drawCircle(center, radius, crisp);
  }

  @override
  bool shouldRepaint(covariant AnimatedRipplePainter old) {
    return old.center != center;
  }
}

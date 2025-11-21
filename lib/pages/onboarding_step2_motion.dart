import 'package:flutter/material.dart';
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

  late AnimationController rippleController;
  late Animation<double> rippleRadius;
  late Animation<double> rippleOpacity;

  late AnimationController bounceController;
  late Animation<double> bounceScale;

  final GlobalKey _syncKey = GlobalKey();
  Offset _syncCenter = Offset.zero;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 150), () {
      setState(() => _animate = true);
    });

    rippleController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1600),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            rippleController.forward(from: 0);
            bounceController.forward(from: 0);
          }
        });

    rippleRadius = Tween<double>(begin: 0, end: 900).animate(
      CurvedAnimation(parent: rippleController, curve: Curves.easeOutCubic),
    );

    rippleOpacity = Tween<double>(
      begin: 0.55,
      end: 0,
    ).animate(CurvedAnimation(parent: rippleController, curve: Curves.easeOut));

    rippleController.forward();

    bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    bounceScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(bounceController);

    bounceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateSyncPosition();
    });
  }

  void _calculateSyncPosition() {
    final renderBox = _syncKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      setState(() {
        _syncCenter = Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
      });
    }
  }

  @override
  void dispose() {
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: rippleController,
                builder: (_, __) {
                  return CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: SingleRipplePainter(
                      radius: rippleRadius.value,
                      opacity: rippleOpacity.value,
                      center: _syncCenter,
                    ),
                  );
                },
              ),

              Column(
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
                            "Let’s",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 6),

                          AnimatedBuilder(
                            animation: bounceController,
                            builder: (_, __) {
                              return Transform.scale(
                                scale: bounceScale.value,
                                child: Container(
                                  key: _syncKey,
                                  child: const Text(
                                    "sync",
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            "your steps.",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
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
                        "We’ll use motion sensors to track your walking rhythm (steps per minute).",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.white70),
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
            ],
          ),
        ),
      ),
    );
  }
}

class SingleRipplePainter extends CustomPainter {
  final double radius;
  final double opacity;
  final Offset center;

  SingleRipplePainter({
    required this.radius,
    required this.opacity,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.greenAccent.withOpacity(opacity);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant SingleRipplePainter old) {
    return old.radius != radius ||
        old.opacity != opacity ||
        old.center != center;
  }
}

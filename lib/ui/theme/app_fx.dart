import 'dart:ui';

import 'package:flutter/material.dart';

import 'colors.dart';

class AppFx {
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B120E), Color(0xFF040505)],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xCC18211D), Color(0xB3101413)],
  );

  static const LinearGradient raisedPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xE0212B26), Color(0xC0131716)],
  );

  static List<BoxShadow> softGlow(Color color, {double strength = 0.26}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: strength),
        blurRadius: 28,
        spreadRadius: -8,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: AppColors.shadowDark.withValues(alpha: 0.28),
        blurRadius: 34,
        spreadRadius: -14,
        offset: const Offset(0, 18),
      ),
    ];
  }

  static BoxDecoration glassDecoration({
    double radius = 24,
    Gradient? gradient,
    Color? glowColor,
    bool elevated = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: gradient ?? (elevated ? raisedPanelGradient : panelGradient),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      boxShadow: [
        ...softGlow(
          glowColor ?? AppColors.primary,
          strength: elevated ? 0.18 : 0.1,
        ),
        const BoxShadow(
          color: Color(0x66000000),
          blurRadius: 26,
          spreadRadius: -14,
          offset: Offset(0, 18),
        ),
      ],
    );
  }
}

class AtmosphereBackground extends StatelessWidget {
  const AtmosphereBackground({
    super.key,
    required this.child,
    this.accent = AppColors.primary,
    this.secondaryAccent = AppColors.cinemaRed,
  });

  final Widget child;
  final Color accent;
  final Color secondaryAccent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppFx.pageGradient),
        ),
        Positioned(
          top: -90,
          left: -30,
          child: _GlowOrb(size: 220, color: accent.withValues(alpha: 0.22)),
        ),
        Positioned(
          top: 140,
          right: -70,
          child: _GlowOrb(
            size: 240,
            color: secondaryAccent.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -120,
          left: 40,
          child: _GlowOrb(
            size: 280,
            color: AppColors.primaryBright.withValues(alpha: 0.10),
          ),
        ),
        child,
      ],
    );
  }
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 24,
    this.gradient,
    this.glowColor,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Gradient? gradient;
  final Color? glowColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: AppFx.glassDecoration(
            radius: radius,
            gradient: gradient,
            glowColor: glowColor,
            elevated: elevated,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

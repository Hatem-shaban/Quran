import 'package:flutter/material.dart';

/// انتقال أفقي (Slide) — للانتقال بين الشاشات الرئيسية.
class SlideRoute<T> extends PageRouteBuilder<T> {
  SlideRoute({required Widget page})
      : super(
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.3, 0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
}

/// انتقال⏫ أنيق للصفحات (Scale + Fade) — لشاشة القراءة.
class ScaleFadeRoute<T> extends PageRouteBuilder<T> {
  ScaleFadeRoute({required Widget page})
      : super(
          pageBuilder: (_, _, _) => page,
          transitionsBuilder: (_, animation, _, child) {
            final fade = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut));
            final scale = Tween(begin: 0.95, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: animation.drive(fade),
              child: ScaleTransition(
                scale: animation.drive(scale),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}

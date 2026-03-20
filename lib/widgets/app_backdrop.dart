import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppBackdrop({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF09101A), Color(0xFF101824), Color(0xFF161F2B)],
            ),
          ),
        ),
        const Positioned(
          top: -120,
          right: -80,
          child: _GlowOrb(size: 260, color: Color(0x66FF8C24)),
        ),
        const Positioned(
          top: 180,
          left: -100,
          child: _GlowOrb(size: 220, color: Color(0x3317E7B1)),
        ),
        Positioned.fill(
          child: SafeArea(
            top: false,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.6,
              spreadRadius: size * 0.12,
            ),
          ],
        ),
      ),
    );
  }
}

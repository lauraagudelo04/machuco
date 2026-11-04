import 'package:flutter/material.dart';
import 'package:machuco/models/payment_method/payment_method_model.dart';

/// Logo de una red de tarjetas dibujado con widgets (sin assets externos).
/// Los colores son los de cada marca, por eso no salen del design system.
class CardNetworkLogo extends StatelessWidget {
  const CardNetworkLogo({super.key, required this.network, this.height = 36});

  final CardNetwork network;
  final double height;

  static const _mastercardRed = Color(0xFFEB001B);
  static const _mastercardOrange = Color(0xFFF79E1B);
  static const _mastercardOverlap = Color(0xFFFF5F00);
  static const _amexBlue = Color(0xFF006FCF);
  static const _discoverOrange = Color(0xFFFF6000);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: switch (network) {
      CardNetwork.visa => _visa(),
      CardNetwork.mastercard => _mastercard(),
      CardNetwork.amex => _amex(),
      CardNetwork.discover => _discover(),
      CardNetwork.unknown => const SizedBox.shrink(),
    },
  );

  Widget _visa() => Center(
    child: Text(
      'VISA',
      style: TextStyle(
        color: Colors.white,
        fontSize: height * 0.85,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -1,
        height: 1,
      ),
    ),
  );

  Widget _mastercard() => AspectRatio(
    aspectRatio: 1.6,
    child: CustomPaint(painter: _MastercardPainter()),
  );

  Widget _amex() => Center(
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.25,
        vertical: height * 0.12,
      ),
      decoration: BoxDecoration(
        color: _amexBlue,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        'AMEX',
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.42,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          height: 1,
        ),
      ),
    ),
  );

  Widget _discover() => Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DISCOVER',
          style: TextStyle(
            color: Colors.white,
            fontSize: height * 0.38,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        SizedBox(width: height * 0.12),
        Container(
          width: height * 0.5,
          height: height * 0.5,
          decoration: const BoxDecoration(
            color: _discoverOrange,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final leftCenter = Offset(size.width / 2 - radius * 0.55, radius);
    final rightCenter = Offset(size.width / 2 + radius * 0.55, radius);

    canvas.drawCircle(
      leftCenter,
      radius,
      Paint()..color = CardNetworkLogo._mastercardRed,
    );
    canvas.drawCircle(
      rightCenter,
      radius,
      Paint()..color = CardNetworkLogo._mastercardOrange,
    );

    final overlap = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: leftCenter, radius: radius)),
      Path()..addOval(Rect.fromCircle(center: rightCenter, radius: radius)),
    );
    canvas.drawPath(
      overlap,
      Paint()..color = CardNetworkLogo._mastercardOverlap,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

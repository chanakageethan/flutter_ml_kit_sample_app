import 'package:flutter/material.dart';


class CenterOvalOverlay extends StatelessWidget {
  final bool isActive; // true = green, false = white

  const CenterOvalOverlay({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Center(
        child: Container(
          width: size.width * 0.7,
          height: size.height * 0.5,
          decoration: ShapeDecoration(
            shape: OvalBorder(
              side: BorderSide(
                color: isActive ? Colors.green : Colors.white,
                width: 3,
              ),
            )
          ),
        ),
      ),
    );
  }
}

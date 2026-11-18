import 'package:flutter/material.dart';

/// Official Keep app artwork, used only to identify this integration.
class KeepIcon extends StatelessWidget {
  const KeepIcon({super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset(
      'assets/integrations/keep.jpg',
      width: 36,
      height: 36,
      semanticLabel: 'Keep',
      fit: BoxFit.cover,
    ),
  );
}

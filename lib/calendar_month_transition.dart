import 'package:flutter/material.dart';

/// Keeps at most one outgoing grid, even when months change in quick succession.
class CalendarMonthTransition extends StatefulWidget {
  final DateTime month;
  final Widget child;
  const CalendarMonthTransition({
    super.key,
    required this.month,
    required this.child,
  });
  @override
  State<CalendarMonthTransition> createState() =>
      _CalendarMonthTransitionState();
}

class _CalendarMonthTransitionState extends State<CalendarMonthTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && outgoing != null && mounted) {
        setState(() => outgoing = null);
      }
    });
  }

  Widget? outgoing;
  double direction = 1;
  int monthIndex(DateTime d) => d.year * 12 + d.month;

  @override
  void didUpdateWidget(covariant CalendarMonthTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final change = monthIndex(widget.month) - monthIndex(oldWidget.month);
    if (change == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      outgoing = null;
      controller.value = 1;
      return;
    }
    outgoing = oldWidget.child;
    direction = change.sign.toDouble();
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (outgoing == null || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final progress = Curves.easeOutCubic.transform(controller.value);
          return Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 1 - progress,
                      child: FractionalTranslation(
                        translation: Offset(-direction * .16 * progress, 0),
                        child: outgoing,
                      ),
                    ),
                  ),
                ),
              ),
              Opacity(
                opacity: progress,
                child: FractionalTranslation(
                  translation: Offset(direction * .16 * (1 - progress), 0),
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

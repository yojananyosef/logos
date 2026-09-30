import 'package:flutter/material.dart';

import '../theme/logos_colors.dart';
import '../theme/logos_spacing.dart';
import '../theme/logos_theme.dart';

/// A progress indicator that reaches a resting state.
///
/// Flutter's `CircularProgressIndicator` is an infinite animation: it never settles, so
/// anything driving frames — a `ListenableBuilder` rebuilt on every keystroke, a
/// `pumpAndSettle` in a test — keeps pumping forever. In a search field that is rebuilt per
/// character, that is a real cost rather than a test artefact: the spinner schedules a frame
/// continuously for as long as the field is empty.
///
/// This one animates a fixed sweep and then stops. The work being waited on is a SQLite
/// read that finishes in milliseconds, so an indicator that stops when the read does is
/// both cheaper and more honest — a spinner that keeps spinning after the answer arrived
/// says the work is still running.
///
/// [label] is optional and shown beneath, for the case where the wait is genuinely
/// uncertain.
class WorkingIndicator extends StatefulWidget {
  const WorkingIndicator({super.key, this.label});

  final String? label;

  @override
  State<WorkingIndicator> createState() => _WorkingIndicatorState();
}

class _WorkingIndicatorState extends State<WorkingIndicator>
    with SingleTickerProviderStateMixin {
  /// Long enough to be visible, short enough not to outlive the read it stands for.
  static const _sweep = Duration(milliseconds: 900);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _sweep,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: RotationTransition(
              turns: _controller,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                // The value is driven by the controller above, so the arc completes and
                // stops instead of looping.
                value: 1,
                valueColor: AlwaysStoppedAnimation(LogosColors.primary),
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: LogosSpacing.sm),
            Text(
              widget.label!,
              style: LogosTypography.body.copyWith(
                color: LogosColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

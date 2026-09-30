import 'package:flutter/material.dart';

import '../theme/logos_colors.dart';
import '../theme/logos_theme.dart';

/// A sidebar destination row.
///
/// Carries the full visual contract from the reference: active background, hover,
/// a 44dp minimum target on touch, and a label that stays in the semantics tree even
/// when the sidebar is collapsed to icons.
class NavItem extends StatefulWidget {
  const NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.collapsed = false,
    this.badge,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  /// Icon-only. The label is still exposed to assistive technology.
  final bool collapsed;
  final Widget? badge;

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.active
        ? LogosColors.primary
        : (_hovered ? LogosColors.primary : LogosColors.textPrimary);

    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: LogosColors.minTouchTarget),
      color: widget.active
          ? LogosColors.surfaceHover
          : (_hovered ? LogosColors.surfaceHover : Colors.transparent),
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 0 : LogosSpacing.md,
      ),
      child: Row(
        mainAxisAlignment:
            widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 20, color: fg),
          if (!widget.collapsed) ...[
            const SizedBox(width: LogosSpacing.md),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LogosTypography.navItem.copyWith(
                  color: fg,
                  fontWeight:
                      widget.active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
          if (widget.badge != null && !widget.collapsed) widget.badge!,
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.collapsed ? widget.label : null,
      excludeSemantics: widget.collapsed,
      child: Tooltip(
        message: widget.collapsed ? widget.label : '',
        waitDuration: const Duration(milliseconds: 500),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: widget.onTap,
            focusColor: LogosColors.linkHover.withOpacity(0.16),
            hoverColor: Colors.transparent,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A toolbar section. Active state is the 2dp primary underline from the reference.
class ToolbarSection extends StatelessWidget {
  const ToolbarSection({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: LogosColors.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.md),
          decoration: BoxDecoration(
            color: active ? LogosColors.surfaceHover : LogosColors.surface,
            border: Border(
              bottom: BorderSide(
                color: active ? LogosColors.primary : Colors.transparent,
                width: LogosMetrics.activeIndicatorHeight,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: LogosTypography.navItem.copyWith(
              color: active ? LogosColors.primary : LogosColors.textPrimary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

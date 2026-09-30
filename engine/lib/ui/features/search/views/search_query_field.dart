import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../view_models/search_view_model.dart';

/// The query field.
///
/// Owns a [TextEditingController] so the visible text and the ViewModel's query cannot
/// drift apart. That is not a stylistic preference: the ViewModel notifies on every
/// keystroke, the widget rebuilds each time, and a `TextField` with no controller restores
/// its text from its own state on rebuild. Any rebuild during an in-flight search — which
/// is every search — could therefore drop or restore characters the user had typed.
///
/// The controller is synchronised from the ViewModel, not the other way round, so the
/// ViewModel remains the single source of truth and can be tested with no widget at all.
class SearchQueryField extends StatefulWidget {
  const SearchQueryField({super.key, required this.viewModel});

  final SearchViewModel viewModel;

  @override
  State<SearchQueryField> createState() => _SearchQueryFieldState();
}

class _SearchQueryFieldState extends State<SearchQueryField> {
  late final SearchViewModel _vm = widget.viewModel;
  late final TextEditingController _controller = TextEditingController(text: _vm.query);

  @override
  void initState() {
    super.initState();
    _vm.addListener(_syncFromViewModel);
  }

  @override
  void didUpdateWidget(SearchQueryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != _vm) {
      oldWidget.viewModel.removeListener(_syncFromViewModel);
      _vm.addListener(_syncFromViewModel);
      _controller.text = _vm.query;
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_syncFromViewModel);
    _controller.dispose();
    super.dispose();
  }

  /// Applies a change the ViewModel made, such as an example inserted from the help panel.
  ///
  /// The selection is placed at the end so the caret does not jump to the start of a
  /// freshly inserted query, which would be jarring when running an example.
  void _syncFromViewModel() {
    if (_controller.text == _vm.query) return;
    _controller.value = TextEditingValue(
      text: _vm.query,
      selection: TextSelection.collapsed(offset: _vm.query.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LogosSpacing.sm),
      child: ConstrainedReading(
        maxWidth: 900,
        child: TextField(
          controller: _controller,
          onChanged: _vm.setQuery,
          style: LogosTypography.body,
          textInputAction: TextInputAction.search,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar',
            hintStyle: LogosTypography.body.copyWith(color: LogosColors.textDisabled),
            prefixIcon: const Icon(Icons.search, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: LogosColors.borderStrong),
              borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
            ),
          ),
        ),
      ),
    );
  }
}

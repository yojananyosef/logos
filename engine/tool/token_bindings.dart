// The design-token contract: which CSS custom property backs each Dart constant.
//
// This is the single place a value is bound to its source. The generator resolves
// each name here against `docs/research/design-tokens.json` and fails if one is
// missing, so a rename upstream breaks the build instead of silently changing the
// theme.
//
// Binding by token *name* rather than by value is deliberate: 56 tokens share the
// primary value and 177 share white, so a value search would pick whatever component
// happened to be captured and would couple the brand colour to it.
library;

/// Colours resolved from a captured custom property.
///
/// Grouped by the surface the token belongs to, because that is how the reference
/// application itself is organised.
const colorBindings = <String, String>{
  // --- brand ---
  // #154ac9. Backs the active toolbar icon, the generic-tab active border, the app
  // banner and the info notification icon, so it is the accent, not a surface.
  'primary': 'app-toolbar-button-active-icon-color',

  // #030b60. The subscriber-edition badge, i.e. the deepest brand tone.
  'navy': 'app-edition-badge-subscriber-background-color',

  // #ff6600. The active panel tab border. This is orange, not the brand blue: the
  // reference marks the open tab with a warm accent. A hand-written theme
  // reasonably gets this wrong, which is why the value is machine-transcribed.
  'tabActiveAccent': 'panel-tab-active-border-color',

  // --- links ---
  'link': 'link-color',
  'linkHover': 'link-hover-color',
  'linkDisabled': 'link-disabled-color',

  // --- focus ---
  // The reference declares an explicit focus ring rather than relying on the platform
  // default, which is easy to lose on a sunken toolbar surface.
  'focusRing': 'sidebar-menu-item-active-focus-outline-color',
  'linkFocusRing': 'link-focus-outline-color',

  // --- text ---
  // The toolbar's own text colour, which is the application's body ink.
  'textPrimary': 'app-toolbar-text-color',
  'textSecondary': 'app-toolbar-icon-color',
  'textTertiary': 'button-borderless-icon-color',
  'textMuted': 'app-toolbar-button-decorator-icon-color',
  'textDisabled': 'button-badge-count-background-color',
  'textInverted': 'app-toolbar-button-active-background-color',
  'textBrand': 'ui-font-color',
  'textBrandLight': 'ui-font-color-light',
  'textBrandMedium': 'ui-font-color-medium',

  // --- surfaces ---
  'surface': 'toolbar-background-color',
  'surfaceSunken': 'toolbar-separator-color',
  'surfaceHover': 'item-filled-background-color',
  'surfacePressed': 'app-toolbar-button-background-color',
  'surfaceInverted': 'app-edition-badge-free-edition-background-color',

  // --- borders ---
  'border': 'border-color',
  'borderStrong': 'border-color-heavy',
  'tabCloseIcon': 'panel-tab-close-button-color',
  'tabCloseIconHover': 'panel-tab-close-button-hover-color',

  // --- status ---
  'danger': 'icon-alert-color',
  'dangerSurface': 'notification-bar-error-background-color',
  'warningSurface': 'bar-alert-background-color',
  'warningIcon': 'bar-alert-icon-color',
  'warningLink': 'bar-alert-link-color',
  'infoSurface': 'notification-bar-info-background-color',
  'infoIcon': 'notification-bar-info-icon-color',
  'success': 'icon-biblical-places-natural-feature-color',

  // --- scripture accents ---
  // The link and selection colours used inside a document, which deliberately differ
  // from the chrome link colour: on a reading surface a saturated blue competes with
  // the text.
  'documentLink': 'text-alignment-document-primary-link-color',
  'documentLinkMuted': 'text-alignment-document-secondary-link-color',
  'documentSelected': 'text-alignment-document-primary-selected-color',
  'documentNotePrivate': 'text-alignment-document-note-private-indicator-color',
  'documentNotePublic': 'text-alignment-document-note-public-indicator-color',
  'segmentExcused': 'text-alignment-document-segment-excused-color',
  'segmentApproved': 'text-alignment-document-segment-approved-color',
  'textBoxBackground': 'text-box-background-color',
  'redLetters': 'red-letters-font-color',
  'searchHit': 'search-hit-font-color',
};

/// Lengths resolved from a captured custom property written as `Npx`.
///
/// A token whose value is not a single `Npx` length is a build error rather than a
/// silent zero: `sidebar-border-width` is `0 1px 0 0` and has no single-number
/// meaning, so it must not be bound to a `double`.
const dimensionBindings = <String, String>{
  'borderRadiusButton': 'button-border-radius',
  'borderRadiusCard': 'card-stock-border-radius',
  'focusRingWidth': 'sidebar-menu-item-active-focus-outline-width',
  'sidebarBorderRightWidth': 'sidebar-border-right-width',
  'tabActiveBorderTopWidth': 'generic-tab-active-border-top-width',
};

/// Measurements taken from the rendered DOM, not from a custom property.
///
/// These are separated from [dimensionBindings] and from [colorBindings] because the
/// reference application hardcodes them in CSS and never exposes them as tokens.
/// Presenting them alongside token-derived values would imply a provenance they do not
/// have, and would let a future reader assume a re-capture would update them.
///
/// Each value records where it came from, so it can be re-measured rather than
/// trusted indefinitely.
const measuredMetrics = <String, MeasuredMetric>{
  'iconRailWidth': MeasuredMetric(
    value: 48,
    source: 'computed style of the left icon rail element',
    note: 'Confirmed in the capture as an exact 48px column.',
  ),
  'sidebarExpandedWidth': MeasuredMetric(
    value: 207,
    source: 'computed style of the expanded left sidebar',
    note: 'The reference keeps this width at every viewport, which is why it '
        'overflows below 600px. The clone collapses it instead.',
  ),
  'sidebarCollapsedWidth': MeasuredMetric(
    value: 56,
    source: 'computed style of the collapsed left sidebar',
    note: '',
  ),
  'sidebarDividerWidth': MeasuredMetric(
    value: 1,
    source: 'sidebar-border-right-width token',
    note: 'This one does have a token; it is listed here only because it is a '
        'chrome metric rather than a component style.',
  ),
  'activeIndicatorHeight': MeasuredMetric(
    value: 2,
    source: 'computed border of the active toolbar section',
    note: 'The reference uses two different indicators: a 3px top border on a '
        'generic tab and a 1px right border on a panel tab. The toolbar section '
        'marker matches the 2px sidebar active-item outline, so 2 is used for the '
        'toolbar and the token-derived 3px for tabs.',
  ),
  'minTouchTarget': MeasuredMetric(
    value: 44,
    source: 'platform accessibility guidance',
    note: 'Not a Logos value. The reference ships a desktop-only layout and never '
        'declares one, so the clone has to choose.',
  ),
  'maxReadingMeasure': MeasuredMetric(
    value: 720,
    source: 'typographic convention',
    note: 'Not a Logos value. The reference stretches text to the full pane width.',
  ),
};

class MeasuredMetric {
  const MeasuredMetric({
    required this.value,
    required this.source,
    required this.note,
  });

  final double value;
  final String source;
  final String note;
}

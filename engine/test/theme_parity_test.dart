import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logos_engine/ui/core/theme/logos_colors.dart';
import 'package:logos_engine/ui/core/theme/logos_spacing.dart';
import 'package:logos_engine/ui/core/theme/logos_theme.dart';

import '../tool/theme_renderer.dart';
import '../tool/theme_resolver.dart';

/// The generated theme must stay equal to its source.
///
/// The file is generated rather than hand-written, but a generator is only worth having
/// if something fails when its output is edited. Without this, someone can change
/// `LogosColors.primary` in place, the app shifts colour, and nothing reports it —
/// which is the exact failure mode the generator exists to prevent.
void main() {
  group('theme parity', () {
    final resolved = resolveTheme('../docs/research/design-tokens.json');

    test('every bound token exists in the captured reference', () {
      // An absent token means the reference renamed it. Failing here is deliberate: the
      // fix is to re-derive the binding, never to drop the colour, because a silently
      // missing colour is how a clone diverges without anyone noticing.
      expect(
        resolved.missing,
        isEmpty,
        reason: 'unresolved bindings:\n${resolved.missing.join('\n')}',
      );
    });

    test('the committed file matches what the generator produces', () {
      // Renders through the same code path the generator uses, so the two cannot
      // diverge. Shelling out to the generator and re-reading the file it had just
      // checked would have been circular.
      final fresh = renderTheme(resolveTheme('../docs/research/design-tokens.json'));
      final committed = File('lib/ui/core/theme/logos_colors.dart').readAsStringSync();

      expect(
        committed,
        fresh,
        reason: 'lib/ui/core/theme/logos_colors.dart has drifted from '
            '../docs/research/design-tokens.json. '
            'Run: dart run tool/generate_theme.dart',
      );
    });

    test('the reference exposes the tokens the bindings assume', () {
      // Guards against a re-capture that silently captures fewer custom properties,
      // which would make the resolver return fewer colours and the parity test pass
      // on an incomplete theme.
      expect(resolved.tokens.length, greaterThan(1800));
    });
  });

  group('values transcribed from the reference', () {
    // Each of these is a specific finding from reading the captured tokens. They are
    // asserted individually so a regression names the value that broke, instead of
    // failing an opaque "file differs" comparison.

    test('the active panel tab accent is orange, not the brand blue', () {
      // `panel-tab-active-border-color` is #ff6600. Reading the theme by eye
      // naturally reaches for the primary blue, and the result looks plausible while
      // being wrong.
      expect(LogosColors.tabActiveAccent, const Color(0xFFFF6600));
      expect(
        LogosColors.tabActiveAccent,
        isNot(LogosColors.primary),
        reason: 'the open tab uses a warm accent, distinct from the brand blue',
      );
    });

    test('the brand palette matches the reference', () {
      expect(LogosColors.primary, const Color(0xFF154AC9));
      expect(LogosColors.navy, const Color(0xFF030B60));
    });

    test('link colours match the reference', () {
      expect(LogosColors.link, const Color(0xFF1E6AFE));
      expect(LogosColors.linkHover, const Color(0xFF4797FF));
      // The disabled link keeps the same hue at reduced alpha, which is what the
      // token `link-disabled-color` = #1e6afe80 encodes.
      // The token is CSS `#1e6afe80` (RRGGBBAA); `Color(0x...)` takes AARRGGBB.
      expect(LogosColors.linkDisabled, const Color(0x801E6AFE));
    });

    test('the body ink is the toolbar text colour', () {
      expect(LogosColors.textPrimary, const Color(0xFF333333));
    });

    test('document link colours differ from the chrome link colour', () {
      // Inside a reading surface a saturated blue competes with the text, so the
      // reference uses a pale tint there. Conflating the two makes scripture look
      // like a web page.
      expect(LogosColors.documentLink, const Color(0xFF8BC5FF));
      expect(LogosColors.documentLink, isNot(LogosColors.link));
    });

    test('the warning surface and its icon are distinct', () {
      expect(LogosColors.warningSurface, const Color(0xFFFFF4D5));
      expect(LogosColors.warningIcon, const Color(0xFFDBA910));
    });

    test('alpha-bearing tokens keep their alpha', () {
      // The normaliser must not truncate an 8-digit hex to 6, which would silently
      // promote a translucent colour to opaque — the disabled link would then be
      // indistinguishable from the active one on the surfaces it was measured on.
      // The token is CSS `#1e6afe80` (RRGGBBAA); `Color(0x...)` takes AARRGGBB.
      expect(LogosColors.linkDisabled, const Color(0x801E6AFE));
      expect(LogosColors.link, const Color(0xFF1E6AFE));
      expect(LogosColors.linkDisabled, isNot(LogosColors.link));
    });
  });

  group('measured metrics', () {
    test('the rail is 48 and the sidebar 207, as captured', () {
      expect(LogosMeasured.iconRailWidth, 48);
      expect(LogosMeasured.sidebarExpandedWidth, 207);
    });

    test('the touch target is the accessibility minimum, not a Logos value', () {
      // Recorded explicitly because the reference never declares one: it ships a
      // desktop-only layout. The clone is adaptive, so it has to choose, and the
      // choice is recorded rather than implied.
      expect(LogosMeasured.minTouchTarget, greaterThanOrEqualTo(44));
    });
  });

  group('typography', () {
    test('the family is the bundled one', () {
      expect(LogosTypeScale.family, 'SourceSansPro');
      expect(LogosTypography.family, LogosTypeScale.family);
    });

    test('every declared font file is present and is a real font', () {
      // A pubspec entry pointing at a missing asset fails only at runtime, on the
      // platform that needs it, and then as invisible fallback text. Checking the
      // files here turns that into a build failure.
      const pubspec = 'pubspec.yaml';
      final declared = File(pubspec)
          .readAsLinesSync()
          .where((l) => l.contains('asset: assets/fonts/'))
          .map((l) => l.split('asset:').last.trim())
          .toList();

      expect(declared, isNotEmpty, reason: 'no fonts declared in $pubspec');

      for (final path in declared) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path is declared but missing');
        // A TTF starts with 0x00010000; an OTF with 0x4F54544F. A 14-byte 404 page
        // would pass an existence check and fail only once the font engine met it.
        final head = f.readAsBytesSync().sublist(0, 4);
        // sfnt version tags: 0x00010000 (TrueType), 'OTTO' (CFF), 'true' (Apple).
        final signature = (head[0] << 24) | (head[1] << 16) | (head[2] << 8) | head[3];
        expect(
          signature,
          anyOf(0x00010000, 0x4F54544F, 0x74727565),
          reason: '$path is not a TrueType or OpenType file',
        );
      }
    });

    test('the font licence travels with the font', () {
      // SIL OFL 1.1 requires the licence to accompany the font files. Shipping the
      // font without it is a licence violation, not a documentation gap.
      expect(
        File('assets/fonts/OFL.txt').existsSync(),
        isTrue,
        reason: 'the OFL text must ship alongside the font files',
      );
    });

    test('the body style uses the reference size and leading', () {
      expect(LogosTypography.body.fontSize, 16);
      expect(LogosTypography.body.height, 1.5);
    });

    test('scripture is set looser than interface text', () {
      expect(
          LogosTypeScale.scriptureLineHeight, greaterThan(LogosTypeScale.bodyLineHeight));
      expect(LogosTypography.scripture(1.5).fontSize, 24);
    });
  });

  group('spacing', () {
    test('the scale is a strict 4dp lattice', () {
      // Not token-derived, and documented as a convention. Asserting the lattice
      // keeps that convention honest as surfaces are added.
      const steps = [
        LogosSpacing.xxs,
        LogosSpacing.xs,
        LogosSpacing.sm,
        LogosSpacing.md,
        LogosSpacing.lg,
        LogosSpacing.xl,
        LogosSpacing.xxl,
      ];
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]));
        expect(steps[i] % 4, 0, reason: '${steps[i]} is off the 4dp lattice');
      }
    });
  });
}

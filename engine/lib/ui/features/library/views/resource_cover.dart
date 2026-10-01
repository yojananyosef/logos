import 'package:flutter/material.dart';

import '../../../core/theme/logos_colors.dart';
import '../../../../domain/models/catalog.dart';
import '../../../../domain/models/library_query.dart';

/// A generated cover for a library resource.
///
/// **The catalog carries no cover art, and none exists in this repository.** The AMF
/// manifest has no image field and the catalog's eighteen entries have no URLs for one, so
/// there is nothing to display. Fabricating a plausible-looking illustration for each
/// resource would be inventing data; this renders the resource's own identity instead.
///
/// The shape is a book spine — a light board, a coloured spine down the left edge, and the
/// short name — because the reference's rows show a small cover thumbnail per resource and
/// a list without one reads as a list of links rather than a shelf.
///
/// Every colour here comes from the transcribed palette, and the text sits on a near-white
/// board rather than on the accent: the seven type colours have very different luminances
/// (`#919CAE` and `#154AC9` are more than four stops apart), so white-on-accent would pass
/// AA for some resource types and fail for others. One contrast-safe text colour for all
/// seven is the only arrangement that cannot regress. The accent is decoration, so it is
/// held to no contrast requirement.
class ResourceCover extends StatelessWidget {
  const ResourceCover({
    super.key,
    required this.resource,
    required this.size,
  });

  final ResourceDescriptor resource;

  /// The board's height. The width follows the 3:4 book proportion.
  final double size;

  /// The accent for a resource type, from the transcribed palette.
  ///
  /// Reused across types where the palette has no distinct value rather than tinted
  /// towards a colour it does not declare — the same rule the reader's `crema` scheme
  /// follows, and recorded the same way.
  static Color accentFor(ResourceType type) => switch (type) {
        ResourceType.bible => LogosColors.primary,
        ResourceType.commentary => LogosColors.navy,
        ResourceType.lexicon => LogosColors.link,
        ResourceType.dictionary => LogosColors.textSecondary,
        ResourceType.crossref => LogosColors.tabActiveAccent,
        ResourceType.devotion => LogosColors.textTertiary,
        ResourceType.words => LogosColors.success,
      };

  /// The label printed on the board.
  ///
  /// The short name where there is one, since a cover is read at a glance and `KJV` is
  /// recognisable at forty pixels where `King James Version` is not. Falls back to the
  /// title's initials, and to nothing at all if the resource has neither, rather than
  /// printing an empty board that looks like a failed image load.
  String get _label {
    final short = resource.shortName.trim();
    if (short.isNotEmpty && short.length <= 6) return short;

    final words = resourceTitle(resource)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentFor(resource.type);
    final width = size * 0.75;
    final label = _label;

    return Semantics(
      image: true,
      label: '${resourceTypeLabel(resource.type)}: ${resourceTitle(resource)}',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: size,
        decoration: BoxDecoration(
          color: LogosColors.surfaceHover,
          border: Border.all(color: LogosColors.border),
          borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // The spine. Its width is a fraction of the board so it stays a spine rather
            // than becoming a stripe, and it is what carries the type's identity.
            Container(width: width * 0.16, color: accent),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'SourceSansPro',
                      fontSize: size * 0.17,
                      fontWeight: FontWeight.w700,
                      // The board is `#F4F4F4`, so this is the palette's own body colour
                      // and clears AA by a wide margin at any size above ~11px.
                      color: LogosColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';

/// The four card types observed on the reference dashboard, kept distinct because
/// they have genuinely different shapes and calls to action.
enum DashboardCardKind { announcement, news, preOrder, serviceBanner }

class DashboardCardData {
  const DashboardCardData({
    required this.kind,
    required this.title,
    this.body,
    this.dateLabel,
    this.ctaLabel,
  });

  final DashboardCardKind kind;
  final String title;
  final String? body;
  final String? dateLabel;
  final String? ctaLabel;
}

/// The reference dashboard content, as data.
///
/// Kept separate from the widget so the card layout can be tested without a network
/// or an installed catalog, and so the same data could later come from a repository.
const dashboardCards = <DashboardCardData>[
  DashboardCardData(
    kind: DashboardCardKind.announcement,
    title: 'Descubre las actualizaciones',
    dateLabel: 'AGO. 2026',
    ctaLabel: 'Explorar las últimas novedades',
  ),
  DashboardCardData(
    kind: DashboardCardKind.news,
    title: '¿Qué hay de nuevo en Logos? Septiembre 2026',
    body: 'La versión 53 hace que la app móvil de Logos sea más fácil de navegar, '
        'lleva el Asistente de Estudio al paisaje y permite modificar un Plan de '
        'Lectura sin perder todo lo que ya habías hecho.',
  ),
  DashboardCardData(
    kind: DashboardCardKind.preOrder,
    title: 'CLIE Historia Esencial del Cristianismo',
    body: 'La Historia esencial del cristianismo ofrece lo que promete: lo esencial.',
    ctaLabel: 'Pre-orden ahora',
  ),
  DashboardCardData(
    kind: DashboardCardKind.preOrder,
    title: 'Polvo de la tierra: La singularidad del cuerpo humano',
    body: 'Con una lectura accesible pero no por ello poco profunda, el libro cumple '
        'con el propósito de proveer a cristianos que buscan un diálogo entre la ciencia y la fe.',
    ctaLabel: 'Pre-orden ahora',
  ),
  DashboardCardData(
    kind: DashboardCardKind.serviceBanner,
    title: 'Potencia tu estudio bíblico hoy',
    body: 'Autores Hispanos con hasta 50% de descuento.',
    ctaLabel: 'Ver descuentos',
  ),
];

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomScrollView(
      slivers: [
        SliverPadding(
          padding:
              EdgeInsets.fromLTRB(LogosSpacing.lg, LogosSpacing.lg, LogosSpacing.lg, 0),
          sliver: SliverToBoxAdapter(
            child: ConstrainedReading(
              maxWidth: 1200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Panel de inicio', style: LogosTypography.title),
                  SizedBox(height: LogosSpacing.lg),
                  _PromoBanner(),
                  SizedBox(height: LogosSpacing.xl),
                  Text('EXPLORAR', style: LogosTypography.sectionLabel),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(LogosSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: ConstrainedReading(
              maxWidth: 1200,
              child: _CardGrid(cards: dashboardCards),
            ),
          ),
        ),
        SliverPadding(
          padding:
              EdgeInsets.fromLTRB(LogosSpacing.lg, 0, LogosSpacing.lg, LogosSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: ConstrainedReading(
              maxWidth: 1200,
              child: _LibrarySection(),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LogosSpacing.lg, vertical: LogosSpacing.md),
      color: LogosColors.primary,
      // A row of message + CTA + close cannot fit a narrow window, so the banner
      // stacks rather than squeezing the message into a one-word-per-line column.
      // The decision comes from the available width, not from a device type.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final message = Text(
            'Potencia tu estudio biblico hoy: Autores Hispanos con hasta 50% de descuento',
            textAlign: TextAlign.center,
            style: LogosTypography.body
                .copyWith(color: LogosColors.surface, fontWeight: FontWeight.w600),
          );
          final cta = Container(
            color: LogosColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.sm,
            ),
            child: Text(
              'Ver descuentos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: LogosTypography.navItem.copyWith(color: LogosColors.textPrimary),
            ),
          );
          // An explicit 44x44 target rather than IconButton, whose built-in minimum
          // size is 48 and would overflow the parent Row at narrow widths.
          final close = Tooltip(
            message: 'Cerrar aviso',
            child: Semantics(
              button: true,
              label: 'Cerrar aviso',
              child: InkWell(
                onTap: () {},
                child: const SizedBox(
                  width: LogosMeasured.minTouchTarget,
                  height: LogosMeasured.minTouchTarget,
                  child: Icon(Icons.close, size: 16, color: LogosColors.surface),
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 420) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                message,
                const SizedBox(height: LogosSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: cta),
                    const SizedBox(width: LogosSpacing.sm),
                    close,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: LogosSpacing.md),
              Flexible(child: cta),
              close,
            ],
          );
        },
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});

  final List<DashboardCardData> cards;

  @override
  Widget build(BuildContext context) {
    final layoutClass = AdaptiveLayout.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The responsive skill's rule: decide from available space, not from a device
        // type. `LayoutClass.large` reports a null column count on purpose, meaning
        // "grow with the window" — so the count is computed here from the real width.
        final fixed = layoutClass.gridColumns;
        final columns = fixed ??
            ((constraints.maxWidth - LogosSpacing.md * 2) / 320).floor().clamp(3, 5);
        return Wrap(
          spacing: LogosSpacing.md,
          runSpacing: LogosSpacing.md,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth - LogosSpacing.md * (columns - 1)) / columns,
                child: _Card(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.data});

  final DashboardCardData data;

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = data.kind == DashboardCardKind.announcement;

    return Semantics(
      button: true,
      label: '${data.title}. ${data.ctaLabel ?? ''}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Container(
            constraints: const BoxConstraints(minHeight: 190),
            padding: const EdgeInsets.all(LogosSpacing.lg),
            decoration: isAnnouncement
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [LogosColors.navy, LogosColors.primary],
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAnnouncement && data.dateLabel != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: LogosSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: LogosColors.surface.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        data.dateLabel!,
                        style: LogosTypography.sectionLabel
                            .copyWith(color: LogosColors.surface),
                      ),
                    ),
                  ),
                if (data.kind == DashboardCardKind.preOrder)
                  const _Badge(
                      label: 'Pre-orden',
                      color: LogosColors.infoSurface,
                      fg: LogosColors.navy),
                const SizedBox(height: LogosSpacing.sm),
                Text(
                  data.title,
                  style: LogosTypography.title.copyWith(
                    color: isAnnouncement ? LogosColors.surface : LogosColors.textPrimary,
                  ),
                ),
                if (data.body != null) ...[
                  const SizedBox(height: LogosSpacing.sm),
                  Text(
                    data.body!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: LogosTypography.body.copyWith(
                      color: isAnnouncement
                          ? LogosColors.surface
                          : LogosColors.textSecondary,
                    ),
                  ),
                ],
                if (data.ctaLabel != null) ...[
                  const SizedBox(height: LogosSpacing.md),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            isAnnouncement ? LogosColors.surface : LogosColors.primary,
                        foregroundColor:
                            isAnnouncement ? LogosColors.primary : LogosColors.surface,
                      ),
                      child: Text(data.ctaLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.fg});

  final String label;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: LogosSpacing.sm, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        child: Text(label, style: LogosTypography.sectionLabel.copyWith(color: fg)),
      );
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('De su biblioteca', style: LogosTypography.title),
        const SizedBox(height: LogosSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(LogosSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La Palabra: El Mensaje de Dios para mí',
                        style: LogosTypography.title,
                      ),
                      const SizedBox(height: LogosSpacing.xs),
                      Text(
                        'Sociedad Bíblica de España',
                        style: LogosTypography.body
                            .copyWith(color: LogosColors.textSecondary),
                      ),
                      const SizedBox(height: LogosSpacing.md),
                      Text(
                        'No hay recursos instalados todavía. Instale un catálogo para '
                        'que esta sección muestre su biblioteca.',
                        style: LogosTypography.body
                            .copyWith(color: LogosColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LogosSpacing.lg),
                Container(
                  width: 96,
                  height: 132,
                  decoration: BoxDecoration(
                    color: LogosColors.surfaceSunken,
                    border: Border.all(color: LogosColors.border),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(Icons.menu_book_outlined,
                      color: LogosColors.textDisabled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

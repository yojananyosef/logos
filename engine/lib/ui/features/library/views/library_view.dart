import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../../core/theme/logos_colors.dart';
import '../../../core/theme/logos_spacing.dart';
import '../../../core/theme/logos_theme.dart';
import '../../../../data/repositories/library_repository.dart';
import '../../../../domain/models/catalog.dart';
import '../view_models/library_view_model.dart';

/// The library: what is installed, what can be installed, and what is not yet available.
///
/// Grouped by state rather than by resource type, because the user's question is not
/// "what bibles exist" but "what can I open right now, and what am I waiting for".
class LibraryView extends StatelessWidget {
  const LibraryView({
    super.key,
    required this.viewModel,
    required this.onOpenResource,
  });

  final LibraryViewModel viewModel;

  /// Opens an installed resource in a workspace tab.
  final void Function(ResourceDescriptor resource) onOpenResource;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;

    if (!state.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.entries.isEmpty) {
      return _EmptyLibrary(catalogKnown: state.catalogVersion != null);
    }

    return AdaptiveLayout(
      builder: (context, layoutClass) {
        return ListView(
          padding: const EdgeInsets.all(LogosSpacing.lg),
          children: [
            ConstrainedReading(
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'Instalados',
                    count: state.installed.length,
                    children: [
                      for (final entry in state.installed)
                        _Row(
                          entry: entry,
                          viewModel: viewModel,
                          onOpen: () => onOpenResource(entry.resource),
                        ),
                    ],
                  ),
                  if (state.available.isNotEmpty) ...[
                    const SizedBox(height: LogosSpacing.xl),
                    _Section(
                      title: 'Disponibles',
                      count: state.available.length,
                      children: [
                        for (final entry in state.available)
                          _Row(
                            entry: entry,
                            viewModel: viewModel,
                            onOpen: () => onOpenResource(entry.resource),
                          ),
                      ],
                    ),
                  ],
                  if (state.pending.isNotEmpty) ...[
                    const SizedBox(height: LogosSpacing.xl),
                    _Section(
                      title: 'Aún bajo derechos de autor',
                      count: state.pending.length,
                      children: [
                        for (final entry in state.pending)
                          _Row(entry: entry, viewModel: viewModel),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(title.toUpperCase(), style: LogosTypography.sectionLabel),
            const SizedBox(width: LogosSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LogosSpacing.sm,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: LogosColors.surfaceSunken,
                borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
              ),
              child: Text('$count', style: LogosTypography.sectionLabel),
            ),
          ],
        ),
        const SizedBox(height: LogosSpacing.sm),
        if (children.isEmpty)
          Text(
            'Nada aquí todavía.',
            style: LogosTypography.body.copyWith(color: LogosColors.textSecondary),
          )
        else
          Card(child: Column(children: children)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.viewModel, this.onOpen});

  final LibraryEntry entry;
  final LibraryViewModel viewModel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final r = entry.resource;
    final progress = viewModel.state.inProgress[r.id];
    final failure = viewModel.state.failures[r.id];

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LogosMeasured.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.name,
                              overflow: TextOverflow.ellipsis,
                              style: LogosTypography.navItem.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: LogosSpacing.sm),
                          _Tag(label: _typeLabel(r.type)),
                          if (r.granularity != Granularity.verse)
                            _Tag(label: 'por ${_granularityLabel(r.granularity)}'),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          r.shortName,
                          if (r.publisher != null) r.publisher!,
                          if (r.genre != null) r.genre!,
                        ].join(' · '),
                        style: LogosTypography.body
                            .copyWith(fontSize: 12, color: LogosColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: LogosSpacing.sm),
                _Action(
                  progress: progress,
                  failure: failure,
                  onOpen: onOpen,
                  onInstall: () => viewModel.install(r.id),
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
        if (failure != null)
          Container(
            width: double.infinity,
            color: LogosColors.dangerSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.xs,
            ),
            child: Text(
              'No se pudo instalar: $failure',
              style:
                  LogosTypography.body.copyWith(fontSize: 12, color: LogosColors.danger),
            ),
          ),
        if (entry.releaseDate != null)
          Container(
            width: double.infinity,
            color: LogosColors.warningSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: LogosSpacing.md,
              vertical: LogosSpacing.xs,
            ),
            child: Text(
              'Disponible a partir del ${entry.releaseDate!.toIso8601String().substring(0, 10)}: '
              'la obra sigue bajo derechos de autor.',
              style: LogosTypography.body.copyWith(fontSize: 12),
            ),
          ),
        const Divider(height: 1, color: LogosColors.border),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.progress,
    required this.failure,
    required this.onOpen,
    required this.onInstall,
    required this.onDismiss,
  });

  final InstallProgress? progress;
  final String? failure;
  final VoidCallback? onOpen;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (progress != null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (onOpen != null) {
      return TextButton(onPressed: onOpen, child: const Text('Abrir'));
    }
    return OutlinedButton(
      onPressed: onInstall,
      child: const Text('Instalar'),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: LogosSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: LogosColors.infoSurface,
        borderRadius: BorderRadius.circular(LogosDimensions.borderRadiusButton),
      ),
      child: Text(label, style: LogosTypography.sectionLabel),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.catalogKnown});

  final bool catalogKnown;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedReading(
        child: Padding(
          padding: const EdgeInsets.all(LogosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.library_books_outlined,
                  size: 40, color: LogosColors.textDisabled),
              const SizedBox(height: LogosSpacing.md),
              const Text('Biblioteca vacía', style: LogosTypography.title),
              const SizedBox(height: LogosSpacing.sm),
              Text(
                catalogKnown
                    ? 'El catálogo no ofrece ningún recurso. Eso puede ser correcto: '
                        'esta compilación solo distribuye obras de dominio público.'
                    : 'No hay contenido instalado. Sin un catálogo no hay nada que '
                        'instalar, pero los módulos que ya estén en disco siguen '
                        'disponibles.',
                textAlign: TextAlign.center,
                style: LogosTypography.body.copyWith(color: LogosColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(ResourceType t) => switch (t) {
      ResourceType.bible => 'Biblia',
      ResourceType.commentary => 'Comentario',
      ResourceType.lexicon => ' Léxico',
      ResourceType.dictionary => 'Diccionario',
      ResourceType.crossref => 'Referencias',
      ResourceType.devotion => 'Devocional',
      ResourceType.words => 'Palabras',
    };

String _granularityLabel(Granularity g) => switch (g) {
      Granularity.verse => 'verso',
      Granularity.chapter => 'capítulo',
      Granularity.book => 'libro',
    };

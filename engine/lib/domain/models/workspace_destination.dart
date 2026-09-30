import 'package:flutter/material.dart';

/// The nine primary destinations, in the order the reference shows them.
///
/// The order is the same on every layout class: only the chrome hosting them changes,
/// so muscle memory transfers between a phone and a desktop.
enum WorkspaceDestination {
  home('Panel de Control', Icons.dashboard_outlined),
  library('Biblioteca', Icons.library_books_outlined),
  search('Buscar', Icons.search),
  bible('Biblia', Icons.church_outlined),
  studyAssistant('Asistente de estudio', Icons.forum_outlined),
  encyclopedia('Enciclopedia bíblica', Icons.check_box_outlined),
  guides('Guías de Estudio', Icons.auto_stories_outlined),
  notes('Notas', Icons.edit_note_outlined),
  tools('Herramientas', Icons.grid_view_outlined);

  const WorkspaceDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The five quick actions from the reference's `Acciones Rápidas` section.
enum QuickAction {
  openCommentary('Abrir un comentario', Icons.comment_outlined),
  openStudyBible('Abrir una Biblia de estudio', Icons.menu_book_outlined),
  compareVersions('Comparar versiones de la Biblia', Icons.compare_arrows),
  openLexicon('Abrir un diccionario bíblico', Icons.text_fields),
  openDevotional('Abrir el devocional de hoy', Icons.wb_sunny_outlined);

  const QuickAction(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The six sections of a resource panel's toolbar, as the reference orders them.
enum ToolbarSectionId {
  home('Inicio'),
  search('Búsqueda'),
  notes('Notas'),
  format('Formato'),
  view('Vista'),
  share('Compartir'),
  more('Más');

  const ToolbarSectionId(this.label);

  final String label;
}

/// The six sections of a resource panel's sub-toolbar.
enum SubToolbarSectionId {
  contents('Contenido'),
  history('Historia'),
  article('Artículo'),
  linkSet('Conjunto de enlaces'),
  ideas('Ideas'),
  bookInfo('Información del libro');

  const SubToolbarSectionId(this.label);

  final String label;
}

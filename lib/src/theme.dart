import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'layout.dart';

/// Text styles of an ER diagram.
///
/// The same instance is used to measure the text during layout and to paint
/// it, so labels are painted exactly as they were measured.
@immutable
class ErTextStyles {
  /// Creates text styles from explicit [TextStyle]s.
  const ErTextStyles({
    required this.entityName,
    required this.attribute,
    required this.relationshipLabel,
    required this.subgraphTitle,
    required this.title,
    this.labelWrapWidth = 160,
  });

  /// Default styles in the font family of [base], usually the surrounding
  /// text style: 14 px entity names, 13 px attributes, relationship labels
  /// and subgraph titles, and a 16 px diagram title.
  factory ErTextStyles.from(
    TextStyle base, {
    double entityFontSize = 14,
    double fontSize = 13,
    double titleFontSize = 16,
    double labelWrapWidth = 160,
  }) {
    final family = TextStyle(
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
      height: 1.3,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return ErTextStyles(
      entityName: family.copyWith(
        fontSize: entityFontSize,
        fontWeight: FontWeight.w600,
      ),
      attribute: family.copyWith(fontSize: fontSize),
      relationshipLabel: family.copyWith(fontSize: fontSize),
      subgraphTitle: family.copyWith(fontSize: fontSize),
      title: family.copyWith(
        fontSize: titleFontSize,
        fontWeight: FontWeight.w600,
      ),
      labelWrapWidth: labelWrapWidth,
    );
  }

  /// Style of the entity names in the table headers.
  final TextStyle entityName;

  /// Style of attribute types, names, keys and comments.
  final TextStyle attribute;

  /// Style of relationship labels.
  final TextStyle relationshipLabel;

  /// Style of subgraph titles.
  final TextStyle subgraphTitle;

  /// Style of the diagram title from the front matter.
  final TextStyle title;

  /// Relationship labels wrap at this width.
  final double labelWrapWidth;

  /// Lays [text] out in the style of [role]. `**bold**` and `_italic_`
  /// Markdown is rendered everywhere but in attribute cells. The caller owns
  /// the returned painter and should dispose it.
  TextPainter layout(String text, ErTextRole role, {TextStyle? overrides}) {
    final (style, maxWidth) = switch (role) {
      ErTextRole.entityName => (entityName, double.infinity),
      ErTextRole.attribute => (attribute, double.infinity),
      ErTextRole.relationshipLabel => (relationshipLabel, labelWrapWidth),
      ErTextRole.subgraphTitle => (subgraphTitle, double.infinity),
      ErTextRole.title => (title, double.infinity),
    };
    final merged = style.merge(overrides);
    return TextPainter(
      text: role == ErTextRole.attribute
          ? TextSpan(text: text, style: merged)
          : TextSpan(style: merged, children: markdownSpans(text)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: maxWidth);
  }

  /// The size [text] takes in the style of [role]. Matches
  /// [ErTextMeasurer], so it can be handed to [ErDiagramLayout.compute].
  Size measure(String text, ErTextRole role) {
    final painter = layout(text, role);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static final RegExp _emphasis = RegExp(
    r'\*\*(.+?)\*\*|__(.+?)__|\*(?!\s)(.+?)(?<!\s)\*|'
    r'(?<![\p{L}\p{N}])_(?!\s)(.+?)(?<!\s)_(?![\p{L}\p{N}])',
    unicode: true,
  );

  /// Splits [text] into spans, rendering `**bold**` / `__bold__` and
  /// `*italic*` / `_italic_`. Underscores inside words (`LINE_ITEM`) are
  /// left alone.
  static List<InlineSpan> markdownSpans(String text, [TextStyle? style]) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in _emphasis.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final bold = match.group(1) ?? match.group(2);
      final inner = bold ?? match.group(3) ?? match.group(4)!;
      spans.add(
        TextSpan(
          style: bold != null
              ? const TextStyle(fontWeight: FontWeight.bold)
              : const TextStyle(fontStyle: FontStyle.italic),
          children: markdownSpans(inner),
        ),
      );
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    return spans;
  }

  @override
  bool operator ==(Object other) =>
      other is ErTextStyles &&
      other.entityName == entityName &&
      other.attribute == attribute &&
      other.relationshipLabel == relationshipLabel &&
      other.subgraphTitle == subgraphTitle &&
      other.title == title &&
      other.labelWrapWidth == labelWrapWidth;

  @override
  int get hashCode => Object.hash(
        entityName,
        attribute,
        relationshipLabel,
        subgraphTitle,
        title,
        labelWrapWidth,
      );
}

/// Colors of an ER diagram.
///
/// The defaults follow Mermaid's current look: every entity gets its own
/// pastel table (fuchsia, teal, orange, cyan...) with a matching outline and
/// grid, relationships are dark lines with crow's foot markers, and
/// subgraphs are light grey boxes. [ErPalette.dark] is the same design for
/// dark backgrounds.
///
/// `style`, `classDef` and `class` statements in the diagram override these
/// colors for the entities and subgraphs they target.
@immutable
class ErPalette {
  /// Creates a palette from explicit colors.
  const ErPalette({
    required this.background,
    required this.entityFills,
    required this.entityStrokes,
    required this.text,
    required this.line,
    required this.labelBackground,
    required this.subgraphFill,
    required this.subgraphStroke,
    required this.subgraphText,
  });

  /// The default palette for light backgrounds.
  const ErPalette.light()
      : this(
          background: const Color(0xFFFFFFFF),
          entityFills: _lightFills,
          entityStrokes: _strokes,
          text: const Color(0xFF28253D),
          line: const Color(0xFF000000),
          labelBackground: const Color(0xFFFFFFFF),
          subgraphFill: const Color(0xFFF9F9FB),
          subgraphStroke: const Color(0xFF28253D),
          subgraphText: const Color(0xFF3C3C43),
        );

  /// The default palette for dark backgrounds.
  const ErPalette.dark()
      : this(
          background: const Color(0xFF1B1B22),
          entityFills: _darkFills,
          entityStrokes: _darkStrokes,
          text: const Color(0xFFE8E8EE),
          line: const Color(0xFFD4D4DC),
          labelBackground: const Color(0xFF1B1B22),
          subgraphFill: const Color(0xFF23232C),
          subgraphStroke: const Color(0xFF8A8A99),
          subgraphText: const Color(0xFFC9C9D6),
        );

  /// [ErPalette.light] or [ErPalette.dark].
  factory ErPalette.of(Brightness brightness) => brightness == Brightness.light
      ? const ErPalette.light()
      : const ErPalette.dark();

  // Fuchsia, teal, orange, cyan, green, violet, amber and rose: Mermaid's
  // `redux-color` entity colors, in the order it assigns them.
  static const List<Color> _lightFills = [
    Color(0xFFFDF4FF),
    Color(0xFFF0FDFA),
    Color(0xFFFFF7ED),
    Color(0xFFECFEFF),
    Color(0xFFF0FDF4),
    Color(0xFFF5F3FF),
    Color(0xFFFFFBEB),
    Color(0xFFFFF1F2),
  ];
  static const List<Color> _strokes = [
    Color(0xFFE879F9),
    Color(0xFF2DD4BF),
    Color(0xFFFB923C),
    Color(0xFF22D3EE),
    Color(0xFF4ADE80),
    Color(0xFFA78BFA),
    Color(0xFFFBBF24),
    Color(0xFFFB7185),
  ];
  // The light strokes at 14 % (fills) and 80 % (strokes) opacity.
  static const List<Color> _darkFills = [
    Color(0x24E879F9),
    Color(0x242DD4BF),
    Color(0x24FB923C),
    Color(0x2422D3EE),
    Color(0x244ADE80),
    Color(0x24A78BFA),
    Color(0x24FBBF24),
    Color(0x24FB7185),
  ];
  static const List<Color> _darkStrokes = [
    Color(0xCCE879F9),
    Color(0xCC2DD4BF),
    Color(0xCCFB923C),
    Color(0xCC22D3EE),
    Color(0xCC4ADE80),
    Color(0xCCA78BFA),
    Color(0xCCFBBF24),
    Color(0xCCFB7185),
  ];

  /// Painted behind the whole diagram. Use a transparent color to let the
  /// surroundings show through.
  final Color background;

  /// Entity table fills, used in order of appearance and cycled. Must not
  /// be empty.
  final List<Color> entityFills;

  /// Entity outlines and grid lines, paired with [entityFills]. Must not be
  /// empty.
  final List<Color> entityStrokes;

  /// Color of entity names, attributes, relationship labels and the title.
  final Color text;

  /// Color of relationship lines and their markers.
  final Color line;

  /// Background of relationship labels and of the circles of the
  /// zero-or-one and zero-or-more markers.
  final Color labelBackground;

  /// Fill of subgraph boxes.
  final Color subgraphFill;

  /// Outline of subgraph boxes.
  final Color subgraphStroke;

  /// Color of subgraph titles.
  final Color subgraphText;

  @override
  bool operator ==(Object other) =>
      other is ErPalette &&
      other.background == background &&
      listEquals(other.entityFills, entityFills) &&
      listEquals(other.entityStrokes, entityStrokes) &&
      other.text == text &&
      other.line == line &&
      other.labelBackground == labelBackground &&
      other.subgraphFill == subgraphFill &&
      other.subgraphStroke == subgraphStroke &&
      other.subgraphText == subgraphText;

  @override
  int get hashCode => Object.hash(
        background,
        Object.hashAll(entityFills),
        Object.hashAll(entityStrokes),
        text,
        line,
        labelBackground,
        subgraphFill,
        subgraphStroke,
        subgraphText,
      );
}

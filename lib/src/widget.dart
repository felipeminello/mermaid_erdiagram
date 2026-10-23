import 'package:flutter/material.dart';

import 'layout.dart';
import 'model.dart';
import 'painter.dart';
import 'parser.dart';
import 'theme.dart';

/// Renders a Mermaid entity relationship diagram (`erDiagram`) natively,
/// without a WebView.
///
/// ```dart
/// MermaidErDiagram(
///   source: '''
/// erDiagram
///   CUSTOMER ||--o{ ORDER : places
///   ORDER ||--|{ LINE-ITEM : contains
/// ''',
/// )
/// ```
///
/// The diagram is drawn at its natural size, which depends on its content.
/// Wrap it in a `FittedBox` to shrink it to the available width, or in an
/// `InteractiveViewer` to pan and zoom.
///
/// Colors default to [ErPalette.light] or [ErPalette.dark] following the
/// ambient [Theme], and text uses the theme's `bodyMedium` font family.
/// Parsing and layout are cached and only redone when the source, the text
/// styles or [layoutConfig] change.
class MermaidErDiagram extends StatefulWidget {
  /// Parses and renders [source]. When it is not an ER diagram, or declares
  /// no entity, [errorBuilder] is shown instead.
  const MermaidErDiagram({
    super.key,
    required String this.source,
    this.palette,
    this.textStyles,
    this.layoutConfig = const ErLayoutConfig(),
    this.errorBuilder,
    this.onEntityTap,
    this.semanticLabel,
  }) : diagram = null;

  /// Renders an [ErDiagram] that was already parsed, for example with
  /// [ErDiagramParser] to decide beforehand whether it can be rendered.
  const MermaidErDiagram.diagram({
    super.key,
    required ErDiagram this.diagram,
    this.palette,
    this.textStyles,
    this.layoutConfig = const ErLayoutConfig(),
    this.onEntityTap,
    this.semanticLabel,
  })  : source = null,
        errorBuilder = null;

  /// Mermaid source, when built with the default constructor.
  final String? source;

  /// Parsed diagram, when built with [MermaidErDiagram.diagram].
  final ErDiagram? diagram;

  /// Colors. Defaults to the palette matching the theme's brightness.
  final ErPalette? palette;

  /// Text styles. Defaults to [ErTextStyles.from] the theme's `bodyMedium`
  /// style.
  final ErTextStyles? textStyles;

  /// Spacing of the layout.
  final ErLayoutConfig layoutConfig;

  /// Shown when [source] cannot be rendered. Defaults to an empty box.
  final WidgetBuilder? errorBuilder;

  /// Called with the entity under a tap.
  final ValueChanged<ErEntity>? onEntityTap;

  /// Description for screen readers. Defaults to the diagram's `accTitle`
  /// and `accDescr`, or "Entity relationship diagram:" followed by the
  /// entity names.
  final String? semanticLabel;

  @override
  State<MermaidErDiagram> createState() => _MermaidErDiagramState();
}

class _MermaidErDiagramState extends State<MermaidErDiagram> {
  ErDiagram? _parsed;
  String? _parsedSource;
  ErDiagramLayout? _layout;
  ErDiagram? _layoutDiagram;
  ErTextStyles? _layoutStyles;
  ErLayoutConfig? _layoutConfig;

  ErDiagram? get _diagram {
    final diagram = widget.diagram;
    if (diagram != null) return diagram;
    final source = widget.source!;
    if (source != _parsedSource) {
      _parsedSource = source;
      _parsed = const ErDiagramParser().parse(source);
    }
    return _parsed;
  }

  @override
  Widget build(BuildContext context) {
    final diagram = _diagram;
    if (diagram == null) {
      return widget.errorBuilder?.call(context) ?? const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final styles = widget.textStyles ??
        ErTextStyles.from(
          theme.textTheme.bodyMedium ?? DefaultTextStyle.of(context).style,
        );
    final config = widget.layoutConfig;
    if (_layout == null ||
        _layoutDiagram != diagram ||
        _layoutStyles != styles ||
        _layoutConfig != config) {
      _layout =
          ErDiagramLayout.compute(diagram, styles.measure, config: config);
      _layoutDiagram = diagram;
      _layoutStyles = styles;
      _layoutConfig = config;
    }
    final layout = _layout!;

    Widget painted = CustomPaint(
      size: layout.size,
      painter: ErDiagramPainter(
        diagram: diagram,
        layout: layout,
        styles: styles,
        palette: widget.palette ?? ErPalette.of(theme.brightness),
        config: config,
      ),
    );

    final onEntityTap = widget.onEntityTap;
    if (onEntityTap != null) {
      painted = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          for (final box in layout.entities.values) {
            if (box.rect.contains(details.localPosition)) {
              onEntityTap(box.entity);
              return;
            }
          }
        },
        child: painted,
      );
    }

    return Semantics(
      image: true,
      label: widget.semanticLabel ?? _describe(diagram),
      child: ExcludeSemantics(child: painted),
    );
  }

  static String _describe(ErDiagram diagram) {
    final described = [
      diagram.accessibilityTitle,
      diagram.accessibilityDescription,
    ].whereType<String>().where((text) => text.isNotEmpty).join('. ');
    if (described.isNotEmpty) return described;
    final names = diagram.entities.values
        .map((entity) => entity.label.replaceAll('\n', ' '))
        .join(', ');
    return 'Entity relationship diagram: $names';
  }
}

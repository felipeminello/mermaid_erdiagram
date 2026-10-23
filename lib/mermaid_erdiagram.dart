/// Native Mermaid entity relationship diagram rendering for Flutter: a
/// parser for the `erDiagram` syntax, a layered layout with subgraph
/// support and a `CustomPainter` drawing attribute tables and crow's foot
/// markers, with no WebView and no JavaScript.
///
/// Most apps only need [MermaidErDiagram]. The lower layers are exported
/// for custom rendering: [ErDiagramParser] turns source into an
/// [ErDiagram], [ErDiagramLayout] positions it and [ErDiagramPainter] draws
/// it.
library;

export 'package:mermaid_flowchart/mermaid_flowchart.dart' show FlowStyle;

export 'src/layout.dart'
    show
        ErDiagramLayout,
        ErEntityBox,
        ErLayoutConfig,
        ErRelationshipRoute,
        ErSubgraphBox,
        ErTextMeasurer,
        ErTextRole;
export 'src/model.dart';
export 'src/painter.dart' show ErDiagramPainter;
export 'src/parser.dart' show ErDiagramParser;
export 'src/theme.dart' show ErPalette, ErTextStyles;
export 'src/widget.dart' show MermaidErDiagram;

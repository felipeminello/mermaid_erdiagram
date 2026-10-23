# mermaid_erdiagram

[![pub package](https://img.shields.io/pub/v/mermaid_erdiagram.svg)](https://pub.dev/packages/mermaid_erdiagram)
[![CI](https://github.com/felipeminello/mermaid_erdiagram/actions/workflows/ci.yaml/badge.svg)](https://github.com/felipeminello/mermaid_erdiagram/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/felipeminello/mermaid_erdiagram/blob/main/LICENSE)

Render [Mermaid](https://mermaid.js.org/syntax/entityRelationshipDiagram.html)
entity relationship diagrams natively in Flutter: no WebView, no
JavaScript, on every platform.

![An ER diagram with attribute tables, keys and comments](https://raw.githubusercontent.com/felipeminello/mermaid_erdiagram/main/doc/attributes_light.png)

## Features

- **Attribute tables**: one row per attribute with type, name, `PK`/`FK`/`UK`
  keys and comments in their own columns, like Mermaid draws them.
- **Crow's foot notation**: zero or one, exactly one, zero or more and one
  or more, from symbols (`||--o{`) or words (`only one to zero or more`).
- **Identifying and non-identifying** relationships as solid or dashed
  lines, with labels.
- **Subgraphs**: nested groups of entities, also usable as relationship
  endpoints (`title1 ||--|| title2 : links`).
- **Readable names**: aliases (`p[Person]`), quoted and Unicode names, and
  `**bold**` / `_italic_` Markdown.
- **Styling**: `style`, `classDef` (including `default`), `class` and `:::`.
- **Light and dark palettes** that follow your `Theme`, with Mermaid's
  per-entity colors, fully customizable.
- **Interactive**: `onEntityTap` reports the tapped entity.
- **Pure Dart layout** you can also use on its own to draw on any canvas.

| Dark palette | Left to right, with a title |
| --- | --- |
| ![The diagram in the dark palette](https://raw.githubusercontent.com/felipeminello/mermaid_erdiagram/main/doc/attributes_dark.png) | ![An order model laid out left to right](https://raw.githubusercontent.com/felipeminello/mermaid_erdiagram/main/doc/orders.png) |

## Getting started

```sh
flutter pub add mermaid_erdiagram
```

## Usage

```dart
import 'package:mermaid_erdiagram/mermaid_erdiagram.dart';

MermaidErDiagram(
  source: '''
erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER ||--|{ LINE-ITEM : contains
  CUSTOMER {
    string name
    string custNumber PK
  }
''',
  errorBuilder: (context) => const Text('Not an ER diagram'),
  onEntityTap: (entity) => debugPrint('Tapped ${entity.id}'),
)
```

The diagram is drawn at its natural size, which depends on its content.
To fit it in the available width, or to pan and zoom:

```dart
FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.topLeft,
  child: MermaidErDiagram(source: source),
)

InteractiveViewer(
  constrained: false,
  child: MermaidErDiagram(source: source),
)
```

### Theming

Colors follow the ambient `Theme` brightness. Pass your own palette, text
styles or spacing to change them:

```dart
MermaidErDiagram(
  source: source,
  palette: const ErPalette.dark(),
  textStyles: ErTextStyles.from(
    const TextStyle(fontFamily: 'Inter'),
    entityFontSize: 15,
    fontSize: 13,
  ),
  layoutConfig: const ErLayoutConfig(entitySeparation: 64),
)
```

`style`, `classDef` and `class` statements in the diagram still win over
the palette for the entities and subgraphs they target.

### In Markdown

With [`flutter_markdown`](https://pub.dev/packages/flutter_markdown) or
[`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus),
render ```` ```mermaid ```` blocks with a custom builder:

```dart
class MermaidBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final source = element.textContent;
    if (element.attributes['class'] != 'language-mermaid' ||
        !ErDiagramParser.isErDiagram(source)) {
      return null; // Keep the default code block.
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: MermaidErDiagram(source: source),
    );
  }
}

MarkdownBody(data: markdown, builders: {'code': MermaidBuilder()});
```

It pairs well with
[`mermaid_flowchart`](https://pub.dev/packages/mermaid_flowchart): route
`FlowchartParser.isFlowchart` sources to `MermaidFlowchart` and
`ErDiagramParser.isErDiagram` ones to `MermaidErDiagram`.

### Lower-level API

Each stage is exported, so you can parse, lay out and paint separately:

```dart
final diagram = const ErDiagramParser().parse(source); // null if not an ER diagram
final styles = ErTextStyles.from(const TextStyle());
final layout = ErDiagramLayout.compute(diagram!, styles.measure);

layout.entities; // every table, its columns and rows
layout.subgraphs; // subgraph boxes
layout.relationships; // orthogonal polylines and label positions

CustomPaint(
  size: layout.size,
  painter: ErDiagramPainter(
    diagram: diagram,
    layout: layout,
    styles: styles,
    palette: const ErPalette.light(),
  ),
);
```

## Supported syntax

| Feature | Syntax |
| --- | --- |
| Header and title | `erDiagram`, front matter `title:` |
| Entities | `CUSTOMER`, `"name with spaces"`, Unicode, aliases `p[Person]` / `a["Customer Account"]` |
| Attributes | `type name`, `PK`, `FK`, `UK` (comma separated), `"comment"`, `string(99)`, `string[]`, `string?`, `List~T~`, `*name` |
| Cardinality | `\|o` `o\|`, `\|\|`, `}o` `o{`, `}\|` `\|{` and the word aliases (`zero or one`, `only one`, `1`, `one or more`, `1+`, `many(1)`, `zero or more`, `0+`, `many(0)`...) |
| Identification | `--` / `to` (solid), `..` / `optionally to` (dashed) |
| Labels | `: places`, `: "appears in"`, `: ""` |
| Direction | `direction TB`, `BT`, `LR`, `RL` |
| Subgraphs | `subgraph id`, `subgraph id [Title]`, `subgraph "Quoted"`, nesting, subgraphs as relationship endpoints |
| Styling | `style`, `classDef` (`default` included), `class`, `:::` |
| Misc | `%%` comments, `accTitle`, `accDescr` (used for semantics) |

Not supported yet: `direction` inside a subgraph (the diagram's direction
is used), CSS properties other than colors, stroke width and dashes (for
example `font-size`), and Mermaid's `config` options (`theme`, `look`,
`layout`). Unknown statements are skipped rather than failing the whole
diagram.

## How the layout works

1. **Tables.** Each entity is measured as a table: a header with its name
   and one row per attribute, with a column for types, names, keys (when
   any attribute has keys) and comments (when any has one).
2. **Placement and routing.** The tables are handed, as rectangles, to the
   layered layout of
   [`mermaid_flowchart`](https://pub.dev/packages/mermaid_flowchart):
   longest-path ranks, subgraphs moved as rigid blocks, barycenter
   ordering and orthogonal routing. Every relationship spans at least two
   ranks, so its label gets a lane of its own and both markers fit.
3. **Markers.** Lines keep a straight stretch next to each entity for the
   crow's foot; short steps right next to an entity are removed by sliding
   the line along the entity's side.
4. **Self relationships** become loops on the side of the table, with room
   reserved so neighbours stay clear.

## Example app

[`example/`](https://github.com/felipeminello/mermaid_erdiagram/tree/main/example) is a live editor: type Mermaid on one side and see it
rendered on the other, with sample diagrams and a dark mode toggle.

```sh
cd example
flutter create .   # generate the platform folders once
flutter run
```

## Contributing

Issues and pull requests are welcome. Run `dart format .`,
`flutter analyze` and `flutter test` before sending a change. The
screenshots in `doc/` are regenerated with
`flutter test tool/screenshots_test.dart`.

## License

[MIT](https://github.com/felipeminello/mermaid_erdiagram/blob/main/LICENSE)

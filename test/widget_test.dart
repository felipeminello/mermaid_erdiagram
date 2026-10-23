import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_erdiagram/mermaid_erdiagram.dart';

const _source = '''
erDiagram
  CUSTOMER ||--o{ ORDER : places
  ORDER {
    int orderNumber PK
  }
''';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

ErDiagramPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<ErDiagramPainter>()
    .single;

void main() {
  group('MermaidErDiagram', () {
    testWidgets('paints a diagram at its natural size', (tester) async {
      await tester.pumpWidget(_app(const MermaidErDiagram(source: _source)));

      final painter = _painter(tester);
      expect(painter.diagram.entities.keys, ['CUSTOMER', 'ORDER']);
      expect(
        tester.getSize(find.byType(MermaidErDiagram)),
        painter.layout.size,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows errorBuilder for sources it cannot render',
        (tester) async {
      await tester.pumpWidget(
        _app(
          MermaidErDiagram(
            source: 'flowchart LR\n A --> B',
            errorBuilder: (_) => const Text('not an ER diagram'),
          ),
        ),
      );

      expect(find.text('not an ER diagram'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is ErDiagramPainter,
        ),
        findsNothing,
      );
    });

    testWidgets('renders an already parsed diagram', (tester) async {
      final diagram = const ErDiagramParser().parse(_source)!;
      await tester.pumpWidget(
        _app(MermaidErDiagram.diagram(diagram: diagram)),
      );

      expect(_painter(tester).diagram, same(diagram));
    });

    testWidgets('follows the theme brightness unless a palette is given',
        (tester) async {
      await tester.pumpWidget(
        _app(
          const MermaidErDiagram(source: _source),
          brightness: Brightness.dark,
        ),
      );
      expect(_painter(tester).palette, const ErPalette.dark());

      const custom = ErPalette(
        background: Colors.transparent,
        entityFills: [Colors.yellow],
        entityStrokes: [Colors.black],
        text: Colors.black,
        line: Colors.blue,
        labelBackground: Colors.white,
        subgraphFill: Colors.white,
        subgraphStroke: Colors.grey,
        subgraphText: Colors.black,
      );
      await tester.pumpWidget(
        _app(
          const MermaidErDiagram(source: _source, palette: custom),
          brightness: Brightness.dark,
        ),
      );
      expect(_painter(tester).palette, custom);
    });

    testWidgets('reports taps on entities', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _app(
          MermaidErDiagram(
            source: _source,
            onEntityTap: (entity) => tapped.add(entity.id),
          ),
        ),
      );

      final layout = _painter(tester).layout;
      final origin = tester.getTopLeft(find.byType(MermaidErDiagram));
      await tester.tapAt(origin + layout.entities['ORDER']!.rect.center);
      // Taps between entities are ignored.
      await tester.tapAt(origin + const Offset(1, 1));

      expect(tapped, ['ORDER']);
    });

    testWidgets('describes itself to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const MermaidErDiagram(source: _source)));
      expect(
        find.bySemanticsLabel('Entity relationship diagram: CUSTOMER, ORDER'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _app(
          const MermaidErDiagram(
            source: 'erDiagram\n accTitle: Orders\n accDescr: Who buys what\n'
                ' A ||--o{ B : x',
          ),
        ),
      );
      expect(find.bySemanticsLabel('Orders. Who buys what'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('paints every marker, style and a self loop', (tester) async {
      await tester.pumpWidget(
        _app(
          const MermaidErDiagram(
            source: '''
---
title: Everything
---
erDiagram
  A |o--|| B : one
  B }o..}| C : many
  C o{--o| C : self
  subgraph G [Group]
    D:::hot
  end
  C ||--o{ G : grouped
  style A stroke-dasharray: 4 2
  classDef hot fill:#f00,color:#fff
''',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_painter(tester).layout.subgraphs, hasLength(1));
    });
  });

  group('ErTextStyles.markdownSpans', () {
    String describe(List<InlineSpan> spans) => spans.map((span) {
          final text = span as TextSpan;
          final inner = text.children == null
              ? text.text!
              : describe(text.children!.cast<InlineSpan>());
          if (text.style?.fontWeight == FontWeight.bold) return '<b>$inner</b>';
          if (text.style?.fontStyle == FontStyle.italic) return '<i>$inner</i>';
          return inner;
        }).join();

    test('renders emphasis but leaves identifiers alone', () {
      expect(
        describe(ErTextStyles.markdownSpans('This **is** _Markdown_')),
        'This <b>is</b> <i>Markdown</i>',
      );
      expect(describe(ErTextStyles.markdownSpans('LINE_ITEM')), 'LINE_ITEM');
      expect(
        describe(ErTextStyles.markdownSpans('**bold _and italic_**')),
        '<b>bold <i>and italic</i></b>',
      );
    });
  });
}

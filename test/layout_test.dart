// Tests for the layout. Text is measured by a fake with a fixed glyph
// width, so no fonts are involved.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_erdiagram/mermaid_erdiagram.dart';

const _attributes = '''
erDiagram
    CAR ||--o{ NAMED-DRIVER : allows
    CAR {
        string registrationNumber PK
        string make
        string model
        string[] parts
    }
    PERSON ||--o{ NAMED-DRIVER : is
    PERSON {
        string driversLicense PK "The license #"
        string(99) firstName "Only 99 characters are allowed"
        string lastName
        string phone UK
        int age
    }
    NAMED-DRIVER {
        string carRegistrationNumber PK, FK
        string driverLicence PK, FK
    }
    MANUFACTURER only one to zero or more CAR : makes
''';

ErDiagram _parse(String source) => const ErDiagramParser().parse(source)!;

Size _measure(String text, ErTextRole role) {
  final lines = text.split('\n');
  final longest = lines.map((line) => line.length).reduce(math.max);
  return Size(longest * 7.0, lines.length * 17.0);
}

ErDiagramLayout _layout(String source) =>
    ErDiagramLayout.compute(_parse(source), _measure);

void _expectNoOverlaps(ErDiagramLayout layout) {
  final boxes = layout.entities.values.toList();
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final overlap = boxes[i].rect.intersect(boxes[j].rect);
      expect(
        overlap.width > 0.5 && overlap.height > 0.5,
        isFalse,
        reason: '${boxes[i].entity.id} overlaps ${boxes[j].entity.id}',
      );
    }
  }
}

bool _onOutline(Offset point, Rect rect) {
  const e = 0.5;
  final insideX = point.dx >= rect.left - e && point.dx <= rect.right + e;
  final insideY = point.dy >= rect.top - e && point.dy <= rect.bottom + e;
  final onX =
      (point.dx - rect.left).abs() < e || (point.dx - rect.right).abs() < e;
  final onY =
      (point.dy - rect.top).abs() < e || (point.dy - rect.bottom).abs() < e;
  return (onX && insideY) || (onY && insideX);
}

void _expectAttached(ErDiagramLayout layout) {
  for (final route in layout.relationships) {
    final relationship = route.relationship;
    final from = layout.entities[relationship.from];
    final to = layout.entities[relationship.to];
    if (from != null) {
      expect(_onOutline(route.points.first, from.rect), isTrue,
          reason: '${relationship.from} start');
    }
    if (to != null) {
      expect(_onOutline(route.points.last, to.rect), isTrue,
          reason: '${relationship.to} end');
    }
    for (var i = 0; i + 1 < route.points.length; i++) {
      final a = route.points[i];
      final b = route.points[i + 1];
      expect(
        (a.dx - b.dx).abs() < 0.01 || (a.dy - b.dy).abs() < 0.01,
        isTrue,
        reason: '${relationship.from} -> ${relationship.to} has a diagonal',
      );
    }
  }
}

void main() {
  group('tables', () {
    test('have a column per part and a row per attribute', () {
      final layout = _layout(_attributes);

      final car = layout.entities['CAR']!;
      expect(car.columnWidths, hasLength(3)); // type, name, keys
      expect(car.rows, [
        ['string', 'registrationNumber', 'PK'],
        ['string', 'make', ''],
        ['string', 'model', ''],
        ['string[]', 'parts', ''],
      ]);

      final person = layout.entities['PERSON']!;
      expect(person.columnWidths, hasLength(4)); // + comment
      expect(person.rows.first.last, 'The license #');

      final driver = layout.entities['NAMED-DRIVER']!;
      expect(driver.rows.first[2], 'PK,FK');

      // Columns fit their widest cell plus padding and fill the table.
      expect(car.columnWidths[1], 'registrationNumber'.length * 7.0 + 24);
      expect(
        car.columnWidths.reduce((a, b) => a + b),
        closeTo(car.rect.width, 0.01),
      );
      expect(
        car.rect.height,
        closeTo(car.headerHeight + car.rowHeight * 4, 0.01),
      );
      expect(car.cellRect(3, 1).bottom, closeTo(car.rect.bottom, 0.01));
    });

    test('without attributes are a padded name box', () {
      final layout = _layout(_attributes);
      final manufacturer = layout.entities['MANUFACTURER']!;
      expect(manufacturer.rows, isEmpty);
      expect(manufacturer.rect.width, 'MANUFACTURER'.length * 7.0 + 48);
      expect(manufacturer.rect.height, 56);
      expect(manufacturer.headerHeight, manufacturer.rect.height);
    });

    test('widen their columns for a long name', () {
      final layout = _layout('''
erDiagram
    A_VERY_LONG_ENTITY_NAME_INDEED {
        int id
    }
''');
      final box = layout.entities.values.single;
      expect(
        box.rect.width,
        'A_VERY_LONG_ENTITY_NAME_INDEED'.length * 7.0 + 24,
      );
      expect(box.columnWidths[0], closeTo(box.columnWidths[1], 0.01 + 7 * 2));
    });
  });

  group('layout', () {
    test('places entities without overlaps and attaches every line', () {
      final layout = _layout(_attributes);
      _expectNoOverlaps(layout);
      _expectAttached(layout);
      expect(layout.relationships, hasLength(3));
      for (final box in layout.entities.values) {
        expect(
            (Offset.zero & layout.size).contains(box.rect.bottomRight), isTrue);
      }
    });

    test('leaves room for the markers before a line bends', () {
      final layout = _layout(_attributes);
      for (final route in layout.relationships) {
        final points = route.points;
        if (points.length < 3) continue;
        expect((points[1] - points[0]).distance, greaterThanOrEqualTo(34));
        expect(
          (points[points.length - 1] - points[points.length - 2]).distance,
          greaterThanOrEqualTo(34),
        );
      }
    });

    test('ranks go down by default and right with direction LR', () {
      const source = '''
erDiagram
    %s
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
''';
      var layout = _layout(source.replaceFirst('%s', ''));
      var customer = layout.entities['CUSTOMER']!.rect;
      var order = layout.entities['ORDER']!.rect;
      expect(order.top, greaterThan(customer.bottom));

      layout = _layout(source.replaceFirst('%s', 'direction LR'));
      customer = layout.entities['CUSTOMER']!.rect;
      order = layout.entities['ORDER']!.rect;
      expect(order.left, greaterThan(customer.right));
      _expectAttached(layout);
    });

    test('keeps subgraph members inside their box', () {
      final layout = _layout('''
erDiagram
    subgraph title1
        A1 ||--|| A2 : links
    end
    subgraph title2
        B1 ||--|| B2 : links
        subgraph inner
            C1
        end
    end
    title1 ||--|| title2 : links
    OUTSIDE ||--|| B1 : links
''');
      _expectNoOverlaps(layout);
      final boxes = {
        for (final box in layout.subgraphs) box.subgraph.id: box,
      };
      expect(boxes.keys, unorderedEquals(['title1', 'title2', 'inner']));
      expect(boxes['inner']!.depth, 1);

      bool inside(String entity, String subgraph) =>
          boxes[subgraph]!.rect.contains(layout.entities[entity]!.rect.center);
      expect(inside('A1', 'title1'), isTrue);
      expect(inside('A2', 'title1'), isTrue);
      expect(inside('B1', 'title2'), isTrue);
      expect(inside('C1', 'inner'), isTrue);
      expect(inside('C1', 'title2'), isTrue);
      expect(inside('OUTSIDE', 'title1'), isFalse);
      expect(inside('OUTSIDE', 'title2'), isFalse);

      // The subgraph-to-subgraph relationship ends on both boxes.
      final link = layout.relationships
          .firstWhere((route) => route.relationship.from == 'title1');
      expect(_onOutline(link.points.first, boxes['title1']!.rect), isTrue);
      expect(_onOutline(link.points.last, boxes['title2']!.rect), isTrue);
    });

    test('draws self relationships as loops clear of other entities', () {
      for (final direction in ['TB', 'LR']) {
        final layout = _layout('''
erDiagram
    direction $direction
    EMPLOYEE }o--o| EMPLOYEE : manages
    EMPLOYEE ||--o{ TASK : owns
    BOSS ||--o{ TASK : reviews
''');
        final route = layout.relationships.first;
        final employee = layout.entities['EMPLOYEE']!.rect;
        expect(route.points, hasLength(4));
        expect(_onOutline(route.points.first, employee), isTrue);
        expect(_onOutline(route.points.last, employee), isTrue);
        expect(route.labelRect, isNotNull);
        for (final box in layout.entities.values) {
          if (box.entity.id == 'EMPLOYEE') continue;
          expect(box.rect.overlaps(route.labelRect!), isFalse,
              reason: '$direction: label over ${box.entity.id}');
          for (final point in route.points.skip(1).take(2)) {
            expect(box.rect.contains(point), isFalse,
                reason: '$direction: loop through ${box.entity.id}');
          }
        }
        expect((Offset.zero & layout.size).contains(route.labelRect!.center),
            isTrue);
      }
    });

    test('puts the title above the diagram', () {
      final layout = _layout('''
---
title: A rather long diagram title
---
erDiagram
    A ||--o{ B : has
''');
      final title = layout.titleRect!;
      expect(title.width, 'A rather long diagram title'.length * 7.0);
      expect(title.center.dx, closeTo(layout.size.width / 2, 0.01));
      for (final box in layout.entities.values) {
        expect(box.rect.top, greaterThan(title.bottom));
      }
      expect(_layout('erDiagram\n A ||--o{ B : has').titleRect, isNull);
    });
  });
}

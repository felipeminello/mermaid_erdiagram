import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_erdiagram/mermaid_erdiagram.dart';

ErDiagram _parse(String source) => const ErDiagramParser().parse(source)!;

ErRelationship _single(String statement) =>
    _parse('erDiagram\n  $statement').relationships.single;

void main() {
  group('ErDiagramParser.isErDiagram', () {
    test('detects erDiagram headers', () {
      expect(ErDiagramParser.isErDiagram('erDiagram\n A ||--o{ B : x'), isTrue);
      expect(ErDiagramParser.isErDiagram('%% note\n\nerDiagram\n A'), isTrue);
      expect(
        ErDiagramParser.isErDiagram('---\ntitle: T\n---\nerDiagram\n A'),
        isTrue,
      );
    });

    test('rejects other diagrams', () {
      expect(ErDiagramParser.isErDiagram('flowchart LR\n A-->B'), isFalse);
      expect(ErDiagramParser.isErDiagram('erDiagrams'), isFalse);
      expect(ErDiagramParser.isErDiagram(''), isFalse);
    });
  });

  group('parse', () {
    test('returns null for other diagrams and empty ER diagrams', () {
      const parser = ErDiagramParser();
      expect(parser.parse('flowchart LR\n A --> B'), isNull);
      expect(parser.parse('erDiagram'), isNull);
      expect(parser.parse('erDiagram\n %% only a comment'), isNull);
    });

    test('reads the order example', () {
      final diagram = _parse('''
---
title: Order example
---
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
''');
      expect(diagram.title, 'Order example');
      expect(diagram.direction, ErDirection.topDown);
      expect(
        diagram.entities.keys,
        ['CUSTOMER', 'ORDER', 'LINE-ITEM', 'DELIVERY-ADDRESS'],
      );

      final places = diagram.relationships[0];
      expect(places.from, 'CUSTOMER');
      expect(places.to, 'ORDER');
      expect(places.fromCardinality, ErCardinality.exactlyOne);
      expect(places.toCardinality, ErCardinality.zeroOrMore);
      expect(places.identifying, isTrue);
      expect(places.label, 'places');

      final uses = diagram.relationships[2];
      expect(uses.fromCardinality, ErCardinality.oneOrMore);
      expect(uses.toCardinality, ErCardinality.oneOrMore);
      expect(uses.identifying, isFalse);
    });

    test('maps every cardinality symbol on either side', () {
      const expected = {
        '|o': ErCardinality.zeroOrOne,
        'o|': ErCardinality.zeroOrOne,
        '||': ErCardinality.exactlyOne,
        '}o': ErCardinality.zeroOrMore,
        'o{': ErCardinality.zeroOrMore,
        '}|': ErCardinality.oneOrMore,
        '|{': ErCardinality.oneOrMore,
      };
      for (final MapEntry(key: left, value: from) in expected.entries) {
        for (final MapEntry(key: right, value: to) in expected.entries) {
          final relationship = _single('A $left--$right B : r');
          expect(relationship.fromCardinality, from, reason: '$left--$right');
          expect(relationship.toCardinality, to, reason: '$left--$right');
        }
      }
    });

    test('understands the word aliases', () {
      var relationship = _single('CAR 1 to zero or more NAMED-DRIVER : allows');
      expect(relationship.fromCardinality, ErCardinality.exactlyOne);
      expect(relationship.toCardinality, ErCardinality.zeroOrMore);
      expect(relationship.identifying, isTrue);
      expect(relationship.to, 'NAMED-DRIVER');

      relationship =
          _single('PERSON many(0) optionally to 0+ NAMED-DRIVER : is');
      expect(relationship.fromCardinality, ErCardinality.zeroOrMore);
      expect(relationship.toCardinality, ErCardinality.zeroOrMore);
      expect(relationship.identifying, isFalse);

      relationship =
          _single('MANUFACTURER only one to zero or more CAR : makes');
      expect(relationship.from, 'MANUFACTURER');
      expect(relationship.fromCardinality, ErCardinality.exactlyOne);
      expect(relationship.toCardinality, ErCardinality.zeroOrMore);

      const aliases = {
        'one or zero': ErCardinality.zeroOrOne,
        'zero or one': ErCardinality.zeroOrOne,
        'one or more': ErCardinality.oneOrMore,
        'one or many': ErCardinality.oneOrMore,
        'many(1)': ErCardinality.oneOrMore,
        '1+': ErCardinality.oneOrMore,
        'zero or more': ErCardinality.zeroOrMore,
        'zero or many': ErCardinality.zeroOrMore,
        'many(0)': ErCardinality.zeroOrMore,
        '0+': ErCardinality.zeroOrMore,
        'only one': ErCardinality.exactlyOne,
        '1': ErCardinality.exactlyOne,
      };
      for (final MapEntry(key: alias, value: cardinality) in aliases.entries) {
        relationship = _single('A $alias to $alias B : r');
        expect(relationship.fromCardinality, cardinality, reason: alias);
        expect(relationship.toCardinality, cardinality, reason: alias);
        expect(relationship.to, 'B', reason: alias);
      }
    });

    test('reads relationships without spaces, quotes or labels', () {
      var relationship = _single('id1||--||id2 : label');
      expect((relationship.from, relationship.to), ('id1', 'id2'));
      expect(relationship.label, 'label');

      expect(_single('PRODUCT ||--o{ LINE_ITEM : "appears in"').label,
          'appears in');
      expect(_single('A ||--o{ B : ""').label, '');
      expect(_single('A ||--o{ B').label, '');

      relationship = _single('PERSON o{--|| HOUSE:::bar : has');
      expect(relationship.fromCardinality, ErCardinality.zeroOrMore);
      expect(relationship.to, 'HOUSE');
    });

    test('reads attributes with keys and comments', () {
      final diagram = _parse('''
erDiagram
    PERSON {
        string driversLicense PK "The license #"
        string(99) firstName "Only 99 characters are allowed"
        string? middleName
        string phone UK
        decimal(10, 2) salary
        List~string~ nicknames
        string[] parts
        int *id
    }
    NAMED-DRIVER {
        string carRegistrationNumber PK, FK
        string driverLicence PK,FK
    }
''');
      final person = diagram.entities['PERSON']!.attributes;
      expect(person.map((a) => a.type), [
        'string',
        'string(99)',
        'string?',
        'string',
        'decimal(10, 2)',
        'List<string>',
        'string[]',
        'int',
      ]);
      expect(person.map((a) => a.name), [
        'driversLicense',
        'firstName',
        'middleName',
        'phone',
        'salary',
        'nicknames',
        'parts',
        '*id',
      ]);
      expect(person[0].keys, [ErAttributeKey.primary]);
      expect(person[0].comment, 'The license #');
      expect(person[1].keys, isEmpty);
      expect(person[1].comment, 'Only 99 characters are allowed');
      expect(person[3].keys, [ErAttributeKey.unique]);
      expect(person[2].comment, isNull);

      for (final attribute in diagram.entities['NAMED-DRIVER']!.attributes) {
        expect(
            attribute.keys, [ErAttributeKey.primary, ErAttributeKey.foreign]);
      }
    });

    test('reads one-line, empty and repeated attribute blocks', () {
      final diagram = _parse('''
erDiagram
    A { int id PK string name }
    B {
    }
    A {
        date createdAt
    }
    A ||--o{ B : has
''');
      expect(
        diagram.entities['A']!.attributes.map((a) => a.name),
        ['id', 'name', 'createdAt'],
      );
      expect(diagram.entities['B']!.attributes, isEmpty);
      expect(diagram.relationships, hasLength(1));
    });

    test('reads aliases, quoted names and Markdown', () {
      final diagram = _parse('''
erDiagram
    p[Person] {
        string firstName
    }
    a["Customer Account"] {
        string email
    }
    p ||--o| a : has
    "This ❤ Unicode"
    "This **is** _Markdown_"
''');
      expect(diagram.entities['p']!.label, 'Person');
      expect(diagram.entities['a']!.label, 'Customer Account');
      expect(diagram.entities['This ❤ Unicode']!.label, 'This ❤ Unicode');
      expect(
        diagram.entities['This **is** _Markdown_']!.label,
        'This **is** _Markdown_',
      );
      final has = diagram.relationships.single;
      expect((has.from, has.to), ('p', 'a'));
      expect(has.toCardinality, ErCardinality.zeroOrOne);
    });

    test('reads direction, comments and accessibility statements', () {
      final diagram = _parse('''
erDiagram
    %% a comment
    direction LR
    accTitle: Orders
    accDescr {
        Customers place
        orders.
    }
    CUSTOMER ||--o{ ORDER : places
''');
      expect(diagram.direction, ErDirection.leftRight);
      expect(diagram.accessibilityTitle, 'Orders');
      expect(diagram.accessibilityDescription, 'Customers place orders.');
      expect(diagram.entities.keys, ['CUSTOMER', 'ORDER']);
    });

    test('groups entities in nested subgraphs', () {
      final diagram = _parse('''
erDiagram
    CUSTOMER ||--o{ CAR : rents
    subgraph title1
        CUSTOMER
        CUSTOMER {
            string name
        }
    end
    subgraph title2
        CAR ||--o{ NAMED-DRIVER : allows
        subgraph title3 [Drivers]
            PERSON
        end
    end
    subgraph "Customer Domain"
        ACCOUNT
    end
''');
      expect(diagram.subgraphs.keys,
          ['title1', 'title3', 'title2', 'Customer Domain']);
      expect(diagram.entities['CUSTOMER']!.subgraph, 'title1');
      expect(diagram.entities['CAR']!.subgraph, 'title2');
      expect(diagram.entities['NAMED-DRIVER']!.subgraph, 'title2');
      expect(diagram.entities['PERSON']!.subgraph, 'title3');
      expect(diagram.entities['ACCOUNT']!.subgraph, 'Customer Domain');

      final title2 = diagram.subgraphs['title2']!;
      expect(title2.entityIds, ['CAR', 'NAMED-DRIVER']);
      expect(title2.childIds, ['title3']);
      expect(diagram.subgraphs['title3']!.parent, 'title2');
      expect(diagram.subgraphs['title3']!.title, 'Drivers');
      expect(diagram.subgraphs['Customer Domain']!.title, 'Customer Domain');
    });

    test('treats subgraph ids in relationships as subgraphs', () {
      final diagram = _parse('''
erDiagram
    subgraph title1
        A1 ||--|| A2 : links
    end
    subgraph title2
        direction BT
        B1 ||--|| B2 : links
    end
    title1 ||--|| title2 : links
    title2 ||--|| A1 : links
''');
      expect(diagram.entities.keys, ['A1', 'A2', 'B1', 'B2']);
      expect(diagram.subgraphs['title2']!.direction, ErDirection.bottomUp);
      expect(diagram.relationships[2].from, 'title1');
      expect(diagram.relationships[2].to, 'title2');
    });

    test('resolves style, classDef, class, ::: and the default class', () {
      final diagram = _parse('''
erDiagram
    PERSON:::foo ||--|| CAR : owns
    PERSON o{--|| HOUSE:::bar,baz : has
    CAR:::someclass {
        string make
    }
    class HOUSE extra
    style CAR fill:#bbf,stroke:#f66,stroke-width:2px,color:#fff,stroke-dasharray: 5 5
    classDef default fill:#f9f,stroke-width:4px;
    classDef foo stroke:#f00
    classDef bar,baz stroke:#0f0
''');
      final person = diagram.entities['PERSON']!;
      final house = diagram.entities['HOUSE']!;
      final car = diagram.entities['CAR']!;
      expect(person.classes, ['foo']);
      expect(house.classes, ['bar', 'baz', 'extra']);
      expect(car.classes, ['someclass']);

      final personStyle = diagram.entityStyle(person);
      expect(personStyle.fill, const Color(0xFFFF99FF));
      expect(personStyle.stroke, const Color(0xFFFF0000));
      expect(personStyle.strokeWidth, 4);

      expect(diagram.entityStyle(house).stroke, const Color(0xFF00FF00));

      final carStyle = diagram.entityStyle(car);
      expect(carStyle.fill, const Color(0xFFBBBBFF));
      expect(carStyle.stroke, const Color(0xFFFF6666));
      expect(carStyle.color, const Color(0xFFFFFFFF));
      expect(carStyle.strokeWidth, 2);
      expect(carStyle.dashArray, [5, 5]);
    });

    test('keeps self relationships and skips unknown statements', () {
      final diagram = _parse('''
erDiagram
    EMPLOYEE }o--o| EMPLOYEE : manages
    click EMPLOYEE callback
    this is not valid ||
''');
      final manages = diagram.relationships.single;
      expect((manages.from, manages.to), ('EMPLOYEE', 'EMPLOYEE'));
      expect(diagram.entities.keys, ['EMPLOYEE']);
    });
  });
}

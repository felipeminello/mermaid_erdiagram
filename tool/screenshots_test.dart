// Regenerates the screenshots in doc/ used by the README and pub.dev:
//
//   flutter test tool/screenshots_test.dart
//
// Tests render with a placeholder font, so a real one is loaded first. The
// default path is Arial on macOS; set SCREENSHOT_FONT to use another file.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const _orders = '''
---
title: Order example
---
erDiagram
    direction LR
    CUSTOMER ||--o{ ORDER : places
    CUSTOMER {
        string name
        string custNumber
        string sector
    }
    ORDER ||--|{ LINE-ITEM : contains
    ORDER {
        int orderNumber
        string deliveryAddress
    }
    LINE-ITEM {
        string productCode
        int quantity
        float pricePerUnit
    }
    CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
''';

Future<void> _capture(
  WidgetTester tester,
  String source,
  String file, {
  Brightness brightness = Brightness.light,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness, fontFamily: 'Screenshot'),
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: MermaidErDiagram(source: source),
          ),
        ),
      ),
    ),
  );
  // MaterialApp animates theme changes.
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Platform.environment['SCREENSHOT_DIR'] ?? 'doc';
    File('$directory/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('screenshots', (tester) async {
    final font = Platform.environment['SCREENSHOT_FONT'] ??
        '/System/Library/Fonts/Supplemental/Arial.ttf';
    final bytes = File(font).readAsBytesSync();
    await (FontLoader('Screenshot')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    tester.view.physicalSize = const Size(3000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _capture(tester, _attributes, 'attributes_light.png');
    await _capture(
      tester,
      _attributes,
      'attributes_dark.png',
      brightness: Brightness.dark,
    );
    await _capture(tester, _orders, 'orders.png');
  });
}

import 'package:flutter/material.dart';
import 'package:mermaid_erdiagram/mermaid_erdiagram.dart';

void main() => runApp(const ExampleApp());

/// Sample diagrams, from the Mermaid documentation and a few more.
const Map<String, String> samples = {
  'Attributes and keys': '''
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
''',
  'Order example': '''
---
title: Order example
---
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE-ITEM : contains
    CUSTOMER }|..|{ DELIVERY-ADDRESS : uses
''',
  'Left to right': '''
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
''',
  'Aliases': '''
erDiagram
    p[Person] {
        string firstName
        string? middleName
        string lastName
    }
    a["Customer Account"] {
        string email
    }
    p ||--o| a : has
    EMPLOYEE }o--o| EMPLOYEE : manages
    p ||--o| EMPLOYEE : "works as"
''',
  'Subgraphs': '''
erDiagram
    subgraph title1
        A1 ||--|| A2 : links
    end

    subgraph title2
        B1 ||--|| B2 : links
    end

    subgraph title3
        C1 ||--|| C2 : links
    end

    title1 ||--|| title2 : links
    title2 ||--|| title3 : links
    title2 ||--|| C2 : links
''',
  'Styles': '''
erDiagram
    CAR {
        string registrationNumber
        string make
        string model
    }
    PERSON {
        string firstName
        string lastName
        int age
    }
    PERSON:::foo ||--|| CAR : owns
    PERSON o{--|| HOUSE:::bar : has

    classDef default fill:#f9f,stroke-width:4px
    classDef foo stroke:#f00
    classDef bar stroke:#0f0
''',
};

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mermaid_erdiagram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      themeMode: _mode,
      home: EditorPage(
        dark: _mode == ThemeMode.dark,
        onToggleDark: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// Edit Mermaid source on one side and see it rendered on the other.
class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.dark,
    required this.onToggleDark,
  });

  final bool dark;
  final VoidCallback onToggleDark;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  String _sample = samples.keys.first;
  late final TextEditingController _source =
      TextEditingController(text: samples[_sample]);

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  void _select(String? name) {
    if (name == null) return;
    setState(() {
      _sample = name;
      _source.text = samples[name]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = TextField(
      controller: _source,
      onChanged: (_) => setState(() {}),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'erDiagram\n  CUSTOMER ||--o{ ORDER : places',
      ),
    );

    final preview = InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.2,
      maxScale: 4,
      child: MermaidErDiagram(
        source: _source.text,
        errorBuilder: (context) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Not an ER diagram (start with "erDiagram").'),
        ),
        onEntityTap: (entity) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Tapped "${entity.id}" '
                '(${entity.attributes.length} attributes)',
              ),
            ),
          ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('mermaid_erdiagram'),
        actions: [
          DropdownButton<String>(
            value: _sample,
            underline: const SizedBox.shrink(),
            onChanged: _select,
            items: [
              for (final name in samples.keys)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
          ),
          IconButton(
            tooltip: widget.dark ? 'Light theme' : 'Dark theme',
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleDark,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final children = [
            Expanded(
              flex: 2,
              child: Padding(padding: const EdgeInsets.all(12), child: editor),
            ),
            Expanded(flex: 3, child: ClipRect(child: preview)),
          ];
          return wide ? Row(children: children) : Column(children: children);
        },
      ),
    );
  }
}

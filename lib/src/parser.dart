import 'package:mermaid_flowchart/mermaid_flowchart.dart' show FlowStyle;

import 'model.dart';

/// Parses the Mermaid entity relationship syntax (`erDiagram`) into an
/// [ErDiagram].
///
/// Covers the documented syntax: entities with or without attribute blocks,
/// quoted and Unicode names, aliases (`p[Person]`), attributes with
/// `PK`/`FK`/`UK` keys and comments, every cardinality marker and its word
/// aliases (`||--o{`, `only one to zero or more`), identifying (`--`, `to`)
/// and non-identifying (`..`, `optionally to`) relationships, `direction`,
/// nested subgraphs (also as relationship endpoints), `style`, `classDef`,
/// `class`, `:::`, `accTitle`/`accDescr` and the front matter `title`.
/// Statements it does not understand are skipped.
class ErDiagramParser {
  /// Creates a parser. It holds no state and can be reused.
  const ErDiagramParser();

  static final RegExp _header = RegExp(
    r'^erDiagram(?=\s|;|$)',
    caseSensitive: false,
  );

  /// Whether [source] declares an ER diagram (`erDiagram`), after any front
  /// matter, `%%` comments and directives. Cheap: it only looks at the
  /// header, so other diagram types can be routed elsewhere.
  static bool isErDiagram(String source) {
    final lines = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('%%'))
        .toList();
    if (lines.isNotEmpty && lines.first == '---') {
      final close = lines.indexOf('---', 1);
      if (close > 0) lines.removeRange(0, close + 1);
    }
    return lines.isNotEmpty && _header.hasMatch(lines.first);
  }

  /// Parses [source]. Returns `null` when it is not an ER diagram or
  /// declares no entity. Statements that cannot be understood are skipped.
  ErDiagram? parse(String source) => _ErReader().read(source);
}

class _Scanner {
  _Scanner(this.text);

  final String text;
  int index = 0;

  bool get done => index >= text.length;
  String get current => index < text.length ? text[index] : '';
  String at(int offset) {
    final i = index + offset;
    return i >= 0 && i < text.length ? text[i] : '';
  }

  bool startsWith(String pattern) => text.startsWith(pattern, index);

  void skipSpaces() {
    while (!done && _isSpace(current)) {
      index++;
    }
  }
}

bool _isSpace(String char) =>
    char == ' ' || char == '\t' || char == '\r' || char == '\n';

/// An entity reference: `NAME`, `"quoted name"`, `NAME[Alias]`, followed by
/// optional `:::classes`.
class _Ref {
  const _Ref(this.id, {this.label, this.classes = const []});

  final String id;
  final String? label;
  final List<String> classes;
}

final RegExp _symbolCardinality = RegExp(r'\|o|o\||\|\||\}o|o\{|\}\||\|\{');

final RegExp _wordCardinality = RegExp(
  r'(one\s+or\s+zero|zero\s+or\s+one|one\s+or\s+more|one\s+or\s+many|'
  r'many\(1\)|1\+|zero\s+or\s+more|zero\s+or\s+many|many\(0\)|0\+|'
  r'only\s+one|1)(?=\s|$)',
);

final RegExp _optionallyTo = RegExp(r'optionally\s+to(?=\s)');
final RegExp _to = RegExp(r'to(?=\s)');

ErCardinality _cardinalityOf(String marker) {
  final words = marker.replaceAll(RegExp(r'\s+'), ' ');
  switch (words) {
    case '|o' || 'o|' || 'zero or one' || 'one or zero':
      return ErCardinality.zeroOrOne;
    case '||' || 'only one' || '1':
      return ErCardinality.exactlyOne;
    case '}o' || 'o{' || 'zero or more' || 'zero or many' || 'many(0)' || '0+':
      return ErCardinality.zeroOrMore;
    default:
      return ErCardinality.oneOrMore;
  }
}

const Map<String, ErAttributeKey> _keys = {
  'PK': ErAttributeKey.primary,
  'FK': ErAttributeKey.foreign,
  'UK': ErAttributeKey.unique,
};

class _ErReader {
  ErDirection direction = ErDirection.topDown;
  String? title;
  String? accTitle;
  String? accDescr;

  /// Every name used as an entity, in order of first appearance. Names that
  /// turn out to be subgraph ids are dropped when building.
  final Map<String, ErEntity> entities = {};

  /// Innermost subgraph each entity was first mentioned in.
  final Map<String, String> membership = {};

  final List<ErSubgraph> stack = [];
  final Map<String, ErSubgraph> subgraphs = {};
  final Map<String, ErSubgraph> closed = {};
  final List<ErRelationship> relationships = [];
  final Map<String, FlowStyle> classDefs = {};
  final Map<String, List<String>> classesOf = {};
  final Map<String, FlowStyle> styleOf = {};

  ErDiagram? read(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var i = 0;
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i < lines.length && lines[i].trim() == '---') {
      final close = lines.indexWhere((line) => line.trim() == '---', i + 1);
      if (close > 0) {
        _frontMatter(lines.sublist(i + 1, close));
        i = close + 1;
      }
    }

    var foundHeader = false;
    final statements = <String>[];
    for (; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('%%')) continue;
      final header = ErDiagramParser._header.matchAsPrefix(line);
      if (header == null) return null;
      foundHeader = true;
      final rest = line.substring(header.end).trim();
      if (rest.isNotEmpty && rest != ';') statements.add(rest);
      i++;
      break;
    }
    if (!foundHeader) return null;

    while (i < lines.length) {
      var statement = lines[i++].trim();
      if (statement.isEmpty || statement.startsWith('%%')) continue;
      // Attribute blocks (and `accDescr { }`) may span several lines.
      final open = _blockStart(statement);
      if (open >= 0) {
        while (_blockEnd(statement, open) < 0 && i < lines.length) {
          statement = '$statement\n${lines[i++]}';
        }
      }
      statements.add(statement);
    }

    for (final statement in statements) {
      _statement(statement);
    }
    while (stack.isNotEmpty) {
      _closeSubgraph();
    }
    return _build();
  }

  void _frontMatter(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(r'^title:\s*(.*)$').firstMatch(line);
      if (match != null) {
        final value = _decodeText(match.group(1)!.trim().replaceAll("'", '"'));
        if (value.isNotEmpty) title = value;
      }
    }
  }

  static final RegExp _subgraph = RegExp(r'^subgraph(?:\s+(.*))?$');
  static final RegExp _direction = RegExp(
    r'^direction\s+(TB|TD|BT|LR|RL)\s*;?$',
    caseSensitive: false,
  );
  static final RegExp _accTitle = RegExp(r'^accTitle\s*:\s*(.*)$');
  static final RegExp _accDescr = RegExp(r'^accDescr\s*:\s*(.*)$');
  static final RegExp _accDescrBlock = RegExp(r'^accDescr\s*\{([\s\S]*?)\}?$');
  static final RegExp _classDef = RegExp(r'^classDef\s+(\S+)\s+(\S.*:.*)$');
  static final RegExp _class = RegExp(r'^class\s+(\S+)\s+([\w,-]+)\s*;?$');
  static final RegExp _style = RegExp(r'^style\s+(\S+)\s+(\S.*:.*)$');

  void _statement(String text) {
    if (text == 'end' || text == 'end;') {
      if (stack.isNotEmpty) _closeSubgraph();
      return;
    }
    RegExpMatch? match;
    if ((match = _subgraph.firstMatch(text)) != null) {
      _openSubgraph(match!.group(1) ?? '');
    } else if ((match = _direction.firstMatch(text)) != null) {
      final value = _directionOf(match!.group(1)!.toUpperCase());
      if (stack.isEmpty) {
        direction = value;
      } else {
        stack.last.direction = value;
      }
    } else if ((match = _accTitle.firstMatch(text)) != null) {
      accTitle = match!.group(1)!.trim();
    } else if ((match = _accDescr.firstMatch(text)) != null) {
      accDescr = match!.group(1)!.trim();
    } else if ((match = _accDescrBlock.firstMatch(text)) != null) {
      accDescr = match!
          .group(1)!
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join(' ');
    } else if ((match = _classDef.firstMatch(text)) != null) {
      final style = FlowStyle.parse(_stripSemicolon(match!.group(2)!));
      for (final name in match.group(1)!.split(',')) {
        if (name.isNotEmpty) classDefs[name] = style;
      }
    } else if ((match = _class.firstMatch(text)) != null) {
      final names = match!.group(2)!.split(',').where((n) => n.isNotEmpty);
      for (final id in match.group(1)!.split(',')) {
        if (id.isNotEmpty) classesOf.putIfAbsent(id, () => []).addAll(names);
      }
    } else if ((match = _style.firstMatch(text)) != null) {
      final style = FlowStyle.parse(_stripSemicolon(match!.group(2)!));
      for (final id in match.group(1)!.split(',')) {
        if (id.isEmpty) continue;
        styleOf[id] = (styleOf[id] ?? const FlowStyle()).merge(style);
      }
    } else {
      _entityOrRelationship(text);
    }
  }

  static String _stripSemicolon(String text) {
    final trimmed = text.trim();
    return trimmed.endsWith(';')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static ErDirection _directionOf(String value) => switch (value) {
        'BT' => ErDirection.bottomUp,
        'LR' => ErDirection.leftRight,
        'RL' => ErDirection.rightLeft,
        _ => ErDirection.topDown,
      };

  // -- Subgraphs -------------------------------------------------------------

  void _openSubgraph(String header) {
    final text = header.trim();
    String id;
    String title;
    final bracket = RegExp(r'^([^\s\[]+)\s*\[(.*)\]$').firstMatch(text);
    if (bracket != null) {
      id = bracket.group(1)!;
      title = _decodeText(bracket.group(2)!);
    } else if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      id = text.substring(1, text.length - 1);
      title = _decodeText(text);
    } else if (text.isEmpty) {
      id = 'subgraph${subgraphs.length}';
      title = '';
    } else {
      id = text;
      title = _decodeText(text);
    }
    final subgraph = ErSubgraph(id, title)
      ..parent = stack.isEmpty ? null : stack.last.id;
    subgraphs[id] = subgraph;
    stack.add(subgraph);
  }

  void _closeSubgraph() {
    final subgraph = stack.removeLast();
    closed[subgraph.id] = subgraph;
  }

  // -- Entities and relationships --------------------------------------------

  void _entityOrRelationship(String text) {
    final scanner = _Scanner(text);
    final first = _readRef(scanner);
    if (first == null) return;
    scanner.skipSpaces();

    final operator = _readOperator(scanner);
    if (operator != null) {
      final second = _readRef(scanner);
      if (second == null) return;
      scanner.skipSpaces();
      var label = '';
      if (scanner.current == ':') {
        label = _decodeText(text.substring(scanner.index + 1));
      }
      _mention(first);
      _mention(second);
      relationships.add(
        ErRelationship(
          from: first.id,
          to: second.id,
          fromCardinality: operator.$1,
          identifying: operator.$2,
          toCardinality: operator.$3,
          label: label,
        ),
      );
      return;
    }

    // A lone entity, optionally followed by its attribute block. Anything
    // else is a statement this parser does not know (`click`...).
    if (!scanner.done && scanner.current != '{') return;
    _mention(first);
    if (scanner.current == '{') {
      final end = _blockEnd(text, scanner.index);
      final content =
          text.substring(scanner.index + 1, end < 0 ? text.length : end);
      entities[first.id]!.attributes.addAll(_attributes(content));
    }
  }

  void _mention(_Ref ref) {
    final entity = entities.putIfAbsent(ref.id, () => ErEntity(ref.id));
    final label = ref.label;
    if (label != null) entity.label = label;
    if (ref.classes.isNotEmpty) {
      classesOf.putIfAbsent(ref.id, () => []).addAll(ref.classes);
    }
    if (stack.isNotEmpty) membership.putIfAbsent(ref.id, () => stack.last.id);
  }

  static bool _isNameChar(_Scanner scanner) {
    final char = scanner.current;
    if (char.isEmpty || _isSpace(char)) return false;
    if ('[]{}|:,";'.contains(char)) return false;
    if (char == '-' && scanner.at(1) == '-') return false;
    if (char == '.' && scanner.at(1) == '.') return false;
    return true;
  }

  _Ref? _readRef(_Scanner scanner) {
    scanner.skipSpaces();
    String id;
    String? label;
    if (scanner.current == '"') {
      final close = scanner.text.indexOf('"', scanner.index + 1);
      if (close < 0) return null;
      id = scanner.text.substring(scanner.index + 1, close);
      label = _decodeText(id);
      scanner.index = close + 1;
    } else {
      final start = scanner.index;
      while (_isNameChar(scanner)) {
        scanner.index++;
      }
      if (scanner.index == start) return null;
      id = scanner.text.substring(start, scanner.index);
    }
    if (id.trim().isEmpty) return null;

    if (scanner.current == '[') {
      final close = scanner.text.indexOf(']', scanner.index + 1);
      if (close > 0) {
        label = _decodeText(scanner.text.substring(scanner.index + 1, close));
        scanner.index = close + 1;
      }
    }

    var classes = const <String>[];
    if (scanner.startsWith(':::')) {
      scanner.index += 3;
      final start = scanner.index;
      while (!scanner.done &&
          !_isSpace(scanner.current) &&
          scanner.current != '{' &&
          scanner.current != ':') {
        scanner.index++;
      }
      classes = scanner.text
          .substring(start, scanner.index)
          .split(',')
          .where((name) => name.isNotEmpty)
          .toList();
    }
    return _Ref(id, label: label, classes: classes);
  }

  /// Reads `<cardinality> <identification> <cardinality>`, for example
  /// `||--o{` or `only one optionally to zero or more`. Leaves the scanner
  /// untouched and returns `null` when there is no relationship operator.
  (ErCardinality, bool, ErCardinality)? _readOperator(_Scanner scanner) {
    final start = scanner.index;
    final from = _readCardinality(scanner);
    if (from == null) return null;
    scanner.skipSpaces();

    bool identifying;
    Match? word;
    if (scanner.startsWith('--')) {
      identifying = true;
      scanner.index += 2;
    } else if (scanner.startsWith('..')) {
      identifying = false;
      scanner.index += 2;
    } else if ((word =
            _optionallyTo.matchAsPrefix(scanner.text, scanner.index)) !=
        null) {
      identifying = false;
      scanner.index = word!.end;
    } else if ((word = _to.matchAsPrefix(scanner.text, scanner.index)) !=
        null) {
      identifying = true;
      scanner.index = word!.end;
    } else {
      scanner.index = start;
      return null;
    }
    scanner.skipSpaces();

    final to = _readCardinality(scanner);
    if (to == null) {
      scanner.index = start;
      return null;
    }
    return (from, identifying, to);
  }

  ErCardinality? _readCardinality(_Scanner scanner) {
    final match =
        _symbolCardinality.matchAsPrefix(scanner.text, scanner.index) ??
            _wordCardinality.matchAsPrefix(scanner.text, scanner.index);
    if (match == null) return null;
    scanner.index = match.end;
    return _cardinalityOf(match.group(0)!);
  }

  // -- Attributes ------------------------------------------------------------

  static List<ErAttribute> _attributes(String content) {
    final tokens = _tokenize(content);
    final attributes = <ErAttribute>[];
    var i = 0;
    while (i < tokens.length) {
      final type = tokens[i++];
      if (type.quoted || type.text == ',') continue;
      if (i >= tokens.length || tokens[i].quoted || tokens[i].text == ',') {
        break;
      }
      final name = tokens[i++].text;

      final keys = <ErAttributeKey>[];
      while (i < tokens.length && !tokens[i].quoted) {
        final token = tokens[i].text;
        final key = _keys[token];
        if (key != null) {
          keys.add(key);
          i++;
        } else if (token == ',' &&
            i + 1 < tokens.length &&
            _keys.containsKey(tokens[i + 1].text)) {
          i++;
        } else {
          break;
        }
      }

      String? comment;
      if (i < tokens.length && tokens[i].quoted) {
        comment = tokens[i++].text;
      }

      attributes.add(
        ErAttribute(
          type: type.text.replaceAllMapped(
            RegExp(r'~([^~]*)~'),
            (match) => '<${match.group(1)}>',
          ),
          name: name,
          keys: keys,
          comment: comment,
        ),
      );
    }
    return attributes;
  }

  /// Splits an attribute block into words, quoted comments and commas.
  /// Parentheses group their content, so `decimal(10, 2)` is one word.
  static List<({String text, bool quoted})> _tokenize(String content) {
    final tokens = <({String text, bool quoted})>[];
    var i = 0;
    while (i < content.length) {
      final char = content[i];
      if (_isSpace(char) || char == ';') {
        i++;
      } else if (char == '"') {
        var close = content.indexOf('"', i + 1);
        if (close < 0) close = content.length;
        tokens.add(
            (text: _decodeText(content.substring(i + 1, close)), quoted: true));
        i = close + 1;
      } else if (char == ',') {
        tokens.add((text: ',', quoted: false));
        i++;
      } else {
        final start = i;
        var depth = 0;
        while (i < content.length) {
          final c = content[i];
          if (c == '(') depth++;
          if (c == ')' && depth > 0) depth--;
          if (depth == 0 && (_isSpace(c) || c == ',' || c == '"')) break;
          i++;
        }
        tokens.add((
          text: content.substring(start, i).replaceAll(RegExp(r'\s+'), ' '),
          quoted: false,
        ));
      }
    }
    return tokens;
  }

  // -- Result ----------------------------------------------------------------

  ErDiagram? _build() {
    final result = <String, ErEntity>{};
    for (final entity in entities.values) {
      // Subgraph ids used as relationship endpoints are not entities.
      if (subgraphs.containsKey(entity.id)) continue;
      entity.subgraph = membership[entity.id];
      result[entity.id] = entity;
    }
    if (result.isEmpty) return null;

    for (final entity in result.values) {
      final subgraph = subgraphs[entity.subgraph];
      if (subgraph != null) subgraph.entityIds.add(entity.id);
    }
    for (final subgraph in closed.values) {
      subgraphs[subgraph.parent]?.childIds.add(subgraph.id);
    }

    for (final MapEntry(key: id, value: classes) in classesOf.entries) {
      result[id]?.classes.addAll(classes);
      subgraphs[id]?.classes.addAll(classes);
    }
    for (final MapEntry(key: id, value: style) in styleOf.entries) {
      final entity = result[id];
      if (entity != null) entity.style = entity.style.merge(style);
      final subgraph = subgraphs[id];
      if (subgraph != null) subgraph.style = subgraph.style.merge(style);
    }

    return ErDiagram(
      direction: direction,
      entities: result,
      relationships: relationships,
      subgraphs: closed,
      classDefs: classDefs,
      title: title,
      accessibilityTitle: accTitle,
      accessibilityDescription: accDescr,
    );
  }
}

/// Index of the `{` that opens an attribute block (or `accDescr { }`) in
/// [text], or -1. Braces that belong to cardinality markers (`o{`, `|{`) and
/// anything after the relationship label's `:` are ignored.
int _blockStart(String text) {
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      quoted = !quoted;
      continue;
    }
    if (quoted) continue;
    if (text.startsWith(':::', i)) {
      i += 2;
    } else if (char == ':') {
      return -1;
    } else if (char == '{') {
      final previous = i > 0 ? text[i - 1] : ' ';
      if (previous != 'o' && previous != '|') return i;
    }
  }
  return -1;
}

/// Index of the `}` closing the block opened at [open], or -1.
int _blockEnd(String text, int open) {
  var quoted = false;
  for (var i = open + 1; i < text.length; i++) {
    final char = text[i];
    if (char == '"') quoted = !quoted;
    if (!quoted && char == '}') return i;
  }
  return -1;
}

/// Turns label source into display text: drops quotes and Markdown-string
/// backticks, turns `<br>` into line breaks, strips other HTML tags and
/// decodes Mermaid (`#quot;`) and HTML (`&amp;`) entities. Markdown emphasis
/// is kept; the painter renders it.
String _decodeText(String raw) {
  var text = raw.trim();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    text = text.substring(1, text.length - 1);
  }
  if (text.length >= 2 && text.startsWith('`') && text.endsWith('`')) {
    text = text.substring(1, text.length - 1);
  }

  text = text
      .replaceAll(r'\"', '"')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</?[A-Za-z][^>]*>'), '');

  text = text.replaceAllMapped(RegExp(r'[#&](#?)(\w+);'), (match) {
    final name = match.group(2)!;
    if (match.group(1)!.isNotEmpty || RegExp(r'^\d+$').hasMatch(name)) {
      final code = int.tryParse(name);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    return switch (name) {
      'quot' => '"',
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'nbsp' => ' ',
      'apos' => "'",
      _ => match.group(0)!,
    };
  });

  return text
      .split('\n')
      .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
      .join('\n')
      .trim();
}

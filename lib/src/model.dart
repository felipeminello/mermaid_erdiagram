import 'package:mermaid_flowchart/mermaid_flowchart.dart' show FlowStyle;

/// Direction in which the ranks of an ER diagram advance.
enum ErDirection {
  /// `TB` / `TD`: ranks go downwards. The default.
  topDown,

  /// `BT`: ranks go upwards.
  bottomUp,

  /// `LR`: ranks go to the right.
  leftRight,

  /// `RL`: ranks go to the left.
  rightLeft,
}

/// How many instances of an entity take part in a relationship, drawn with
/// crow's foot notation at that entity's end of the line.
enum ErCardinality {
  /// `|o` / `o|`, `zero or one`, `one or zero`: a circle and a bar.
  zeroOrOne,

  /// `||`, `only one`, `1`: two bars.
  exactlyOne,

  /// `}o` / `o{`, `zero or more`, `zero or many`, `many(0)`, `0+`: a
  /// circle and a crow's foot.
  zeroOrMore,

  /// `}|` / `|{`, `one or more`, `one or many`, `many(1)`, `1+`: a bar and
  /// a crow's foot.
  oneOrMore;

  /// Whether the minimum is zero.
  bool get isOptional => this == zeroOrOne || this == zeroOrMore;

  /// Whether there is no upper limit.
  bool get isMany => this == zeroOrMore || this == oneOrMore;
}

/// A key marker of an attribute.
enum ErAttributeKey {
  /// `PK`: primary key.
  primary('PK'),

  /// `FK`: foreign key.
  foreign('FK'),

  /// `UK`: unique key.
  unique('UK');

  const ErAttributeKey(this.label);

  /// The marker as written in the source and shown in the diagram.
  final String label;
}

/// A `type name [keys] ["comment"]` line of an entity's attribute block.
class ErAttribute {
  /// Creates an attribute.
  const ErAttribute({
    required this.type,
    required this.name,
    this.keys = const [],
    this.comment,
  });

  /// The type, as written (`string`, `int`, `varchar(255)`, `string[]`...).
  /// Generic types written `List~T~` are turned into `List<T>`.
  final String type;

  /// The name, as written. A leading `*` is kept.
  final String name;

  /// `PK`, `FK` and `UK` markers, in source order.
  final List<ErAttributeKey> keys;

  /// The quoted comment at the end of the line, without the quotes.
  final String? comment;
}

/// An entity: a box with a name and, optionally, a table of attributes.
class ErEntity {
  /// Creates an entity whose label is its [id] until an alias is set.
  ErEntity(this.id) : label = id;

  /// The name used to reference the entity in the source.
  final String id;

  /// Text shown in the header: the alias (`p[Person]`) or the name.
  /// Supports `**bold**` and `_italic_` Markdown; `\n` separates lines.
  String label;

  /// Attributes in source order. Several blocks for the same entity are
  /// concatenated.
  final List<ErAttribute> attributes = [];

  /// Id of the subgraph that directly contains the entity, if any.
  String? subgraph;

  /// Classes assigned with `:::` or `class`.
  final List<String> classes = [];

  /// The entity's own `style` statement.
  FlowStyle style = const FlowStyle();
}

/// A relationship line between two entities (or subgraphs).
class ErRelationship {
  /// Creates a relationship.
  const ErRelationship({
    required this.from,
    required this.to,
    required this.fromCardinality,
    required this.toCardinality,
    this.identifying = true,
    this.label = '',
  });

  /// Id of the first entity of the statement.
  final String from;

  /// Id of the second entity of the statement.
  final String to;

  /// Cardinality drawn at the [from] end (the left marker in the source).
  final ErCardinality fromCardinality;

  /// Cardinality drawn at the [to] end (the right marker in the source).
  final ErCardinality toCardinality;

  /// `--` / `to` (solid line) when true, `..` / `optionally to` (dashed
  /// line) when false.
  final bool identifying;

  /// Text written after the `:`, from the perspective of [from]. Empty when
  /// the relationship has no label.
  final String label;
}

/// A `subgraph ... end` block grouping entities.
class ErSubgraph {
  /// Creates an empty subgraph.
  ErSubgraph(this.id, this.title);

  /// The id used to reference the subgraph in relationships and styles.
  final String id;

  /// Text shown at the top of the box.
  final String title;

  /// Id of the enclosing subgraph, if any.
  String? parent;

  /// Entities directly inside this subgraph (not inside a nested one).
  final List<String> entityIds = [];

  /// Subgraphs directly nested in this one.
  final List<String> childIds = [];

  /// The `direction` statement written inside the subgraph, if any. The
  /// layout currently uses the diagram's direction everywhere.
  ErDirection? direction;

  /// Classes assigned with `class`.
  final List<String> classes = [];

  /// The subgraph's own `style` statement.
  FlowStyle style = const FlowStyle();
}

/// A parsed Mermaid entity relationship diagram (`erDiagram`).
class ErDiagram {
  /// Creates a diagram. Usually obtained from `ErDiagramParser.parse`
  /// rather than built by hand.
  ErDiagram({
    required this.direction,
    required this.entities,
    required this.relationships,
    required this.subgraphs,
    required this.classDefs,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
  });

  /// Direction in which ranks advance.
  final ErDirection direction;

  /// Entities in order of first appearance.
  final Map<String, ErEntity> entities;

  /// Relationships in source order.
  final List<ErRelationship> relationships;

  /// Subgraphs in the order they are closed: nested ones come before the
  /// subgraph that contains them.
  final Map<String, ErSubgraph> subgraphs;

  /// `classDef` statements by class name.
  final Map<String, FlowStyle> classDefs;

  /// The `title` of the front matter, drawn above the diagram.
  final String? title;

  /// The `accTitle` statement.
  final String? accessibilityTitle;

  /// The `accDescr` statement.
  final String? accessibilityDescription;

  /// The effective style of [entity]: the `default` class, then its
  /// classes, then its own `style` statement.
  FlowStyle entityStyle(ErEntity entity) =>
      _resolve(['default', ...entity.classes], entity.style);

  /// The effective style of [subgraph]: its classes, then its own `style`.
  FlowStyle subgraphStyle(ErSubgraph subgraph) =>
      _resolve(subgraph.classes, subgraph.style);

  FlowStyle _resolve(List<String> classes, FlowStyle own) {
    var style = const FlowStyle();
    for (final name in classes) {
      final classStyle = classDefs[name];
      if (classStyle != null) style = style.merge(classStyle);
    }
    return style.merge(own);
  }
}

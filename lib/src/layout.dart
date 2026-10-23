import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;
import 'package:mermaid_flowchart/mermaid_flowchart.dart';

import 'model.dart';

/// Which piece of text is being measured, so the measurer can apply the
/// matching style.
enum ErTextRole {
  /// An entity name in a table header.
  entityName,

  /// An attribute type, name, key list or comment.
  attribute,

  /// A relationship label.
  relationshipLabel,

  /// A subgraph title.
  subgraphTitle,

  /// The diagram title.
  title,
}

/// Returns the size [text] takes when painted in the style of [role].
typedef ErTextMeasurer = Size Function(String text, ErTextRole role);

/// Spacing used by [ErDiagramLayout], in logical pixels.
@immutable
class ErLayoutConfig {
  /// Creates a spacing configuration. The defaults suit 13–14 px text.
  const ErLayoutConfig({
    this.cellPaddingX = 12,
    this.cellPaddingY = 8,
    this.entityMinWidth = 100,
    this.emptyEntityPaddingX = 24,
    this.emptyEntityMinHeight = 56,
    this.rankSeparation = 50,
    this.entitySeparation = 48,
    this.portSeparation = 36,
    this.markerClearance = 40,
    this.trackSeparation = 12,
    this.subgraphPadding = 20,
    this.subgraphTitleGap = 6,
    this.labelPaddingX = 4,
    this.labelPaddingY = 2,
    this.selfLoopSize = 52,
    this.titleGap = 12,
    this.diagramPadding = 8,
  });

  /// Horizontal space between a table cell's border and its text.
  final double cellPaddingX;

  /// Vertical space between a table cell's border and its text.
  final double cellPaddingY;

  /// Minimum width of an entity.
  final double entityMinWidth;

  /// Horizontal space around the name of an entity without attributes.
  final double emptyEntityPaddingX;

  /// Minimum height of an entity without attributes.
  final double emptyEntityMinHeight;

  /// Minimum gap between two ranks (rows in TB, columns in LR). Gaps where
  /// lines bend grow to twice [markerClearance].
  final double rankSeparation;

  /// Gap between neighbouring entities inside a rank.
  final double entitySeparation;

  /// Distance between relationships that meet the same side of an entity.
  final double portSeparation;

  /// Minimum length of the straight segment next to an entity before a
  /// bend, which holds the cardinality marker.
  final double markerClearance;

  /// Distance between parallel line segments in a gap.
  final double trackSeparation;

  /// Space between a subgraph's border and its content.
  final double subgraphPadding;

  /// Space above and below a subgraph's title.
  final double subgraphTitleGap;

  /// Horizontal space between a relationship label and its background.
  final double labelPaddingX;

  /// Vertical space between a relationship label and its background.
  final double labelPaddingY;

  /// How far a relationship from an entity to itself sticks out.
  final double selfLoopSize;

  /// Space between the diagram title and the diagram.
  final double titleGap;

  /// Empty space around the whole diagram.
  final double diagramPadding;

  /// The configuration handed to the flowchart layout that positions the
  /// entities and routes the relationships.
  FlowLayoutConfig get flowConfig => FlowLayoutConfig(
        nodeMinWidth: 0,
        nodeMinHeight: 0,
        nodePaddingX: 0,
        nodePaddingY: 0,
        rankSeparation: rankSeparation,
        nodeSeparation: entitySeparation,
        edgeSeparation: trackSeparation,
        clusterPadding: subgraphPadding,
        clusterTitleGap: subgraphTitleGap,
        trackSeparation: trackSeparation,
        trackMargin: markerClearance,
        portSeparation: portSeparation,
        labelPaddingX: labelPaddingX,
        labelPaddingY: labelPaddingY,
        diagramPadding: diagramPadding,
      );

  @override
  bool operator ==(Object other) =>
      other is ErLayoutConfig &&
      other.cellPaddingX == cellPaddingX &&
      other.cellPaddingY == cellPaddingY &&
      other.entityMinWidth == entityMinWidth &&
      other.emptyEntityPaddingX == emptyEntityPaddingX &&
      other.emptyEntityMinHeight == emptyEntityMinHeight &&
      other.rankSeparation == rankSeparation &&
      other.entitySeparation == entitySeparation &&
      other.portSeparation == portSeparation &&
      other.markerClearance == markerClearance &&
      other.trackSeparation == trackSeparation &&
      other.subgraphPadding == subgraphPadding &&
      other.subgraphTitleGap == subgraphTitleGap &&
      other.labelPaddingX == labelPaddingX &&
      other.labelPaddingY == labelPaddingY &&
      other.selfLoopSize == selfLoopSize &&
      other.titleGap == titleGap &&
      other.diagramPadding == diagramPadding;

  @override
  int get hashCode => Object.hashAll([
        cellPaddingX,
        cellPaddingY,
        entityMinWidth,
        emptyEntityPaddingX,
        emptyEntityMinHeight,
        rankSeparation,
        entitySeparation,
        portSeparation,
        markerClearance,
        trackSeparation,
        subgraphPadding,
        subgraphTitleGap,
        labelPaddingX,
        labelPaddingY,
        selfLoopSize,
        titleGap,
        diagramPadding,
      ]);
}

/// Where an entity's table is drawn, and how it is divided.
class ErEntityBox {
  /// Creates a positioned entity table.
  const ErEntityBox({
    required this.entity,
    required this.index,
    required this.rect,
    required this.headerHeight,
    required this.rowHeight,
    required this.columnWidths,
    required this.rows,
  });

  /// The entity the table belongs to.
  final ErEntity entity;

  /// Position among the diagram's entities, used to pick a palette color.
  final int index;

  /// The whole table.
  final Rect rect;

  /// Height of the header holding the entity name. Equals the height of
  /// [rect] when the entity has no attributes.
  final double headerHeight;

  /// Height of each attribute row.
  final double rowHeight;

  /// Widths of the attribute columns: type, name, then keys and comment
  /// when any attribute of the entity has them. Empty without attributes.
  final List<double> columnWidths;

  /// Text of every cell, one list per attribute, matching [columnWidths].
  final List<List<String>> rows;

  /// The header band.
  Rect get headerRect =>
      Rect.fromLTWH(rect.left, rect.top, rect.width, headerHeight);

  /// The cell at [row] and [column].
  Rect cellRect(int row, int column) {
    var left = rect.left;
    for (var i = 0; i < column; i++) {
      left += columnWidths[i];
    }
    return Rect.fromLTWH(
      left,
      rect.top + headerHeight + row * rowHeight,
      columnWidths[column],
      rowHeight,
    );
  }

  /// A copy moved by [offset].
  ErEntityBox shift(Offset offset) => ErEntityBox(
        entity: entity,
        index: index,
        rect: rect.shift(offset),
        headerHeight: headerHeight,
        rowHeight: rowHeight,
        columnWidths: columnWidths,
        rows: rows,
      );
}

/// Where a subgraph's box is drawn.
class ErSubgraphBox {
  /// Creates a positioned subgraph box.
  const ErSubgraphBox({
    required this.subgraph,
    required this.rect,
    required this.depth,
  });

  /// The subgraph the box belongs to.
  final ErSubgraph subgraph;

  /// The box, title band included.
  final Rect rect;

  /// Nesting depth: 0 for a top-level subgraph.
  final int depth;
}

/// The path of a relationship line.
class ErRelationshipRoute {
  /// Creates a routed relationship.
  const ErRelationshipRoute({
    required this.relationship,
    required this.points,
    this.labelRect,
  });

  /// The relationship being routed.
  final ErRelationship relationship;

  /// Orthogonal polyline from `relationship.from` to `relationship.to`. The
  /// first and last points lie on the outlines of the endpoints, where the
  /// cardinality markers are drawn.
  final List<Offset> points;

  /// Where the label goes, if the relationship has one.
  final Rect? labelRect;
}

/// Positions of every entity table, subgraph box and relationship of an
/// [ErDiagram].
///
/// Each entity is first measured as a table (a header with its name and one
/// row per attribute). The tables are then positioned by the layered layout
/// of `mermaid_flowchart` ([FlowchartLayout]), which keeps subgraphs
/// together, gives labelled relationships a lane of their own and routes the
/// lines orthogonally. Relationships from an entity to itself are drawn as
/// loops on the side of the table.
class ErDiagramLayout {
  /// Creates a layout from precomputed positions. Use
  /// [ErDiagramLayout.compute] to lay a diagram out.
  const ErDiagramLayout({
    required this.size,
    required this.entities,
    required this.subgraphs,
    required this.relationships,
    this.titleRect,
  });

  /// Lays [diagram] out, measuring its text with [measure] (for example
  /// `ErTextStyles.measure`).
  factory ErDiagramLayout.compute(
    ErDiagram diagram,
    ErTextMeasurer measure, {
    ErLayoutConfig config = const ErLayoutConfig(),
  }) =>
      _LayoutBuilder(diagram, measure, config).build();

  /// Size of the whole diagram, padding included.
  final Size size;

  /// Every entity's table, by entity id.
  final Map<String, ErEntityBox> entities;

  /// Subgraph boxes, outermost first so they can be painted in order.
  final List<ErSubgraphBox> subgraphs;

  /// Every relationship, in the order of [ErDiagram.relationships].
  /// Relationships whose endpoints do not exist are left out.
  final List<ErRelationshipRoute> relationships;

  /// Where the diagram title goes, if the diagram has one.
  final Rect? titleRect;
}

class _LayoutBuilder {
  _LayoutBuilder(this.diagram, this.measure, this.config);

  final ErDiagram diagram;
  final ErTextMeasurer measure;
  final ErLayoutConfig config;

  ErDiagramLayout build() {
    final tables = <String, ErEntityBox>{};
    for (final (index, entity) in diagram.entities.values.indexed) {
      tables[entity.id] = _table(entity, index);
    }

    // Each entity becomes a rectangle node whose "label" is its id, measured
    // as the size of its table (the node padding is zero).
    final nodes = <String, FlowNode>{};
    for (final entity in diagram.entities.values) {
      nodes[entity.id] = FlowNode(entity.id)
        ..isDefined = true
        ..subgraph = entity.subgraph;
    }
    final edges = <FlowEdge>[];
    final relationshipOf = Map<FlowEdge, ErRelationship>.identity();
    final loops = <ErRelationship>[];
    for (final relationship in diagram.relationships) {
      if (relationship.from == relationship.to &&
          tables.containsKey(relationship.from)) {
        loops.add(relationship);
        continue;
      }
      final edge = FlowEdge(
        from: relationship.from,
        to: relationship.to,
        label: relationship.label.isEmpty ? null : relationship.label,
        line: relationship.identifying
            ? FlowLineStyle.solid
            : FlowLineStyle.dotted,
        endHead: FlowArrowHead.none,
        // Two ranks leave room for a marker at each end; labelled edges get
        // them anyway.
        length: 2,
      );
      relationshipOf[edge] = relationship;
      edges.add(edge);
    }
    // Self loops stick out of one side of their entity; the node is widened
    // on both sides by that much so neighbours keep clear and the table
    // stays centered under its ports.
    final reaches = _loopReaches(loops);
    final extents = <String, double>{};
    for (final relationship in loops) {
      final label = _loopLabelSize(relationship);
      final extent = reaches[relationship]! +
          (label == null ? 0 : (_sideways ? label.height : label.width) + 4) +
          config.trackSeparation;
      extents[relationship.from] =
          math.max(extents[relationship.from] ?? 0, extent);
    }
    Size nodeSize(String id) {
      final size = tables[id]!.rect.size;
      final extent = extents[id] ?? 0;
      return _sideways
          ? Size(size.width, size.height + extent * 2)
          : Size(size.width + extent * 2, size.height);
    }

    final subgraphs = <String, FlowSubgraph>{};
    for (final subgraph in diagram.subgraphs.values) {
      subgraphs[subgraph.id] = FlowSubgraph(subgraph.id, subgraph.title)
        ..parent = subgraph.parent
        ..nodeIds.addAll(subgraph.entityIds)
        ..childIds.addAll(subgraph.childIds);
    }
    final chart = Flowchart(
      direction: switch (diagram.direction) {
        ErDirection.topDown => FlowDirection.topDown,
        ErDirection.bottomUp => FlowDirection.bottomUp,
        ErDirection.leftRight => FlowDirection.leftRight,
        ErDirection.rightLeft => FlowDirection.rightLeft,
      },
      nodes: nodes,
      edges: edges,
      subgraphs: subgraphs,
      classDefs: const {},
    );

    final flow = FlowchartLayout.compute(
      chart,
      (text, role) => switch (role) {
        FlowTextRole.node => nodeSize(text),
        FlowTextRole.edgeLabel => measure(text, ErTextRole.relationshipLabel),
        FlowTextRole.clusterTitle => measure(text, ErTextRole.subgraphTitle),
      },
      config: config.flowConfig,
    );

    final entities = <String, ErEntityBox>{
      for (final MapEntry(key: id, value: table) in tables.entries)
        id: table.shift(
          flow.nodeRects[id]!.center - table.rect.center,
        ),
    };
    final boxes = [
      for (final cluster in flow.clusters)
        ErSubgraphBox(
          subgraph: diagram.subgraphs[cluster.subgraph.id]!,
          rect: cluster.rect,
          depth: cluster.depth,
        ),
    ];
    // Where lines meet each entity, to keep ports apart when moving them.
    final ports = <String, List<Offset>>{};
    for (final route in flow.edges) {
      ports.putIfAbsent(route.edge.from, () => []).add(route.points.first);
      ports.putIfAbsent(route.edge.to, () => []).add(route.points.last);
    }
    final routed = Map<ErRelationship, ErRelationshipRoute>.identity();
    for (final route in flow.edges) {
      final relationship = relationshipOf[route.edge]!;
      var points = route.points;
      final from = entities[relationship.from]?.rect;
      if (from != null) {
        points = _removeJog(points, from, ports[relationship.from]!);
      }
      final to = entities[relationship.to]?.rect;
      if (to != null) {
        points = _removeJog(
          points.reversed.toList(),
          to,
          ports[relationship.to]!,
        ).reversed.toList();
      }
      routed[relationship] = ErRelationshipRoute(
        relationship: relationship,
        points: points,
        labelRect: route.labelRect,
      );
    }
    _routeLoops(loops, reaches, entities, routed);

    final routes = [
      for (final relationship in diagram.relationships)
        if (routed[relationship] case final route?) route,
    ];
    return _finish(flow.size, entities, boxes, routes);
  }

  /// Lines that leave an entity and step aside by a few pixels right away
  /// (`─┐_`) would bend inside the marker. When the step is short, slide
  /// the line's end along the entity's side instead, as long as it stays
  /// clear of the corners and of the other lines meeting that entity.
  List<Offset> _removeJog(List<Offset> points, Rect rect, List<Offset> ports) {
    if (points.length < 4) return points;
    final start = points[0];
    final step = points[2] - points[1];
    if (step.distance < 0.5 || step.distance > config.markerClearance / 2) {
      return points;
    }
    final moved = start + step;
    const margin = 12.0;
    final onSide = (start.dy - points[1].dy).abs() < 0.01
        ? moved.dy >= rect.top + margin && moved.dy <= rect.bottom - margin
        : moved.dx >= rect.left + margin && moved.dx <= rect.right - margin;
    if (!onSide) return points;
    for (final port in ports) {
      if (port != start &&
          (port - moved).distance < config.portSeparation * 0.75) {
        return points;
      }
    }
    ports
      ..remove(start)
      ..add(moved);
    return [moved, ...points.sublist(3)];
  }

  /// Measures [entity] as a table at the origin.
  ErEntityBox _table(ErEntity entity, int index) {
    final name = measure(entity.label, ErTextRole.entityName);
    final attributes = entity.attributes;
    if (attributes.isEmpty) {
      final width = math.max(
        config.entityMinWidth,
        name.width + config.emptyEntityPaddingX * 2,
      );
      final height = math.max(
        config.emptyEntityMinHeight,
        name.height + config.cellPaddingY * 4,
      );
      return ErEntityBox(
        entity: entity,
        index: index,
        rect: Rect.fromLTWH(0, 0, width, height),
        headerHeight: height,
        rowHeight: 0,
        columnWidths: const [],
        rows: const [],
      );
    }

    final hasKeys = attributes.any((attribute) => attribute.keys.isNotEmpty);
    final hasComments = attributes.any(
      (attribute) => attribute.comment?.isNotEmpty ?? false,
    );
    final rows = [
      for (final attribute in attributes)
        [
          attribute.type,
          attribute.name,
          if (hasKeys) attribute.keys.map((key) => key.label).join(','),
          if (hasComments) attribute.comment ?? '',
        ],
    ];

    final columns = rows.first.length;
    final widths = List.filled(columns, 0.0);
    var textHeight = 0.0;
    for (final row in rows) {
      for (final (column, text) in row.indexed) {
        if (text.isEmpty) continue;
        final size = measure(text, ErTextRole.attribute);
        widths[column] = math.max(widths[column], size.width);
        textHeight = math.max(textHeight, size.height);
      }
    }
    for (var column = 0; column < columns; column++) {
      widths[column] += config.cellPaddingX * 2;
    }

    // A header wider than the columns widens them evenly.
    final needed = math.max(
      config.entityMinWidth,
      name.width + config.cellPaddingX * 2,
    );
    final total = widths.reduce((a, b) => a + b);
    if (needed > total) {
      final extra = (needed - total) / columns;
      for (var column = 0; column < columns; column++) {
        widths[column] += extra;
      }
    }

    final headerHeight = name.height + config.cellPaddingY * 2;
    final rowHeight = textHeight + config.cellPaddingY * 2;
    return ErEntityBox(
      entity: entity,
      index: index,
      rect: Rect.fromLTWH(
        0,
        0,
        widths.reduce((a, b) => a + b),
        headerHeight + rowHeight * rows.length,
      ),
      headerHeight: headerHeight,
      rowHeight: rowHeight,
      columnWidths: widths,
      rows: rows,
    );
  }

  bool get _sideways =>
      diagram.direction == ErDirection.leftRight ||
      diagram.direction == ErDirection.rightLeft;

  /// How far each self loop sticks out: nested loops of the same entity
  /// step outwards.
  Map<ErRelationship, double> _loopReaches(List<ErRelationship> loops) {
    final count = <String, int>{};
    final reaches = Map<ErRelationship, double>.identity();
    for (final relationship in loops) {
      final nth =
          count[relationship.from] = (count[relationship.from] ?? 0) + 1;
      reaches[relationship] =
          config.selfLoopSize + (nth - 1) * config.trackSeparation * 2;
    }
    return reaches;
  }

  /// Half the distance between the two ends of a self loop on a side of
  /// [length]: far enough apart for two markers.
  static double _loopSpread(double length) =>
      math.min(math.max(length * 0.2, 15), length / 2 - 4);

  Size? _loopLabelSize(ErRelationship relationship) {
    if (relationship.label.isEmpty) return null;
    final label = measure(relationship.label, ErTextRole.relationshipLabel);
    return Size(
      label.width + config.labelPaddingX * 2,
      label.height + config.labelPaddingY * 2,
    );
  }

  /// Draws relationships from an entity to itself as loops: on the right of
  /// the table when ranks go up or down, below it when they go sideways.
  void _routeLoops(
    List<ErRelationship> loops,
    Map<ErRelationship, double> reaches,
    Map<String, ErEntityBox> entities,
    Map<ErRelationship, ErRelationshipRoute> routed,
  ) {
    final sideways = _sideways;
    for (final relationship in loops) {
      final rect = entities[relationship.from]!.rect;
      final reach = reaches[relationship]!;
      final labelSize = _loopLabelSize(relationship);

      List<Offset> points;
      Rect? labelRect;
      if (sideways) {
        final spread = _loopSpread(rect.width);
        final x1 = rect.center.dx - spread;
        final x2 = rect.center.dx + spread;
        final y = rect.bottom + reach;
        points = [
          Offset(x1, rect.bottom),
          Offset(x1, y),
          Offset(x2, y),
          Offset(x2, rect.bottom),
        ];
        if (labelSize != null) {
          labelRect = Rect.fromCenter(
            center: Offset((x1 + x2) / 2, y + 2 + labelSize.height / 2),
            width: labelSize.width,
            height: labelSize.height,
          );
        }
      } else {
        final spread = _loopSpread(rect.height);
        final y1 = rect.center.dy - spread;
        final y2 = rect.center.dy + spread;
        final x = rect.right + reach;
        points = [
          Offset(rect.right, y1),
          Offset(x, y1),
          Offset(x, y2),
          Offset(rect.right, y2),
        ];
        if (labelSize != null) {
          labelRect = Rect.fromCenter(
            center: Offset(x + 4 + labelSize.width / 2, (y1 + y2) / 2),
            width: labelSize.width,
            height: labelSize.height,
          );
        }
      }
      routed[relationship] = ErRelationshipRoute(
        relationship: relationship,
        points: points,
        labelRect: labelRect,
      );
    }
  }

  /// Adds the title, grows the canvas to hold self loops and moves
  /// everything so the diagram starts at the padding.
  ErDiagramLayout _finish(
    Size flowSize,
    Map<String, ErEntityBox> entities,
    List<ErSubgraphBox> boxes,
    List<ErRelationshipRoute> routes,
  ) {
    var bounds = Offset.zero & flowSize;
    for (final route in routes) {
      for (final point in route.points) {
        bounds =
            bounds.expandToInclude(Rect.fromCircle(center: point, radius: 10));
      }
      final label = route.labelRect;
      if (label != null) bounds = bounds.expandToInclude(label);
    }
    if (bounds.right > flowSize.width || bounds.bottom > flowSize.height) {
      bounds = Rect.fromLTRB(
        bounds.left,
        bounds.top,
        bounds.right + config.diagramPadding,
        bounds.bottom + config.diagramPadding,
      );
    }

    var shift = -bounds.topLeft;
    var size = bounds.size;
    Rect? titleRect;
    final title = diagram.title;
    if (title != null && title.isNotEmpty) {
      final text = measure(title, ErTextRole.title);
      final width =
          math.max(size.width, text.width + config.diagramPadding * 2);
      final top = config.diagramPadding;
      titleRect = Rect.fromLTWH(
        (width - text.width) / 2,
        top,
        text.width,
        text.height,
      );
      final down = top + text.height + config.titleGap - config.diagramPadding;
      shift += Offset((width - size.width) / 2, down);
      size = Size(width, size.height + down);
    }

    if (shift == Offset.zero) {
      return ErDiagramLayout(
        size: size,
        entities: entities,
        subgraphs: boxes,
        relationships: routes,
        titleRect: titleRect,
      );
    }
    return ErDiagramLayout(
      size: size,
      entities: {
        for (final MapEntry(key: id, value: box) in entities.entries)
          id: box.shift(shift),
      },
      subgraphs: [
        for (final box in boxes)
          ErSubgraphBox(
            subgraph: box.subgraph,
            rect: box.rect.shift(shift),
            depth: box.depth,
          ),
      ],
      relationships: [
        for (final route in routes)
          ErRelationshipRoute(
            relationship: route.relationship,
            points: [for (final point in route.points) point + shift],
            labelRect: route.labelRect?.shift(shift),
          ),
      ],
      titleRect: titleRect,
    );
  }
}

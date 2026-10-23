import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'model.dart';
import 'theme.dart';

/// Paints an [ErDiagramLayout]: subgraph boxes, then relationship lines
/// with their cardinality markers, then the entity tables and finally the
/// relationship labels and the title on top.
///
/// `MermaidErDiagram` wraps this painter; use it directly to draw an ER
/// diagram on your own canvas. [styles] and [config] must be the ones the
/// [layout] was computed with.
class ErDiagramPainter extends CustomPainter {
  /// Creates a painter for [diagram] positioned by [layout].
  ErDiagramPainter({
    required this.diagram,
    required this.layout,
    required this.styles,
    required this.palette,
    this.config = const ErLayoutConfig(),
  });

  /// The parsed diagram.
  final ErDiagram diagram;

  /// Positions computed by [ErDiagramLayout.compute].
  final ErDiagramLayout layout;

  /// Text styles the layout was measured with.
  final ErTextStyles styles;

  /// Colors.
  final ErPalette palette;

  /// Spacing the layout was computed with.
  final ErLayoutConfig config;

  static const double _lineWidth = 1.5;
  static const double _borderWidth = 1.5;
  static const double _gridWidth = 1;
  static const double _cornerRadius = 6;

  // Crow's foot geometry, measured from the entity's outline backwards
  // along the line (the same proportions as Mermaid's markers).
  static const double _barHalf = 9;
  static const double _circleRadius = 6;
  static const double _footLength = 18;
  static const double _footSpread = 9;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    for (final box in layout.subgraphs) {
      _paintSubgraph(canvas, box);
    }
    for (final route in layout.relationships) {
      _paintRelationship(canvas, route);
    }
    for (final box in layout.entities.values) {
      _paintEntity(canvas, box);
    }
    for (final route in layout.relationships) {
      _paintLabel(canvas, route);
    }
    _paintTitle(canvas);
  }

  void _paintSubgraph(Canvas canvas, ErSubgraphBox box) {
    final style = diagram.subgraphStyle(box.subgraph);
    canvas.drawRect(
      box.rect,
      Paint()..color = style.fill ?? palette.subgraphFill,
    );
    _strokePath(
      canvas,
      Path()..addRect(box.rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth ?? 1
        ..color = style.stroke ?? palette.subgraphStroke,
      style.dashArray,
    );

    final title = box.subgraph.title;
    if (title.isEmpty) return;
    final painter = styles.layout(
      title,
      ErTextRole.subgraphTitle,
      overrides: TextStyle(
        color: style.color ?? palette.subgraphText,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
      ),
    );
    painter.paint(
      canvas,
      Offset(
        box.rect.center.dx - painter.width / 2,
        box.rect.top + config.subgraphTitleGap,
      ),
    );
    painter.dispose();
  }

  void _paintRelationship(Canvas canvas, ErRelationshipRoute route) {
    final points = route.points;
    if (points.length < 2) return;
    final relationship = route.relationship;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth
      ..strokeCap = StrokeCap.butt
      ..color = palette.line;
    _strokePath(
      canvas,
      _roundedPath(points),
      stroke,
      relationship.identifying ? null : const [6, 4],
    );

    final fill = Paint()..color = palette.labelBackground;
    _paintMarker(
      canvas,
      points.first,
      points[1],
      relationship.fromCardinality,
      stroke,
      fill,
    );
    _paintMarker(
      canvas,
      points.last,
      points[points.length - 2],
      relationship.toCardinality,
      stroke,
      fill,
    );
  }

  /// Draws the crow's foot marker for [cardinality] where the line coming
  /// from [previous] meets an entity at [tip].
  void _paintMarker(
    Canvas canvas,
    Offset tip,
    Offset previous,
    ErCardinality cardinality,
    Paint stroke,
    Paint fill,
  ) {
    final length = (tip - previous).distance;
    if (length == 0) return;
    final direction = (tip - previous) / length;
    final normal = Offset(-direction.dy, direction.dx);
    Offset at(double back, double side) =>
        tip - direction * back + normal * side;

    final solid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth
      ..color = stroke.color;

    void bar(double back) =>
        canvas.drawLine(at(back, -_barHalf), at(back, _barHalf), solid);

    void circle(double back) {
      final center = at(back, 0);
      canvas
        ..drawCircle(center, _circleRadius, fill)
        ..drawCircle(center, _circleRadius, solid);
    }

    void foot() {
      // The line itself is the middle toe; two curved toes spread out to
      // meet the outline at right angles.
      final path = Path()..moveTo(tip.dx, tip.dy);
      final apex = at(_footLength, 0);
      path.lineTo(apex.dx, apex.dy);
      for (final side in const [-1.0, 1.0]) {
        final control = at(_footLength / 2, _footSpread * side);
        final end = at(0, _footSpread * side);
        path
          ..moveTo(apex.dx, apex.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      }
      canvas.drawPath(path, solid);
    }

    switch (cardinality) {
      case ErCardinality.exactlyOne:
        bar(9);
        bar(15);
      case ErCardinality.zeroOrOne:
        bar(9);
        circle(21);
      case ErCardinality.oneOrMore:
        foot();
        bar(24);
      case ErCardinality.zeroOrMore:
        foot();
        circle(28);
    }
  }

  void _paintEntity(Canvas canvas, ErEntityBox box) {
    final entity = box.entity;
    final style = diagram.entityStyle(entity);
    final fill = style.fill ??
        palette.entityFills[box.index % palette.entityFills.length];
    final strokeColor = style.stroke ??
        palette.entityStrokes[box.index % palette.entityStrokes.length];
    final textStyle = TextStyle(
      color: style.color ?? palette.text,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
    );
    final rect = box.rect;

    canvas.drawRect(rect, Paint()..color = fill);

    // Grid: below the header, between rows and between columns.
    if (box.rows.isNotEmpty) {
      final grid = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _gridWidth
        ..color = strokeColor;
      for (var row = 0; row < box.rows.length; row++) {
        final y = rect.top + box.headerHeight + row * box.rowHeight;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      }
      var x = rect.left;
      for (final width in box.columnWidths.take(box.columnWidths.length - 1)) {
        x += width;
        canvas.drawLine(
          Offset(x, rect.top + box.headerHeight),
          Offset(x, rect.bottom),
          grid,
        );
      }
    }

    _strokePath(
      canvas,
      Path()..addRect(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth ?? _borderWidth
        ..color = strokeColor,
      style.dashArray,
    );

    final name = styles.layout(
      entity.label,
      ErTextRole.entityName,
      overrides: textStyle,
    );
    name.paint(
      canvas,
      box.headerRect.center - Offset(name.width / 2, name.height / 2),
    );
    name.dispose();

    for (final (row, cells) in box.rows.indexed) {
      for (final (column, text) in cells.indexed) {
        if (text.isEmpty) continue;
        final cell = box.cellRect(row, column);
        final painter = styles.layout(
          text,
          ErTextRole.attribute,
          overrides: textStyle,
        );
        painter.paint(
          canvas,
          Offset(
            cell.left + config.cellPaddingX,
            cell.center.dy - painter.height / 2,
          ),
        );
        painter.dispose();
      }
    }
  }

  void _paintLabel(Canvas canvas, ErRelationshipRoute route) {
    final rect = route.labelRect;
    final label = route.relationship.label;
    if (rect == null || label.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = palette.labelBackground,
    );
    final painter = styles.layout(
      label,
      ErTextRole.relationshipLabel,
      overrides: TextStyle(color: palette.text),
    );
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  void _paintTitle(Canvas canvas) {
    final rect = layout.titleRect;
    final title = diagram.title;
    if (rect == null || title == null) return;
    final painter = styles.layout(
      title,
      ErTextRole.title,
      overrides: TextStyle(color: palette.text),
    );
    painter.paint(
      canvas,
      rect.center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  /// An orthogonal polyline with its corners rounded off.
  static Path _roundedPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i + 1 < points.length; i++) {
      final previous = points[i - 1];
      final corner = points[i];
      final next = points[i + 1];
      final before = (corner - previous).distance;
      final after = (next - corner).distance;
      final radius = math.min(_cornerRadius, math.min(before, after) / 2);
      if (radius < 0.5) {
        path.lineTo(corner.dx, corner.dy);
        continue;
      }
      final entry = corner - (corner - previous) / before * radius;
      final exit = corner + (next - corner) / after * radius;
      path
        ..lineTo(entry.dx, entry.dy)
        ..quadraticBezierTo(corner.dx, corner.dy, exit.dx, exit.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  static void _strokePath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double>? dash,
  ) {
    if (dash == null || dash.isEmpty || dash.every((d) => d <= 0)) {
      canvas.drawPath(path, paint);
      return;
    }
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var index = 0;
      var draw = true;
      while (distance < metric.length) {
        final length = math.max(dash[index % dash.length], 0.5);
        if (draw) {
          dashed.addPath(
            metric.extractPath(
                distance, math.min(distance + length, metric.length)),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
        index++;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(ErDiagramPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.layout != layout ||
      oldDelegate.styles != styles ||
      oldDelegate.palette != palette ||
      oldDelegate.config != config;
}

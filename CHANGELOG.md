## 0.1.0

- Initial release.
- `MermaidErDiagram` widget that renders Mermaid `erDiagram` diagrams
  natively, with `errorBuilder`, `onEntityTap` and semantics (`accTitle` /
  `accDescr` when present).
- Parser for entities, aliases, quoted and Unicode names, attribute blocks
  with `PK`/`FK`/`UK` keys and comments, every cardinality symbol and word
  alias, identifying and non-identifying relationships, `direction`, nested
  subgraphs (also as relationship endpoints), `style`, `classDef`, `class`,
  `:::` and the front matter `title`.
- Attribute tables, crow's foot markers and self-relationship loops, laid
  out with the layered layout of `mermaid_flowchart`.
- Light and dark palettes with Mermaid's per-entity colors, configurable
  text styles and spacing.
- `ErDiagramParser`, `ErDiagramLayout` and `ErDiagramPainter` exported for
  custom rendering.

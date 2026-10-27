#import "@preview/cetz:0.4.1"

// ---------------------------------------------------------------------------
// Linguagem visual comum a todos os diagramas
// ---------------------------------------------------------------------------

// Dados em circulação: pedidos preenchidos, entradas ocupadas, padrões encontrados
#let accent-fill = rgb("#d5e8d4")
#let accent-stroke = rgb("#82b366")
// Estruturas livres, regiões já processadas e implementações concretas
#let muted-fill = rgb("#f5f5f5")
#let muted-stroke = rgb("#666666")
// Segunda categoria de dados, quando é preciso distingui-la da primeira
#let info-fill = rgb("#dae8fc")
#let info-stroke = rgb("#6c8ebf")
// Kernel, dispositivo e restante sistema subjacente
#let system-fill = luma(225)
// Posições e fronteiras
#let marker = rgb("#b85450")
#let note-color = luma(80)

#let arrow = (end: "stealth", fill: black, scale: 0.7)

#let styles = (
  component: (fill: white, stroke: 0.8pt + black, radius: 0.15),
  system: (fill: system-fill, stroke: 0.8pt + black, radius: 0.15),
  variant: (fill: muted-fill, stroke: 0.6pt + muted-stroke, radius: 0.1),
  filled: (fill: accent-fill, stroke: 0.6pt + accent-stroke, radius: 0.08),
  free: (fill: muted-fill, stroke: 0.6pt + muted-stroke, radius: 0.08),
  highlight: (fill: info-fill, stroke: 0.6pt + info-stroke, radius: 0.08),
)

// Caixa com texto centrado, desenhada segundo um dos estilos acima
#let node(name, pos, width, height, body, kind: "component", pill: false) = {
  import cetz.draw: rect, content
  let style = styles.at(kind)
  let (x, y) = pos
  rect(
    (x - width / 2, y - height / 2),
    (x + width / 2, y + height / 2),
    radius: if pill { height / 2 } else { style.radius },
    fill: style.fill,
    stroke: style.stroke,
    name: name,
  )
  content(pos, align(center, body))
}

// Rótulo com fundo branco, que interrompe a linha sobre a qual assenta
#let tag(pos, body) = {
  import cetz.draw: content
  content(pos, align(center, body), frame: "rect", fill: white, stroke: none, padding: 0.06)
}

// Texto secundário, para legendas de canais e anotações
#let note(pos, body, anchor: "center") = {
  import cetz.draw: content
  content(pos, anchor: anchor, align(center, text(size: 7.5pt, fill: note-color, body)))
}

// Agrupamento tracejado, com o nome no canto superior ou inferior esquerdo
#let region(from, to, label, at: "top") = {
  import cetz.draw: rect, content
  rect(from, to, radius: 0.2, stroke: (paint: luma(120), dash: "dashed", thickness: 0.7pt))
  let (x, y, anchor) = if at == "top" {
    (from.at(0) + 0.15, to.at(1) - 0.1, "north-west")
  } else {
    (from.at(0) + 0.15, from.at(1) + 0.1, "south-west")
  }
  content((x, y), anchor: anchor, text(fill: luma(90), emph(label)))
}

// Fila concorrente com três posições ocupadas
#let channel(name, pos, filled, cell-width: 0.7) = {
  import cetz.draw: rect
  let style = styles.at(if filled { "filled" } else { "free" })
  let (x, y) = pos
  let width = 3 * cell-width + 0.2
  rect((x - width / 2, y - 0.25), (x + width / 2, y + 0.25), radius: 0.12, name: name)
  for i in range(3) {
    let x0 = x - width / 2 + 0.1 + i * cell-width
    rect((x0, y - 0.15), (x0 + cell-width, y + 0.15), fill: style.fill, stroke: style.stroke)
  }
}

// Entrada de legenda: amostra do estilo seguida da descrição
#let legend(pos, kind, body) = {
  import cetz.draw: rect, content
  let style = styles.at(kind)
  let (x, y) = pos
  rect((x, y - 0.15), (x + 0.35, y + 0.15), fill: style.fill, stroke: style.stroke)
  content((x + 0.5, y), anchor: "west", body)
}

// Passo numerado, desenhado como um círculo preto com o número a branco
#let step(n) = box(baseline: 0.2em, circle(
  radius: 0.62em,
  fill: black,
  stroke: none,
  inset: 0pt,
  align(center + horizon, text(size: 0.72em, fill: white, weight: "bold", str(n))),
))

// ---------------------------------------------------------------------------
// Capítulo 2
// ---------------------------------------------------------------------------

#let io-stack() = {
  set text(size: 8pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.62cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let badge(pos, n) = content(pos, step(n))
    let function(pos, name) = content(pos, raw(name))
    let width = 16.5
    let completion = 14.6

    node("aplicacao", (width / 2, 17.3), width, 0.6, [Aplicação])

    // Interfaces, cujas chamadas atravessam a fronteira entre utilizador e kernel
    node(none, (1.4, 15.25), 2.8, 1.6, [POSIX \ #raw("pread()") \ #raw("pwrite()")], kind: "variant")
    node(none, (4.95, 15.25), 3.5, 1.6, [libaio \ #raw("io_submit()") \ #raw("io_getevents()")], kind: "variant")
    node(none, (11.65, 15.25), 9.7, 1.6, none, kind: "variant")
    content((11.65, 15.8), [io_uring])
    node("sq", (9.4, 14.95), 1.2, 0.5, [SQ], kind: "filled")
    node("cq", (completion, 14.95), 1.2, 0.5, [CQ], kind: "filled")

    for (down, up) in ((0.9, 1.9), (4.45, 5.45)) {
      line((down, 17.0), (down, 16.05), mark: arrow)
      line((up, 16.05), (up, 17.0), mark: arrow)
    }
    line((9.4, 17.0), "sq.north", mark: arrow)
    line("cq.north", (completion, 17.0), mark: arrow)
    badge((0.45, 16.5), 1)
    badge((2.35, 16.5), 15)
    badge((4.0, 16.5), 1)
    badge((5.9, 16.5), 15)
    badge((8.95, 16.5), 1)
    badge((completion + 0.45, 16.5), 15)

    line((-0.2, 13.9), (width + 0.2, 13.9), stroke: (paint: marker, dash: "dashed", thickness: 1pt))
    note((-0.3, 14.15), anchor: "east", [espaço de utilizador])
    note((-0.3, 13.65), anchor: "east", [espaço do _kernel_])

    // VFS
    node("vfs", (5.3, 12.4), 10.6, 0.9, [VFS e _cache_ de páginas \ #raw("generic_file_read_iter()")])
    for x in (1.4, 4.95) {
      line((x, 14.45), (x, 12.85), mark: arrow)
    }
    line("sq.south", (9.4, 12.85), mark: arrow)
    tag((9.4, 13.9), raw("io_uring_enter()"))
    badge((1.0, 13.35), 2)

    // Camada de blocos multi-fila
    node(none, (width / 2, 8.65), width, 4.7, none)
    content((0.2, 10.85), anchor: "north-west", [Camada de blocos multi-fila])
    line((5.6, 11.95), (5.6, 10.25), mark: arrow)
    tag((5.6, 11.5), raw("submit_bio(bio)"))
    badge((3.5, 11.5), 3)

    function((5.6, 10.0), "bio")
    line((6.1, 10.0), (7.1, 10.0), mark: arrow)
    content((7.2, 10.0), anchor: "west", [pedidos])
    badge((6.6, 10.4), 4)

    // Filas de software por núcleo, escalonador e filas de despacho do hardware
    let software = (4.6, 6.6, 8.6)
    let hardware = (5.6, 7.6)
    note((0.3, 8.8), anchor: "west", align(left)[filas por \ núcleo])
    note((0.3, 7.2), anchor: "west", align(left)[filas de \ despacho])
    for x in software {
      channel(none, (x, 8.8), true, cell-width: 0.45)
      line((7.7, 9.75), (x, 9.05), mark: arrow)
      for h in hardware {
        if calc.abs(h - x) < 1.5 { line((x, 8.55), (h, 7.45), mark: arrow) }
      }
    }
    for x in hardware {
      channel(none, (x, 7.2), true, cell-width: 0.45)
    }
    badge((8.8, 10.0), 5)
    badge((3.8, 8.0), 7)
    content((9.9, 8.5), anchor: "west", std.grid(
      columns: 2,
      column-gutter: 4pt,
      step(6),
      align(left)[escalonador: \ #raw("none"), #raw("bfq"), \ #raw("kyber"), \ #raw("mq-deadline")],
    ))

    // Driver NVMe
    node(none, (width / 2, 3.8), width, 2.8, none)
    content((0.2, 5.05), anchor: "north-west", [Driver NVMe])
    line((5.6, 6.95), (5.6, 4.65), mark: arrow)
    tag((5.6, 5.75), raw("nvme_queue_rq()"))
    badge((3.7, 5.75), 8)

    content((5.6, 4.4), [pedido])
    line((6.35, 4.4), (7.4, 4.4), mark: arrow)
    content((7.5, 4.4), anchor: "west", [comando NVMe])
    badge((6.85, 4.8), 9)

    node("nvme-sq", (8.6, 3.2), 1.0, 0.5, [SQ], kind: "filled")
    node("nvme-cq", (9.8, 3.2), 1.0, 0.5, [CQ], kind: "filled")
    note((10.45, 3.2), anchor: "west", [par SQ-CQ])
    line((8.6, 4.15), "nvme-sq.north", mark: arrow)
    badge((8.15, 3.8), 10)

    node("dispositivo", (width / 2, 0.7), width, 0.6, [Dispositivo], kind: "system")
    line("nvme-sq.south", (8.6, 1.0), mark: arrow)
    badge((8.15, 1.7), 11)

    // Caminho de conclusão, do dispositivo de volta à aplicação
    line((completion, 1.0), (completion, 3.15), mark: arrow)
    badge((completion + 0.45, 1.85), 12)
    content((completion + 0.8, 1.85), anchor: "west", [interrupção])
    function((completion, 3.4), "nvme_process_cq()")
    line((completion, 3.65), (completion, 6.65), mark: arrow)
    badge((completion + 0.45, 5.75), 13)
    function((completion, 6.9), "blk_mq_end_request()")
    line((completion, 7.15), (completion, 9.65), mark: arrow)
    badge((completion + 0.45, 8.4), 14)
    function((completion, 9.9), "bio_endio()")
    line((completion, 10.15), "cq.south", mark: arrow)

    // O SPDK acede ao dispositivo sem atravessar o kernel
    line((width, 17.3), (width + 0.9, 17.3), (width + 0.9, 0.7), (width, 0.7), mark: arrow)
    tag((width + 0.9, 8.65), [SPDK])
  })
}

#let uring-rings() = {
  set text(size: 8pt)
  set par(leading: 0.45em)

  // Pontos de um setor circular entre os ângulos a e b, em graus
  let sector(center, a, b, inner, outer, steps: 10) = {
    let (cx, cy) = center
    let points = ()
    for i in range(steps + 1) {
      let t = (a + (b - a) * i / steps) * 1deg
      points.push((cx + outer * calc.cos(t), cy + outer * calc.sin(t)))
    }
    for i in range(steps + 1) {
      let t = (b - (b - a) * i / steps) * 1deg
      points.push((cx + inner * calc.cos(t), cy + inner * calc.sin(t)))
    }
    points
  }

  let rim(center, radius, angle) = {
    let (cx, cy) = center
    (cx + radius * calc.cos(angle * 1deg), cy + radius * calc.sin(angle * 1deg))
  }

  cetz.canvas(length: 0.75cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let (inner, outer) = (0.8, 1.2)

    // Anel com oito entradas, das quais as indicadas estão ocupadas
    let ring(center, used) = {
      for k in range(8) {
        let a = k * 45
        line(
          ..sector(center, a, a + 45, inner, outer),
          close: true,
          fill: if a in used { accent-fill } else { white },
          stroke: 0.6pt,
        )
      }
    }

    // Sentido de avanço das entradas, no sentido dos ponteiros do relógio
    let direction(center, from, to) = {
      let points = range(21).map(i => rim(center, 0.5, from + (to - from) * i / 20))
      line(..points, stroke: 0.8pt, mark: (end: "stealth", fill: black, scale: 0.6))
    }

    node("aplicacao", (7.0, 6.35), 7.6, 0.7, text(size: 8.5pt)[Aplicação])
    node("kernel", (7.0, -0.15), 7.6, 0.7, text(size: 8.5pt)[_Kernel_], kind: "system")

    // Fila de submissão: a aplicação insere na cauda e o kernel consome a partir da cabeça
    let sq = (4.6, 3.1)
    ring(sq, (45, 90, 135, 180, 225))
    direction(sq, 250, 30)
    content((3.2, 3.1), anchor: "east", align(center)[Fila de \ submissão])
    content((rim(sq, outer, 45).at(0) + 0.1, rim(sq, outer, 45).at(1) + 0.05), anchor: "south-west", [cauda])
    content((sq.at(0) + 0.15, sq.at(1) - outer - 0.05), anchor: "north-west", [cabeça])
    line((5.1, 6.0), rim(sq, outer, 45), mark: arrow)
    line((4.3, 0.2), rim(sq, outer, 270), mark: arrow)
    note((4.75, 5.1), anchor: "east", align(right)[a aplicação insere \ na cauda])
    note((4.15, 1.0), anchor: "east", align(right)[o _kernel_ consome da \ cabeça para a cauda])

    // Fila de conclusão: o kernel insere na cauda e a aplicação consome a partir da cabeça
    let cq = (9.4, 3.1)
    ring(cq, (270, 315, 0, 45))
    direction(cq, 80, -80)
    content((10.8, 3.1), anchor: "west", align(center)[Fila de \ conclusão])
    content((cq.at(0) + 0.15, cq.at(1) + outer + 0.05), anchor: "south-west", [cabeça])
    content((cq.at(0) - 0.15, cq.at(1) - outer - 0.05), anchor: "north-east", [cauda])
    line((8.6, 6.0), rim(cq, outer, 90), mark: arrow)
    line((9.8, 0.2), rim(cq, outer, 270), mark: arrow)
    note((9.25, 5.45), anchor: "west", align(left)[a aplicação consome da \ cabeça para a cauda])
    note((9.85, 1.0), anchor: "west", align(left)[o _kernel_ insere \ na cauda])
  })
}

#let dedup-overview() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.85cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let cell = 0.8

    // Visão lógica, tal como a aplicação a solicita, e visão física, sem duplicados
    let logical = ("A", "B", "D", "C", "A", "C")
    let physical = ("A", "B", "C", "D")
    let logical-x(i) = 4.0 + i * cell
    let physical-x(id) = 4.8 + physical.position(p => p == id) * cell
    let duplicate(i) = logical.slice(0, i).contains(logical.at(i))
    let (top, bottom) = (3.4, 0.6)

    content((3.35, top + 0.1), anchor: "east", [Visão lógica])
    note((3.35, top - 0.25), anchor: "east", [pedida pela aplicação])
    content((4.15, bottom + 0.1), anchor: "east", [Visão física])
    note((4.15, bottom - 0.25), anchor: "east", [gravada no dispositivo])

    // Os blocos únicos são escritos e os duplicados passam a apontar para a cópia existente
    for (i, id) in logical.enumerate() {
      let (x0, x1) = (logical-x(i), physical-x(id))
      bezier(
        (x0, top - cell / 2), (x1, bottom + cell / 2),
        (x0, 2.0), (x1, 2.0),
        stroke: if duplicate(i) { (thickness: 0.8pt, dash: "dashed") } else { 0.8pt },
        mark: arrow,
      )
    }
    for (i, id) in logical.enumerate() {
      node(none, (logical-x(i), top), cell, cell, id, kind: if duplicate(i) { "highlight" } else { "filled" })
    }
    for id in physical {
      node(none, (physical-x(id), bottom), cell, cell, id, kind: "filled")
    }

    // Índice que associa cada bloco à sua localização física
    let (tx0, tx1, row) = (9.6, 13.6, 0.55)
    let mid = (tx0 + tx1) / 2
    let header = gray.lighten(60%)
    let rows = (([*Índice*],), ([*Bloco*], [*Localização*])) + physical.enumerate().map(((i, id)) => ([#id], [#i]))
    for (r, cells) in rows.enumerate() {
      let y1 = 3.8 - r * row
      let y0 = y1 - row
      let fill = if r < 2 { header } else { white }
      if cells.len() == 1 {
        rect((tx0, y0), (tx1, y1), fill: fill)
        content(((tx0 + tx1) / 2, (y0 + y1) / 2), cells.at(0))
      } else {
        rect((tx0, y0), (mid, y1), fill: fill)
        rect((mid, y0), (tx1, y1), fill: fill)
        content(((tx0 + mid) / 2, (y0 + y1) / 2), cells.at(0))
        content(((mid + tx1) / 2, (y0 + y1) / 2), cells.at(1))
      }
    }

    // Legenda
    let y = -0.55
    legend((0.6, y), "filled", [bloco único])
    legend((3.2, y), "highlight", [bloco duplicado])
    line((6.1, y), (6.8, y), mark: arrow)
    content((6.95, y), anchor: "west", [escrita])
    line((8.4, y), (9.1, y), stroke: (thickness: 0.8pt, dash: "dashed"), mark: arrow)
    content((9.25, y), anchor: "west", [apontador])
  })
}

// Árvore para a frase "this is an example of a huffman tree"
#let huffman-data = {
  let leaf(symbol, weight) = (symbol: symbol, weight: weight)
  let join(weight, left, right) = (weight: weight, left: left, right: right)
  join(36,
    join(16,
      join(8, leaf("e", 4), join(4, leaf("n", 2), join(2, leaf("o", 1), leaf("u", 1)))),
      join(8, leaf("a", 4), join(4, leaf("t", 2), leaf("m", 2))),
    ),
    join(20,
      join(8,
        join(4, leaf("i", 2), join(2, leaf("x", 1), leaf("p", 1))),
        join(4, leaf("h", 2), leaf("s", 2)),
      ),
      join(12, join(5, join(2, leaf("r", 1), leaf("l", 1)), leaf("f", 3)), leaf(" ", 7)),
    ),
  )
}

// Atribui a cada folha uma posição horizontal própria, pela ordem em que surge,
// e centra cada nó interno sobre os respetivos filhos
#let huffman-layout(tree, depth, slot) = {
  if "symbol" in tree {
    return (nodes: ((tree: tree, x: slot, depth: depth),), edges: (), next: slot + 1, x: slot)
  }
  let left = huffman-layout(tree.left, depth + 1, slot)
  let right = huffman-layout(tree.right, depth + 1, left.next)
  let x = (left.x + right.x) / 2
  (
    nodes: ((tree: tree, x: x, depth: depth),) + left.nodes + right.nodes,
    edges: ((x, depth, left.x, "0"), (x, depth, right.x, "1")) + left.edges + right.edges,
    next: right.next,
    x: x,
  )
}

#let huffman-tree() = {
  set text(size: 8pt)
  set par(leading: 0.45em)

  let layout = huffman-layout(huffman-data, 0, 0)
  let (slot, level, height) = (1.05, 0.95, 0.42)
  let position(x, depth) = (x * slot, -depth * level)

  cetz.canvas(length: 0.75cm, {
    import cetz.draw: *

    for (x, depth, child, bit) in layout.edges {
      let (px, py) = position(x, depth)
      let (cx, cy) = position(child, depth + 1)
      line((px, py - height / 2), (cx, cy + height / 2), stroke: 0.8pt)
      let side = if bit == "0" { "east" } else { "west" }
      let offset = if bit == "0" { -0.08 } else { 0.08 }
      content(((px + cx) / 2 + offset, (py + cy) / 2 + 0.05), anchor: side, text(size: 7pt, fill: note-color, bit))
    }

    for item in layout.nodes {
      let (x, y) = position(item.x, item.depth)
      if "symbol" in item.tree {
        let symbol = if item.tree.symbol == " " { "␣" } else { item.tree.symbol }
        node(none, (x, y), 0.9, height, none, kind: "filled")
        line((x + 0.05, y - height / 2), (x + 0.05, y + height / 2), stroke: styles.filled.stroke)
        content((x - 0.2, y), raw(symbol))
        content((x + 0.25, y), str(item.tree.weight))
      } else {
        node(none, (x, y), 0.64, height, str(item.tree.weight))
      }
    }
  })
}

#let lz77-window() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  let input = "aacaacabcabaaac"
  let (search-size, lookahead-size) = (6, 4)
  // Posição corrente, comprimento do padrão encontrado e tuplo emitido
  let steps = (
    (0, 0, "(_,0,a)"),
    (1, 1, "(1,1,c)"),
    (3, 4, "(3,4,b)"),
    (8, 3, "(3,3,a)"),
    (12, 2, "(1,2,c)"),
  )

  cetz.canvas(length: 0.85cm, {
    import cetz.draw: *

    let (cell, height, gap) = (0.55, 0.5, 0.8)

    for (row, (cursor, length, tuple)) in steps.enumerate() {
      let y = -row * gap
      for (i, symbol) in input.clusters().enumerate() {
        let style = if i >= cursor - search-size and i < cursor { styles.free }
          else if i >= cursor and i < cursor + length { styles.filled }
          else if i == cursor + length { styles.highlight }
          else { (fill: white, stroke: 0.6pt + luma(150)) }
        rect((i * cell, y), ((i + 1) * cell, y + height), fill: style.fill, stroke: style.stroke)
        content(((i + 0.5) * cell, y + height / 2), raw(symbol))
      }

      let bar(i, stroke) = line((i * cell, y - 0.08), (i * cell, y + height + 0.08), stroke: stroke)
      bar(calc.max(0, cursor - search-size), 1.4pt + black)
      bar(calc.min(input.len(), cursor + lookahead-size), 1.4pt + black)
      bar(cursor, 1.6pt + marker)

      content((input.len() * cell + 0.4, y + height / 2), anchor: "west", raw(tuple))
    }

    // Legenda
    let y = -steps.len() * gap + 0.25
    legend((0, y), "free", [janela de pesquisa])
    legend((3.9, y), "filled", [padrão repetido])
    legend((7.3, y), "highlight", [símbolo seguinte])
    line((10.85, y - 0.18), (10.85, y + 0.18), stroke: 1.6pt + marker)
    content((11.05, y), anchor: "west", [posição atual])
  })
}

// ---------------------------------------------------------------------------
// Capítulo 3
// ---------------------------------------------------------------------------

#let architecture-overview() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.82cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)

    // Blocos de geração e submissão
    region((-0.2, -0.35), (6.2, 5.95), [Geração])
    region((9.1, -0.35), (14.9, 5.95), [Submissão])

    // Geradores
    let generators = (
      ("acessos", [acessos], 4.45),
      ("operacoes", [operações], 2.6),
      ("conteudo", [conteúdo], 0.75),
    )
    for (name, title, y) in generators {
      node(name, (1.45, y), 2.9, 1.55, [
        Gerador de \ #title \
        #text(size: 7pt, fill: note-color)[sintético ou _trace_]
      ])
      line((2.9, y), (3.35, y))
    }
    line((3.35, 4.45), (3.35, 0.75))
    line((3.35, 2.6), (3.8, 2.6), mark: arrow)

    node("produtor", (4.85, 2.6), 2.1, 1.5, [Produtor])

    // Canais de comunicação
    channel("pedidos", (7.65, 3.15), true)
    channel("retorno", (7.65, 2.05), false)
    note((7.65, 3.5), anchor: "south", [pedidos \ preenchidos])
    note((7.65, 1.7), anchor: "north", [estruturas \ livres])

    line((5.9, 3.15), "pedidos.west", mark: arrow)
    line("pedidos.east", (9.4, 3.15), mark: arrow)
    line((9.4, 2.05), "retorno.east", mark: arrow)
    line("retorno.west", (5.9, 2.05), mark: arrow)

    node("consumidor", (10.5, 2.6), 2.2, 1.5, [Consumidor])
    line((11.6, 2.6), (12.1, 2.6), mark: arrow)

    // Interface de E/S e respetivas implementações
    node("interface", (13.35, 2.6), 2.5, 5.25, none)
    content((13.35, 5.05), anchor: "north", align(center)[Interface \ de E/S])
    for (i, engine) in ([POSIX], [AIO], [io_uring], [SPDK]).enumerate() {
      node(none, (13.35, 3.6 - i * 0.8), 1.9, 0.6, engine, kind: "variant")
    }

    line((14.6, 2.6), (15.4, 2.6), mark: arrow)
    node("dispositivo", (16.6, 2.6), 2.4, 1.5, [Dispositivo], kind: "system")
  })
}

#let producer-flow() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.85cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)

    // Cada gerador contribui com uma dimensão do pedido, sendo o conteúdo exclusivo das escritas
    let generators = (
      ([Gerador de acessos], [#step(2) _offset_], 2.6),
      ([Gerador de operações], [#step(3) operação], 1.4),
      ([Gerador de conteúdo], [#step(4) bloco, se \ for escrita], 0.2),
    )
    for (title, label, y) in generators {
      node(none, (1.5, y), 3.0, 0.8, title)
      line((3.0, y), (5.3, y))
      tag((4.15, y), label)
    }
    line((5.3, 2.6), (5.3, 0.2))
    line((5.3, 1.4), (5.8, 1.4), mark: arrow)

    node("produtor", (6.85, 1.4), 2.1, 1.1, [Produtor])

    channel("retorno", (6.85, -1.3), false)
    note((6.85, -1.65), anchor: "north", [estruturas livres])
    line("retorno.north", "produtor.south", mark: arrow)
    content((7.0, -0.45), anchor: "west", [#step(1) retirar])

    channel("pedidos", (10.9, 1.4), true)
    note((10.9, 1.75), anchor: "south", [pedidos preenchidos])
    line("produtor.east", "pedidos.west", mark: arrow)
    content((8.85, 1.5), anchor: "south", [#step(5) inserir])
  })
}

#let consumer-flow() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.85cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)

    channel("pedidos", (1.25, 1.4), true)
    note((1.25, 1.75), anchor: "south", [pedidos preenchidos])

    node("consumidor", (5.0, 1.4), 2.1, 1.1, [Consumidor])
    line("pedidos.east", "consumidor.west", mark: arrow)
    content((3.25, 1.5), anchor: "south", [#step(1) retirar])

    node("interface", (10.0, 1.4), 2.4, 1.1, [Interface de E/S])
    line((6.05, 1.6), (8.8, 1.6), mark: arrow)
    content((7.4, 1.7), anchor: "south", [#step(2) submeter])
    line((8.8, 1.2), (6.05, 1.2), mark: arrow)
    content((7.4, 1.1), anchor: "north", [#step(3) devolver estrutura])

    channel("retorno", (5.0, -1.3), false)
    note((5.0, -1.65), anchor: "north", [estruturas livres])
    line("consumidor.south", "retorno.north", mark: arrow)
    content((5.15, -0.45), anchor: "west", [#step(4) inserir])
  })
}

// Interface abstrata e as implementações concretas que dela derivam
#let hierarchy(root, children) = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.8cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let xs = (1.7, 6.0, 10.3)

    node("interface", (6.0, 2.3), 3.4, 0.9, root)
    for (x, child) in xs.zip(children) {
      node(none, (x, 0), 3.2, 0.9, child, kind: "variant")
      line((x, 0.45), (x, 1.15))
    }
    line((xs.first(), 1.15), (xs.last(), 1.15))
    line((6.0, 1.15), "interface.south", mark: (end: "triangle", fill: white, scale: 1.1))
  })
}

#let access-hierarchy() = hierarchy([Gerador de acessos], ([Sequencial], [Aleatório], [Zipfian]))
#let operation-hierarchy() = hierarchy([Gerador de operações], ([Constante], [Percentagem], [Sequência]))
#let content-hierarchy() = hierarchy([Gerador de conteúdo], ([Constante], [Aleatório], [Duplicados e \ compressão]))

// Mapa que associa o número de repetições a uma lista de tuplos
#let repeats-map(header, fields, rows) = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  let entry(value) = box(
    fill: accent-fill,
    stroke: 0.6pt + accent-stroke,
    radius: 2pt,
    inset: (x: 4pt, y: 3pt),
    raw(value),
  )

  table(
    columns: (auto, 1fr),
    align: center + horizon,
    inset: 6pt,
    fill: (x, y) => if y == 0 { gray.lighten(60%) },
    table.header(
      [*Repetições*],
      [*#header* \ #text(size: 7.5pt, fill: note-color, fields)],
    ),
    ..rows
      .map(((repeats, entries)) => ([#repeats], align(left, entries.map(entry).join(h(3pt)))))
      .flatten(),
  )
}

#let dedup-map() = repeats-map([Janela de blocos], [\[bloco, cópias em falta\]], (
  (1, ("[A, 1]", "[B, 1]", "[C, 1]", "[D, 1]", "[E, 1]")),
  (2, ("[F, 2]", "[G, 1]", "[H, 1]")),
  (3, ("[I, 3]", "[J, 1]")),
))

#let compression-map() = repeats-map([Compressão], [\[percentagem acumulada, redução\]], (
  (1, ("[40, 10]", "[100, 50]")),
  (2, ("[20, 20]", "[100, 10]")),
  (3, ("[40, 30]", "[100, 0]")),
))

// Estruturas trocadas entre o consumidor e cada motor
#let request-boxes(top, bottom) = {
  node("pedido", (1.35, top), 2.7, 0.55, [pedido], kind: "filled")
  node("livre", (1.35, bottom), 2.7, 0.55, [estrutura livre], kind: "free")
}

#let posix-flow() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.8cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let (top, bottom) = (1.6, 0.0)

    request-boxes(top, bottom)
    node("motor", (6.3, 0.8), 2.4, 2.2, [Motor POSIX])
    node("kernel", (12.3, 0.8), 2.0, 2.2, [_Kernel_], kind: "system")

    line((2.7, top), (5.1, top), mark: arrow)
    content((3.9, top + 0.1), anchor: "south", [#step(1) submeter])
    line((7.5, top), (11.3, top), mark: arrow)
    content((9.4, top + 0.1), anchor: "south", [#step(2) chamada ao sistema])
    line((11.3, bottom), (7.5, bottom), mark: arrow)
    content((9.4, bottom - 0.1), anchor: "north", [#step(3) resultado])
    line((5.1, bottom), (2.7, bottom), mark: arrow)
    content((3.9, bottom - 0.1), anchor: "north", [#step(4) libertar \ estrutura])
  })
}

#let uring-flow() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.8cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let (top, bottom) = (1.6, 0.0)

    request-boxes(top, bottom)
    node("motor", (6.3, 0.8), 2.4, 2.2, [Motor io_uring])
    line((2.7, top), (5.1, top), mark: arrow)
    content((3.9, top + 0.1), anchor: "south", [#step(1) submeter])

    // Decisão entre acumular o pedido no lote ou submeter o lote
    let (dx, dw, dh) = (11.4, 2.8, 1.5)
    line(
      (dx - dw / 2, top), (dx, top + dh / 2), (dx + dw / 2, top), (dx, top - dh / 2),
      close: true,
      fill: white,
    )
    content((dx, top), align(center)[lote \ completo?])
    line((7.5, top), (dx - dw / 2, top), mark: arrow)
    content(((7.5 + dx - dw / 2) / 2, top + 0.1), anchor: "south", [#step(2) obter \ índice livre])

    node("preencher", (dx, top + 1.75), 3.2, 0.6, [preencher entrada], pill: true)
    line((dx, top + dh / 2), "preencher.south", mark: arrow)
    content((dx + 0.1, top + 1.1), anchor: "west", [não])

    node("lote", (16.0, top), 2.8, 0.6, [submeter lote], pill: true)
    line((dx + dw / 2, top), "lote.west", mark: arrow)
    content(((dx + dw / 2 + 14.6) / 2, top + 0.1), anchor: "south", [sim])

    node("kernel", (dx, bottom), 2.0, 0.8, [_Kernel_], kind: "system")
    line("lote.south", (16.0, bottom), "kernel.east", mark: arrow)
    content(((16.0 + dx + 1.0) / 2, bottom - 0.1), anchor: "north", [#step(3) notificar \ submissão])
    line("kernel.west", (7.5, bottom), mark: arrow)
    content(((7.5 + dx - 1.0) / 2, bottom - 0.1), anchor: "north", [#step(4) notificar \ conclusão])
    line((5.1, bottom), (2.7, bottom), mark: arrow)
    content((3.9, bottom - 0.1), anchor: "north", [#step(5) libertar \ estrutura])
  })
}

#let spdk-flow() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.8cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let (top, bottom) = (3.4, -0.8)

    request-boxes(top, bottom)
    node("motor", (6.3, (top + bottom) / 2), 2.4, top - bottom + 0.6, [Motor SPDK])
    line((2.7, top), (5.1, top), mark: arrow)
    content((3.9, top + 0.1), anchor: "south", [#step(1) submeter])

    node("runtime", (12.0, top), 2.6, 0.8, [_Runtime_ SPDK])
    line((7.5, top), "runtime.west", mark: arrow)
    content(((7.5 + 10.7) / 2, top + 0.1), anchor: "south", [#step(2) encaminhar pedido])
    line((11.3, top + 0.4), (11.3, top + 1.0), (12.7, top + 1.0), (12.7, top + 0.4), mark: arrow)
    content((12.0, top + 1.1), anchor: "south", [#step(3) obter índice livre])

    // Threads lógicas pelas quais os pedidos são distribuídos
    let threads = 1.6
    region((9.9, threads - 0.45), (14.1, threads + 0.85), [_threads_ lógicas])
    for i in range(3) {
      node(none, (10.6 + i * 1.4, threads - 0.05), 1.2, 0.55, [_thread_])
    }
    line("runtime.south", (12.0, threads + 0.85), mark: arrow)
    content((11.9, top - 0.68), anchor: "east", [#step(4) enviar mensagem])
    line("runtime.east", (14.8, top), (14.8, threads - 0.05), (14.1, threads - 0.05), mark: arrow)
    content((14.9, (top + threads) / 2 - 0.1), anchor: "west", [#step(5) agendar \ _callback_])

    // O pedido é executado na thread e, concluído, dá lugar ao callback
    node("execucao", (12.0, 0.4), 2.8, 0.6, [executar pedido], pill: true)
    line((12.0, threads - 0.45), "execucao.north", mark: arrow)
    node("callback", (12.0, bottom), 2.8, 0.6, [executar _callback_], pill: true)
    line("execucao.south", "callback.north", mark: arrow)

    line("callback.west", (7.5, bottom), mark: arrow)
    content(((7.5 + 10.6) / 2, bottom - 0.1), anchor: "north", [#step(6) notificar \ conclusão])
    line((5.1, bottom), (2.7, bottom), mark: arrow)
    content((3.9, bottom - 0.1), anchor: "north", [#step(7) libertar \ estrutura])
  })
}

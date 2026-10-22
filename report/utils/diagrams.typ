#import "@preview/cetz:0.4.1"

// Paleta alinhada com as figuras do produtor e do consumidor
#let request-fill = rgb("#d5e8d4")
#let request-stroke = rgb("#82b366")
#let return-fill = rgb("#f5f5f5")
#let return-stroke = rgb("#666666")

#let architecture-overview() = {
  set text(size: 8.5pt)
  set par(leading: 0.45em)

  cetz.canvas(length: 0.82cm, {
    import cetz.draw: *

    set-style(stroke: 0.8pt)
    let arrow = (end: "stealth", fill: black, scale: 0.7)

    let node(name, pos, width, height, body, fill: white) = {
      let (x, y) = pos
      rect(
        (x - width / 2, y - height / 2),
        (x + width / 2, y + height / 2),
        radius: 0.15,
        fill: fill,
        name: name,
      )
      content(name, align(center, body))
    }

    let channel(name, pos, width, fill, stroke) = {
      let (x, y) = pos
      rect((x - width / 2, y - 0.25), (x + width / 2, y + 0.25), radius: 0.12, name: name)
      let cell = (width - 0.2) / 3
      for i in range(3) {
        let x0 = x - width / 2 + 0.1 + i * cell
        rect((x0, y - 0.15), (x0 + cell, y + 0.15), fill: fill, stroke: 0.6pt + stroke)
      }
    }

    let group(from, to, label) = {
      rect(from, to, radius: 0.2, stroke: (paint: luma(120), dash: "dashed", thickness: 0.7pt))
      content((from.at(0) + 0.15, to.at(1) - 0.1), anchor: "north-west", text(fill: luma(90), emph(label)))
    }

    // Blocos de geração e submissão
    group((-0.2, -0.35), (6.2, 5.95), [Geração])
    group((9.1, -0.35), (14.9, 5.95), [Submissão])

    // Geradores
    let generators = (
      ("acessos", [acessos], 4.45),
      ("operacoes", [operações], 2.6),
      ("conteudo", [conteúdo], 0.75),
    )
    for (name, title, y) in generators {
      node(name, (1.45, y), 2.9, 1.55, [
        Gerador de \ #title \
        #text(size: 7pt, fill: luma(80))[sintético ou _trace_]
      ])
      line((2.9, y), (3.35, y))
    }
    line((3.35, 4.45), (3.35, 0.75))
    line((3.35, 2.6), (3.8, 2.6), mark: arrow)

    node("produtor", (4.85, 2.6), 2.1, 1.5, [Produtor])

    // Canais de comunicação
    channel("pedidos", (7.65, 3.15), 2.3, request-fill, request-stroke)
    channel("retorno", (7.65, 2.05), 2.3, return-fill, return-stroke)
    content((7.65, 3.5), anchor: "south", align(center)[pedidos \ preenchidos])
    content((7.65, 1.7), anchor: "north", align(center)[estruturas \ livres])

    line((5.9, 3.15), "pedidos.west", mark: arrow)
    line("pedidos.east", (9.4, 3.15), mark: arrow)
    line((9.4, 2.05), "retorno.east", mark: arrow)
    line("retorno.west", (5.9, 2.05), mark: arrow)

    node("consumidor", (10.5, 2.6), 2.2, 1.5, [Consumidor])
    line((11.6, 2.6), (12.1, 2.6), mark: arrow)

    // Interface de E/S e respetivas implementações
    rect((12.1, -0.025), (14.6, 5.225), radius: 0.15)
    content((13.35, 5.05), anchor: "north", align(center)[Interface \ de E/S])
    let engines = ([POSIX], [AIO], [io_uring], [SPDK])
    for (i, engine) in engines.enumerate() {
      let y = 3.6 - i * 0.8
      rect((12.4, y - 0.3), (14.3, y + 0.3), radius: 0.1, fill: return-fill, stroke: 0.6pt + return-stroke)
      content((13.35, y), engine)
    }

    line((14.6, 2.6), (15.4, 2.6), mark: arrow)
    node("dispositivo", (16.6, 2.6), 2.4, 1.5, [Dispositivo], fill: luma(225))
  })
}

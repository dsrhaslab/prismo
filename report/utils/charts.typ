#import "@preview/lilaq:0.6.0" as lq

// Paleta por ferramenta, constante em todo o capítulo. As cores diferem também em
// luminosidade, de modo a permanecerem distinguíveis em impressão a preto e branco.
#let tool-colors = (
  prismo: rgb("#1f4e79"),
  fio: rgb("#e08214"),
  vdbench: rgb("#8c8c8c"),
)

#let tool-labels = (prismo: [Prismo], fio: [FIO], vdbench: [Vdbench])

// Séries por sistema de armazenamento, usadas nas figuras que comparam targets.
#let series-colors = tool-colors + (
  configurado: rgb("#8c8c8c"),
  medido: rgb("#1f4e79"),
  dev_nvme: rgb("#4d4d4d"),
  btrfs: rgb("#1f4e79"),
  zfs: rgb("#e08214"),
  original: rgb("#4d4d4d"),
  replay: rgb("#1f4e79"),
  extensao: rgb("#e08214"),
)

#let series-labels = tool-labels + (
  configurado: [Configurado], medido: [Medido (Deltoide)],
  dev_nvme: [NVMe], btrfs: [Btrfs], zfs: [ZFS],
  original: [Trace original], replay: [Fase de replay], extensao: [Fase de extensão],
)

// Nome curto de cada carga, o mesmo que o texto utiliza, apresentado no eixo das figuras em vez
// do número, de modo a que o leitor identifique a carga sem regressar à tabela que as descreve.
#let workload-names = (
  "01": "seqwrite", "02": "seqread", "03": "seqwrite64", "04": "randread",
  "05": "randrw", "06": "zipfrw", "07": "seqwrite90", "08": "fsync",
  "09": "randrw3j", "10": "compress", "11": "dedup", "12": "hybaccess",
  "13": "hybops", "14": "homes", "15": "webmail",
)

// Rótulos das categorias tal como surgem no texto, em vez dos identificadores dos CSV.
#let category-labels = (
  posix: [POSIX], uring: [io_uring], aio: [libaio], spdk: [SPDK],
  btrfs: [Btrfs], zfs: [ZFS],
)

#let category-tick(label) = {
  if label in workload-names {
    text(size: 7pt, raw(workload-names.at(label)))
  } else if label in category-labels {
    category-labels.at(label)
  } else {
    [#label]
  }
}

// Painéis de uma figura dispostos lado a lado ou empilhados, cada um com a largura que lhe cabe,
// de modo a que a legenda de cada painel possa quebrar linha sem empurrar o vizinho.
#let panels(columns: 2, ..charts) = grid(
  columns: (1fr,) * columns,
  column-gutter: 4pt,
  row-gutter: 14pt,
  align: center + bottom,
  ..charts.pos(),
)

// Lê um CSV de figura com o formato
//   workload,prismo,fio,vdbench,prismo_std,fio_std,vdbench_std
// e devolve as séries prontas a desenhar, ignorando as ferramentas sem valores.
// O caminho é resolvido a partir deste ficheiro, de modo a não depender da raiz
// configurada no compilador.
#let read-series(name) = {
  let table = csv("../data/" + name)
  let head = table.at(0)
  let rows = table.slice(1)
  // Metade das colunas úteis são valores e a outra metade desvios homónimos.
  let names = head.slice(1, 1 + int((head.len() - 1) / 2))
  (
    labels: rows.map(r => r.at(0)),
    series: names.enumerate()
      .filter(((i, n)) => rows.any(r => r.at(i + 1) != ""))
      .map(((i, n)) => (
        name: n,
        values: rows.map(r => if r.at(i + 1) == "" { 0.0 } else { float(r.at(i + 1)) }),
        errors: rows.map(r => {
          let k = i + 1 + names.len()
          if k >= r.len() or r.at(k) == "" { 0.0 } else { float(r.at(k)) }
        }),
      )),
  )
}

// Linhas por ferramenta ao longo das cargas. Espera-se um CSV com o formato
// workload,prismo,fio,vdbench, sem colunas de desvio.
#let tool-lines(name, ylabel: none, xlabel: [Carga], width: 12.2cm, height: 5.0cm) = {
  let rows = csv("../data/" + name).slice(1)
  let tools = ("prismo", "fio", "vdbench")
  let xs = range(rows.len())
  let marks = ("o", "s", "d")

  lq.diagram(
    width: width,
    height: height,
    xlabel: xlabel,
    ylabel: ylabel,
    legend: (position: right + top),
    xaxis: (ticks: xs.zip(rows.map(r => category-tick(r.at(0))))),
    ..tools.enumerate().map(((i, t)) => lq.plot(
      xs,
      rows.map(r => float(r.at(i + 1))),
      color: tool-colors.at(t),
      mark: marks.at(i),
      label: tool-labels.at(t),
    )),
  )
}

// Repartição do tempo de CPU por estado, em barras empilhadas. Espera-se um CSV com o
// formato workload,usr,sys,wai. O tempo restante corresponde a idle e não é desenhado,
// sob pena de as restantes componentes se tornarem ilegíveis.
#let cpu-states = (
  usr: (rgb("#1f4e79"), [Utilizador]),
  sys: (rgb("#5b9bd5"), [Sistema]),
  wai: (rgb("#e08214"), [Espera por @io]),
)

#let cpu-stack(name, width: 12.2cm, height: 5.0cm, headroom: 1.1) = {
  let rows = csv("../data/" + name).slice(1)
  let xs = range(rows.len())
  let values = ("usr", "sys", "wai").enumerate().map(((i, key)) => (
    key: key,
    data: rows.map(r => float(r.at(i + 1))),
  ))
  // O lq.bar desenha de `base` até `y`, ambos absolutos, pelo que cada camada recebe
  // o topo acumulado e não a altura do próprio segmento.
  let bases = ()
  let tops = ()
  let running = rows.map(_ => 0.0)
  for layer in values {
    bases.push(running)
    running = running.zip(layer.data).map(((a, b)) => a + b)
    tops.push(running)
  }

  // legenda numa única linha por cima da área de dados, tal como nos gráficos de barras agrupadas
  show lq.selector(lq.legend): set grid(columns: 2 * values.len(), column-gutter: 0.6em)
  lq.diagram(
    width: width,
    height: height,
    xlabel: [Carga],
    ylabel: [Tempo de @cpu (%)],
    ylim: (0, calc.max(..running) * headroom),
    legend: (position: bottom + center, dy: -100%, pad: 4pt),
    xaxis: (ticks: xs.zip(rows.map(r => category-tick(r.at(0))))),
    ..values.enumerate().map(((i, layer)) => lq.bar(
      xs,
      tops.at(i),
      base: bases.at(i),
      width: 0.62,
      fill: cpu-states.at(layer.key).at(0),
      label: cpu-states.at(layer.key).at(1),
    )),
  )
}

// Gráfico de barras agrupadas por ferramenta, com barras de erro correspondentes ao
// desvio padrão das execuções. As barras de erro só são desenhadas quando existe
// dispersão, o que evita marcas espúrias enquanto houver uma única execução. A legenda é
// disposta numa única linha por cima da área de dados, onde nunca tapa barras, e o expoente
// do eixo vertical é desativado para que os valores se leiam diretamente na unidade indicada.
//
// O `subcaption` identifica o painel quando o gráfico integra uma figura com vários, sendo
// desenhado por baixo do rótulo do eixo horizontal para ficar centrado na área de dados.
#let tool-bars(
  name, ylabel: none, xlabel: [Carga],
  width: 12.2cm, height: 5.4cm, yscale: auto, ylim: auto, legend: true, subcaption: none,
) = {
  let data = read-series(name)
  let n = data.series.len()
  // Enquanto não existirem valores, desenha-se apenas o referencial, de modo a que a
  // figura permaneça visível no documento e se preencha assim que os dados cheguem.
  let bar-width = 0.8 / calc.max(n, 1)
  let xs = range(data.labels.len())

  show lq.selector(lq.legend): set grid(columns: 2 * calc.max(n, 1), column-gutter: 0.6em)
  lq.diagram(
    width: width,
    height: height,
    xlabel: if subcaption == none { xlabel } else {
      // Nos painéis estreitos a legenda ocupa sempre duas linhas, para que gráficos lado a lado
      // mantenham os eixos alinhados mesmo quando uma das legendas cabe numa só.
      set par(leading: 0.45em, justify: false)
      stack(spacing: 9pt, xlabel, block(
        width: width,
        height: if width < 8cm { 2.3em } else { auto },
        text(size: 0.9em, subcaption),
      ))
    },
    ylabel: ylabel,
    yscale: yscale,
    ylim: ylim,
    legend: if legend == true { (position: bottom + center, dy: -100%, pad: 4pt) }
            else if type(legend) == alignment { (position: legend) } else { none },
    xaxis: (ticks: xs.zip(data.labels.map(category-tick))),
    yaxis: (exponent: 0),
    ..data.series.enumerate().map(((k, s)) => lq.bar(
      xs.map(x => x + (k - (n - 1) / 2) * bar-width),
      s.values,
      width: bar-width,
      fill: series-colors.at(s.name),
      label: series-labels.at(s.name),
    )),
    ..data.series.enumerate().filter(((k, s)) => s.errors.any(e => e > 0)).map(((k, s)) => lq.plot(
      xs.map(x => x + (k - (n - 1) / 2) * bar-width),
      s.values,
      yerr: s.errors,
      color: black,
      stroke: none,
    )),
  )
}

// Painel de barras horizontais para uma categoria de componentes. As barras horizontais
// acomodam nomes de variantes longos sem sobreposição, e cada painel mantém a sua própria
// escala, dado que o débito difere em ordens de grandeza entre categorias. O expoente é
// desativado para que os valores se leiam diretamente em milhões.
#let component-bars(name, categoria, title: none, width: 5.7cm, height: 3.6cm) = {
  let rows = csv("../data/" + name).slice(1).filter(r => r.at(0) == categoria)
  let ys = range(rows.len())
  lq.diagram(
    width: width,
    height: height,
    title: if title == none { categoria } else { title },
    xlabel: [Milhões de operações por segundo],
    xlim: (0, calc.max(..rows.map(r => float(r.at(2)))) * 1.1),
    xaxis: (exponent: 0),
    yaxis: (ticks: ys.zip(rows.map(r => [#r.at(1)])).map(((i, l)) => (i, l))),
    lq.hbar(rows.map(r => float(r.at(2))), ys, width: 0.6, fill: tool-colors.prismo),
  )
}

// Séries temporais das três estratégias de extensão, com uma linha vertical a assinalar o
// instante em que o ficheiro de trace se esgota e a extensão assume a geração. Espera-se um
// CSV com o formato indice,fase,repeat,sample,regression, onde `fase` toma os valores
// `replay` e `extensao`. Cada estratégia combina uma cor de matiz distinta com um padrão de
// traço próprio, de modo a que as séries se separem mesmo onde se cruzam ou em impressão a
// preto e branco.
#let extension-colors = (
  repeat: rgb("#1f4e79"),
  sample: rgb("#e08214"),
  regression: rgb("#b2182b"),
)

#let extension-strokes = (
  repeat: (thickness: 0.6pt),
  sample: (thickness: 0.6pt, dash: (2pt, 1pt)),
  regression: (thickness: 1.1pt, dash: "dash-dotted"),
)

#let extension-labels = (
  repeat: [Repetição], sample: [Amostragem], regression: [Regressão],
)

// Até ao corte as três estratégias reproduzem o mesmo trace, pelo que essa fase é desenhada
// uma única vez, numa cor neutra, e só a partir daí cada estratégia ganha a sua própria série.
#let replay-color = luma(110)

#let trace-lines(name, ylabel: none, xlabel: [Milhares de pedidos submetidos],
                 width: 10.4cm, height: 5.0cm) = {
  let rows = csv("../data/" + name).slice(1)
  let estrategias = ("repeat", "sample", "regression")
  let xs = rows.map(r => float(r.at(0)))
  // fronteira entre as duas fases, usada para posicionar a linha vertical
  let corte = rows.position(r => r.at(1) == "extensao")

  lq.diagram(
    width: width,
    height: height,
    xlabel: xlabel,
    ylabel: ylabel,
    // fixa o domínio para que o referencial se mantenha completo enquanto não houver séries
    xlim: (xs.first(), xs.last()),
    // a legenda fica fora da área de dados, que as séries ocupam por inteiro
    legend: (position: left + top, dx: 100%),
    ..if corte != none { (lq.plot(
        xs.slice(0, corte + 1),
        rows.slice(0, corte + 1).map(r => float(r.at(2))),
        mark: none,
        color: replay-color,
        stroke: 0.6pt,
        label: [Reprodução],
      ),) } else { () },
    ..estrategias.enumerate()
      .filter(((i, e)) => rows.any(r => r.at(i + 2) != ""))
      .map(((i, e)) => {
        let inicio = if corte == none { 0 } else { corte }
        lq.plot(
          xs.slice(inicio),
          rows.slice(inicio).map(r => if r.at(i + 2) == "" { 0.0 } else { float(r.at(i + 2)) }),
          mark: none,
          color: extension-colors.at(e),
          stroke: extension-strokes.at(e),
          label: extension-labels.at(e),
        )
      }),
    ..if corte != none { (lq.vlines(xs.at(corte),
        stroke: (paint: luma(90), dash: "dashed", thickness: 0.8pt)),) } else { () },
  )
}

// Séries por segundo de várias workloads sobre o mesmo referencial temporal. Espera-se um CSV com
// o formato segundo,wl04,wl05,wl06, sendo cada coluna desenhada como uma linha contínua sem marcas,
// dado que a densidade de pontos torna qualquer marcador ilegível.
#let workload-colors = (
  wl04: rgb("#4d4d4d"),
  wl05: rgb("#1f4e79"),
  wl06: rgb("#e08214"),
)

#let workload-labels = (
  wl04: [Aleatório, leitura], wl05: [Aleatório, 50/50], wl06: [Zipf(0.9), 50/50],
)

#let workload-lines(name, ylabel: none, xlabel: [Tempo de execução (s)],
                    width: 12.2cm, height: 5.0cm) = {
  let table = csv("../data/" + name)
  let colunas = table.at(0).slice(1)
  let rows = table.slice(1)
  let xs = rows.map(r => float(r.at(0)))

  lq.diagram(
    width: width,
    height: height,
    xlabel: xlabel,
    ylabel: ylabel,
    xlim: (xs.first(), xs.last()),
    legend: (position: right + top),
    ..colunas.enumerate()
      .filter(((i, c)) => rows.any(r => r.at(i + 1) != ""))
      .map(((i, c)) => lq.plot(
        xs,
        rows.map(r => if r.at(i + 1) == "" { 0.0 } else { float(r.at(i + 1)) }),
        mark: none,
        stroke: 0.5pt,
        color: workload-colors.at(c),
        label: workload-labels.at(c),
      )),
  )
}

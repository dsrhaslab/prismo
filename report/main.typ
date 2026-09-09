#import "@preview/prometeu-thesis:1.1.0": colors, thesis

#show: thesis(
  author: "Diogo Alexandre Correia Marques",
  title: [Realistic Benchmarking of Data Deduplication \ and  Compression Systems],
  date: [jully 2026],
  supervisors: (
    [João Tiago Medeiros Paulo],
    // [Co-Supervisor Name],
  ),
  cover-images: (image("logos/uminho/color/UM.jpg"), image("logos/uminho/color/EE.jpg")),
  cover-gray-images: (image("logos/uminho/gray/UM.jpg"), image("logos/uminho/gray/EE.jpg")),
  school: [School of Engineering],
  degree: [Master's Dissertation in Informatics Engineering],
  // Set this to "pt" for Portuguese titles
  language: "pt"
)

// Setup glossary and acronyms
#import "@preview/glossarium:0.5.9": *

#show: make-glossary
#let acronyms-data = yaml("acronyms.yml")
#register-glossary(acronyms-data)

#let show-acronyms = print-glossary(
  acronyms-data,
  // Change this to your liking
  show-all: true,
  disable-back-references: true,
  user-print-title: entry => {
    let description = if entry.long != none { h(0.5em) + entry.long + [.] }
    text(weight: "bold", entry.short) + description
  },
)

#let show-glossary = print-glossary(
  acronyms-data,
  // Change this to your liking
  show-all: true,
  disable-back-references: true,
  user-print-title: entry => {
    let title = if entry.long == none { entry.short } else { entry.long }
    text(weight: "bold", title) + h(0.5em) + entry.description
  },
  user-print-description: entry => if entry.description != none { [.] },
  description-separator: [],
)

// Setup index
#import "@preview/in-dexter:0.7.2": *

#[
  #set page(numbering: "i")
  // A capa não é numerada, mas conta, por isso o preâmbulo começa em 2
  #counter(page).update(2)

  // O preâmbulo não entra no índice
  #set heading(outlined: false, supplement: none, numbering: none)

  #include "preamble/copyright.typ"
  #pagebreak()
  #include "preamble/acknowledgements.typ"
  #pagebreak()
  #include "preamble/integrity.typ"
  #pagebreak()
  #include "preamble/abstract.typ"
  #pagebreak()
  #outline()
  #pagebreak()
  #outline(title: [Lista de Figuras], target: figure.where(kind: image))
  #pagebreak()
  #outline(title: [Lista de Tabelas], target: figure.where(kind: table))
  #pagebreak()
  = Acrónimos
  #show-acronyms
  #pagebreak()
  // = Glossary
  // #show-glossary
  // #pagebreak()
]

#counter(page).update(1)
#set heading(
  numbering: "1.1",
  // O supplement tem de depender do nível: "Capítulo" só para o nível 1,
  // caso contrário as referências a secções também diriam "Capítulo".
  supplement: it => if it.depth == 1 { [Capítulo] } else { [Secção] },
)

#set par(
  justify: true,
  spacing: 1em,
  first-line-indent: 1em,
)

#include "chapters/introduction.typ"
#include "chapters/background.typ"
#include "chapters/relatedwork.typ"
#include "chapters/architecture.typ"
#include "chapters/evaluation.typ"

#[
  #set heading(numbering: none)

  // Render bibliography
  // Change this to a .bib file if you prefer that format instead
  #bibliography("bibliography.yml", full: true)

  // Render index
  // #heading(level: 1, outlined: false)[Index]
  // #columns(
  //   2,
  //   make-index(
  //     title: none,
  //     use-page-counter: true,
  //     section-title: (letter, counter) => {
  //       set text(weight: "bold")
  //       block(letter, above: 1.5em)
  //     },
  //   ),
  // )
]

// #[
//   #counter(heading).update(0)
//   #set heading(numbering: "A.1", supplement: [Apêndice])
//   #include "appendix.typ"
// ]

#set page(numbering: none)

#page(fill: colors.pantonecoolgray7)[]

#pagebreak()

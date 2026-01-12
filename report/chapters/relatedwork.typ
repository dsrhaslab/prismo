#import "../utils/functions.typ" : raw_code_block

=== Trabalho Relacionado

A fim de explorar ferramentas que solucionem problemas semelhantes aos abordados na dissertação, esta secção procura explicar algumas das técnicas utilizadas para obter workloads mais realistas e assim avaliar com maior critério os sistemas de armazenamento.

Na verdade, o problema em questão não é completamente resolvido pelas ferramentas que se apresentam de seguida, cada uma sofre de limitações ao nível da geração de conteúdo, replicação de traces, ou suporte a diversas #link(<api>)[*APIs*] de #link(<io>)[*I/O*]. No entanto, convém perceber essas mesmas limitações para concluir em que medida a solução proposta se destaca das existentes.

==== DEDISbench

Tratando-se de um micro-benchmark de #link(<io>)[*I/O*] para sistemas de deduplicação orientados ao bloco, o DEDISbench gera dados com padrões de deduplicação semelhantes aos encontrados em ambientes reais, para isso serve-se do DEDISgen, que após analisar um dataset, resume a informação numa grelha que indica a quantidade de blocos com X cópias.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    inset: 6pt,
    align: horizon + left,
    fill: (x, y) => if y == 0 { gray.lighten(60%) },
    table.header(
      [*Nº de Cópias*], [*Nº de Blocos*],
      [*Blocos Únicos (%)*], [*Blocos Totais (%)*],
    ),
    [0], [2000], [50.00%], [22.73%],
    [1], [1000], [25.00%], [22.73%],
    [3], [600],  [15.00%], [27.27%],
    [5], [400],  [10.00%], [27.27%],
  ),
  caption: [Associação entre distribuição de duplicados e blocos totais]
) <dedisbenchdedup>

As duas primeiras colunas da @dedisbenchdedup representam a informação da distribuição de duplicados, sendo esta definida mediante a quantidade de cópias e blocos, neste caso em concreto, 2000 blocos não possuem qualquer cópia e portanto são únicos. Por outro lado, 400 blocos únicos apresentam cada um cinco cópias, resultando num total de 2400 blocos.

De facto, a forma como a distribuição é especificada dificulta a perceção da amostra total, apesar de 50% dos blocos únicos estarem contidos no mesmo grupo, esses representam somente um quarto da população total, pois à medida que a quantidade de cópias aumenta, o peso do grupo cresce proporcionalmente.

Neste sentido, o DEDISgen é responsável por fornecer a distribuição de duplicados num formato passível de interpretação ao DEDISbench, algo que mais tarde será replicado numa workload com padrões de acesso e débito definidos pelo utilizador.

- *Acesso Sequencial:* as operações de #link(<io>)[*I/O*] são realizadas de modo sequencial, o que beneficia a localidade espacial, visto os blocos encontrarem-se fisicamente próximos no sistema de armazenamento.

- *Acesso Uniforme:* os offsets são obtidos através de uma distribuição uniforme, daí que todas as zonas do disco sejam alvo da mesma carga, não havendo por isso benefícios obtidos através da localidade espacial ou temporal.

- *Acesso TPC-C:* uma distribuição com hotspots é responsável por estabelecer os padrões de acesso, consequentemente um subconjunto reduzido de blocos é alvo da maioria dos acessos, contribuindo assim para um bom uso da cache e reflexão do comportamento de partilha de blocos duplicados.

Em sentido semelhante, o DEDISbench permite manipular outros parâmetros da workload, dos quais se destacam a distribuição das operações de #link(<io>)[*I/O*] e o débito a que estas são realizadas, podendo ser nominal ou stress quando pretendemos extrair o máximo das capacidades do sistema de armazenamento.

Apesar desta versatilidade, a impossibilidade de simular traces e falta de suporte para interfaces assíncronas tornam a ferramenta pouco apetecível face aos dispositivos atuais que beneficiam as estratégias de polling face a interrupções, consequentemente não é possível atingir o máximo de performance.

Por outro lado, a própria distribuição de duplicados resulta numa limitação das workloads, uma vez que esta é definida em termos absolutos, ao ser atingido o limite de blocos únicos e respetivas cópias torna-se impossível continuar a escrever mais blocos, afinal não conseguimos depreender o grupo a que estes pertenceriam. Além disso, uma workload inferior àquela estabelecida pela distribuição resulta numa infração da taxa de duplicados, daí que a única forma de respeitar os limites seja não estender nem diminuir a distribuição.

==== DEDISbench++

Os sistemas de armazenamento modernos combinam técnicas de deduplicação e compressão para obter melhor desempenho, no entanto o DEDISbench não tem em conta as taxas de compressão no momento da geração de conteúdo, consequentemente as workloads tornam-se irrealista e não permitem uma avaliação fiel do sistema.

Face a este problema, o DEDISbench++ surge com o objetivo de permitir um controlo explícito sobre as taxas de compressibilidade intra e inter-bloco, sem que isso se reflita numa perda de performance, dado que a geração de conteúdo torna-se evidentemente mais custosa.

Posto isto, o DEDISgen foi alterado para capturar as taxas de duplicados e compressibilidade em simultâneo, resultando numa grelha que indica, para cada grupo de cópias, a percentagem total de blocos atribuídos e respetiva distribuição das taxas de compressão.

#let ecell = table.cell(
  fill: gray.lighten(60%),
  align: center,
)[*x*]

#figure(
  table(
    columns: (1fr, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto, auto),
    inset: 6pt,
    align: horizon + left,
    fill: (x, y) => if y == 0 { gray.lighten(60%) },
    table.header(
      [*Cópias*], [*Total*],
      [*10%*], [*20%*], [*30%*], [*40%*], [*50%*], [*60%*], [*70%*], [*80%*], [*90%*], [*100%*],
    ),
    [0], [22.73%], [15%], ecell, ecell, [20%], ecell, ecell, ecell, [65%], ecell, ecell,
    [1], [22.73%], ecell, ecell, ecell, ecell, [100%], ecell, ecell, ecell, ecell, ecell,
    [3], [27.27%], ecell, ecell, ecell, ecell, ecell, ecell, [80%], ecell, [20%], ecell,
    [5], [27.27%], ecell, ecell, [30%], ecell, ecell, ecell, ecell, [70%], ecell, ecell,
  ),
  caption: [Distribuição de duplicados e taxas de compressão]
) <dedisbenchplusplusdedup>

Ao contrário da distribuição gerada pela primeira versão do DEDISgen, desta vez os duplicados são definidos à custa de percentagens, como tal as limitações anteriormente referidas deixam de ser aplicável, pois os valores relativos são totalmente independentes do tamanho da workload, e portanto esta pode ser estendida indefinidamente.

Por outro lado, vemos que na @dedisbenchplusplusdedup as taxas de compressão intra-bloco são definidas à custa de setores percentuais, ou seja, no caso dos blocos com três cópias, inferimos que 80% deles comprime 70%, enquanto os restantes comprimem 90%. Na verdade, esta forma de representação é bastante inflexível, dado somente permitir a identificação de taxas múltiplas de dez.

Para cumprir os propósitos da compressão inter-bloco, o DEDISbench++ estabelece a existência de modelos que têm por base um buffer completamente aleatório, sendo este mais tarde replicado noutros buffers que comprimem 10%, 20%, 30%, .... Tendo isto em mente, o máximo de compressão inter-bloco é atingido quando dois blocos pertencem ao mesmo modelo, afinal ambos partilham o buffer de base.

Consequentemente, a criação de uma matriz com 100 modelos permite manipular a compressibilidade inter-bloco entre o seu mínimo e máximo, para isso basta encontrar o número de blocos que devem ser alocados ao primeiro modelo e distribuir de forma igualitária os restantes pelos outros modelos.

$
  P = (frac(n_1, N))^2
  arrow.l.r.double
  n_1 = sqrt(P) dot N
$

Se considerarmos $P$ como sendo a taxa de compreensão inter-bloco, isso implica que $P = 1$ corresponde ao máximo e portanto todos os blocos estão associados ao primeiro modelo, no entanto esta fórmula assume que o número total de blocos é conhecido à priori, o que nem sempre é verdade, especialmente em workloads que executam baseadas no tempo em vez do número de operações.

Em suma, apesar de incorporar a geração de conteúdo sintético com propriedades realistas de compressibilidade, o DEDISbench++ continua a sofrer das mesmas fragilidades apontadas ao seu antecessor, nomeadamente a replicação de traces e suporte a múltiplas interfaces de #link(<io>)[*I/O*], no entanto até a definição das taxas de compressão revela debilidades, quer por exigir conhecer o número total de blocos, quer por limitar a sua especificação a múltiplos de dez.

==== FIO

No que se refere ao estado da arte da avaliação de sistemas de armazenamento, o #link(<fio>)[*FIO*] é a ferramenta mais avançada e amplamente utilizada pela comunidade. Além de permitir a manipulação duma infinidade de parâmetros relativos à workload, que vão desde os padrões de acesso, distribuição das operações, escolha da interface de #link(<io>)[*I/O*] e definição de barreiras, as métricas obtidas são de fácil compreensão e um bom indicador das capacidades do sistema de armazenamento.

#figure(
  raw_code_block[
  ```
  seqwrite: (groupid=0, jobs=1): err= 0: pid=144197: Wed Dec 31 00:02:02 2025
   write: IOPS=108k, BW=421MiB/s (442MB/s)(1024MiB/2432msec); 0 zone resets
     clat (usec): min=2, max=19254, avg= 8.73, stdev=232.88
      lat (usec): min=2, max=19254, avg= 8.79, stdev=232.89
    iops        : min=53222, max=210414, avg=97548.50, stdev=75543.88, samples=4
   lat (usec)   : 4=58.64%, 10=35.29%, 20=5.15%, 50=0.83%, 100=0.03%
   lat (usec)   : 250=0.02%, 500=0.01%
   cpu          : usr=6.29%, sys=49.77%, ctx=94, majf=0, minf=9
   IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
      submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
      complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
  ```
  ],
  caption: [Métricas recolhidas pelo FIO]
)

Numa breve análise dos resultados obtidos através de uma execução do #link(<fio>)[*FIO*] com os parâmetros default, reparamos que a workload em questão foi executada por uma única thread, sendo o trabalho sequencial e de escritas constantes, o que resultou num débito de 421MiB/s e 108k #link(<iops>)[*IOPS*].

Por outro lado, uma vez que a engine utilizada é síncrona, todas as operações foram realizadas com uma #link(<io>)[*IO*] depth igual a um, no entanto a submissão foi realizada em grupos de quatro para reduzir o impacto das system calls e extrair maior proveito do sistema de armazenamento, algo que na verdade tornou-se escusado, visto 50% do tempo de #link(<cpu>)[*CPU*] ter sido consumido a resolver syscalls.

Por fim, a latência das operações manteve-se significativamente baixa, com 58% dos pedidos a serem respondidos em menos de quatro microsegundos e somente 0.03% a demorarem entre 250 e 500 microssegundos, no fundo isto indica uma utilização eficiente da cache ou então de um #link(<nvme>)[*NVMe*] deveras performante.

Apesar desta diversidade de configurações, os requisitos para obter workloads realistas são um pouco mais complexos do que as ofertas do #link(<fio>)[*FIO*], por exemplo, a geração de duplicados é obtida através da flag `dedupe_percentage=int`, que tal como o nome indica, estabelece a percentagem de blocos duplicados, no entanto isto é conseguido repetindo X vezes o mesmo bloco, o que não reflete minimamente as situações encontradas em ambientes reais.

Por outro lado, a compressão é alcançada com a flag `buffer_compress_chunk=int`, assim uma determinada zona do bloco é repetida para atingir uma compressibilidade de X%, porém isso significa que todos os blocos irão comprimir na mesma taxa, algo que o DEDISbench++ resolvia ao atribuir distribuições diferentes por grupo de cópias.

Em suma, estes fatores contribuem para que a geração de conteúdo do #link(<fio>)[*FIO*] não respeite os critérios de duplicados e compressibilidade que gostaríamos de ver nas workloads, além disso os traces do #link(<fiu>)[*FIU*] vêm acompanhados com a identificação do processo responsável pela operação de #link(<io>)[*I/O*], algo que o #link(<fio>)[*FIO*] não é capaz de reproduzir por as workloads não serem partilhadas entre processos, quando muito dívidas.

=== Discussão

Após a experienciação das ferramentas anteriormente mencionadas, destaca-se que os requisitos para workloads realistas são cumpridos apenas parcialmente, contudo a combinação das configurações que cada uma oferece aproxima-nos no objetivo final, ou seja, se o #link(<io>)[*FIO*] conseguisse replicar a estratégia de duplicados e compressão do DEDISbench++ e ao mesmo tempo manter o suporte a múltiplas #link(<api>)[*APIs*] de #link(<io>)[*I/O*], somente ficava por resolver a questão da simulação de traces do #link(<fiu>)[*FIU*].

Ademais, a integração entre workloads geradas sinteticamente e traces obtidos em ambiente de produção, é algo totalmente inovador e que soluciona os problemas resultantes de traces incompletos, deste modo as informações em falta seriam geradas artificialmente através de uma distribuição escolhida pelo utilizador ou então conforme um padrão.

Numa outra perspectiva, os traces tendem a ser bastante limitados pelo seu tempo de duração, daí que estender o próprio trace após a sua conclusão permitiria continuar a avaliar o sistema sobre condições reais de funcionamento, algo que nenhum dos benchmark é capaz de fazer em tempo de execução e sem prejudicar a performance da workload.

Por fim, apesar do #link(<fio>)[*FIO*] suportar imensas interfaces de #link(<io>)[*I/O*], a utilização do #link(<spdk>)[*SPDK*] é conseguida através de um plugin cuja utilização é extremamente complicada, nesse sentido o suporte direto de #link(<spdk>)[*SPDK*] no benchmark seria uma melhoria considerável em termos da facilidade de uso.
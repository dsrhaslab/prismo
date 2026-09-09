#import "../utils/functions.typ" : raw_code_block

= Arquitetura <chapter3>

Depois de esclarecido o problema da avaliação realista dos sistemas de armazenamento e compreendidos os conceitos em seu redor, este capítulo visa abordar a arquitetura do benchmark, passando pelo modelo de execução que fundamenta a interação entre componentes, as estratégias adotadas para geração de workloads sintéticas e baseadas em traces, a integração com @api:pl de @io de natureza diversa e o sistema de recolha de métricas @didona2022 @ren2023.

Numa primeira abordagem ao problema, a geração de conteúdo é facilmente dissociável das operações solicitadas ao sistema de armazenamento, sendo estas realizadas por meio das @api:pl de @io. Deste modo, a arquitetura pode ser dividida em dois grandes componentes que estabelecem cada um interfaces para manipulação da conduta: a geração de parâmetros da workload e a submissão de pedidos ao dispositivo @didona2022 @ren2023. A interface de geração abstrai as implementações concretas, daí que a sua utilização não implique desvios de padrão caso o utilizador escolha usufruir de dados sintéticos ou reais obtidos através de traces, do mesmo modo esta lógica é aplicável para a interface de abstração do disco @tracegen2024 @gracia-tinedo2015.

== Modelo de Execução <execution-model>

A execução de uma workload envolve a orquestração de múltiplos componentes que cooperam segundo um modelo produtor-consumidor @didona2022 @ren2023. Um produtor é responsável por invocar os métodos da interface de geração de conteúdo e encapsular os resultados num pedido de @io, sendo este colocado numa fila concorrente como forma de solicitação de execução. Do outro lado, um consumidor está constantemente à escuta na fila com o objetivo de receber pedidos, mal isto ocorra, é realizada uma submissão na interface de @io, sendo mais tarde a estrutura do pedido libertada e transmitida ao produtor para nova utilização.

=== Canais de Comunicação

A comunicação entre produtor e consumidor é realizada através de duas filas concorrentes lock-free @moodycamel: a primeira transporta os pedidos preenchidos do produtor para o consumidor, enquanto a segunda devolve as estruturas cujo pedido já foi concluído, possibilitando a sua reutilização sem alocações dinâmicas durante a execução.

Uma vez que as filas apresentam capacidade limitada, e tendo em consideração que à partida o produtor será mais performante que o consumidor, este mecanismo permite alcançar buffering e backpressure em simultâneo, pois quando a capacidade limite for atingida, o produtor irá bloquear e portanto o consumidor jamais será sobrecarregado com uma quantidade infindável de pedidos, o que contribui para um uso eficiente da memória disponível.

O benchmark disponibiliza dois modos de operação para os canais: bloqueante e não-bloqueante. No modo bloqueante, a operação de dequeue suspende a thread caso a fila esteja vazia, sendo esta retomada quando um novo elemento é inserido, resultando num consumo energético reduzido @didona2022. Em contrapartida, o modo não-bloqueante mantém a thread em busy-wait até que um elemento esteja disponível, sacrificando ciclos de @cpu em troca de menor latência de resposta @ren2023.

Para maximizar o débito, as operações de enqueue e dequeue são realizadas em bulk, transferindo até 64 pacotes por invocação, o que amortiza o custo de sincronização entre threads e melhora a utilização da cache do processador @ren2023. Além disso, um pool de 1024 pacotes é pré-alocado durante a inicialização do canal, eliminando a necessidade de alocação de memória no caminho crítico de execução @didona2022.

=== Terminação

O controlo de terminação define o critério de paragem da workload, sendo suportadas duas estratégias configuráveis @ren2023. A terminação por iterações encerra a execução após a geração de um número fixo de pedidos, enquanto a terminação por tempo de execução impõe um limite temporal em milissegundos.

#figure(
  grid(
    columns: 2,
    gutter: 10pt,
    raw_code_block[
      ```yaml
      termination:
        type: iterations
        value: 10000000
      ```
    ],
    raw_code_block[
      ```yaml
      termination:
        type: runtime
        value: 900000
      ```
    ],
  ),
  caption: [Configuração das estratégias de terminação]
)

A verificação da condição de terminação temporal é otimizada para evitar o custo excessivo de invocações ao relógio do sistema, sendo a consulta real do tempo realizada apenas a cada 4096 iterações @ren2023. Esta técnica de lazy time check reduz significativamente o overhead em workloads de alta frequência sem comprometer a precisão do limite temporal estabelecido.

=== Paralelismo

O benchmark suporta a execução paralela de múltiplos jobs sobre o mesmo dispositivo, sendo cada job constituído por um par produtor-consumidor independente que opera sobre canais dedicados @ren2023 @didona2022. O número de jobs é definido pelo parâmetro `numjobs`, resultando na criação de $2 times n$ threads, ou seja, uma de produção e outra de consumo.

Cada job instancia os seus próprios geradores de acesso, operação e conteúdo, sendo o espaço de endereçamento automaticamente particionado entre os workers para evitar colisões de offset @ren2023. Deste modo, o gerador de acessos recebe o identificador do worker e o número total de jobs, dividindo o espaço disponível em partições equitativas.

Esta abordagem permite avaliar o comportamento do sistema de armazenamento sob carga concorrente, algo fundamental na caracterização de cenários multi-tenant e na identificação de contenção entre threads de @io @didona2022.

=== Rampa de Aquecimento

Em determinadas avaliações, é desejável que a carga de trabalho aumente progressivamente até atingir o débito máximo, evitando assim o enviesamento dos resultados iniciais causado pela inicialização de caches e estruturas internas do sistema de armazenamento @ren2023.

Para este efeito, o benchmark disponibiliza uma rampa de aquecimento configurável que realiza interpolação linear entre um rácio inicial e final ao longo de uma duração especificada em milissegundos. Quando o rácio corrente é inferior a 1.0, o produtor introduz um atraso proporcional à duração do batch, regulando assim o débito de submissão sem alterar a lógica dos geradores @ren2023.

#figure(
  raw_code_block[
    ```yaml
    ramp:
      start_ratio: 0.1
      end_ratio: 1.0
      duration: 60000
    ```
  ],
  caption: [Configuração da rampa de aquecimento]
)

Por esta lógica, quando o rácio inicial é inferior ao final, a rampa de aquecimento aumenta gradualmente o débito de submissão, sendo o contrário inverso igualmente válido, oferecendo ao utilizador a flexibilidade de acelerar ou desacelerar a carga de trabalho conforme necessário @ren2023.

== Geração de Workloads

Na generalidade das interfaces, os pedidos de @io são caracterizados pelo tipo de operação, conteúdo e posição do disco onde o pedido será satisfeito, consequentemente a geração de workloads pode ser desacoplada nestas três funcionalidades, dando origem a interfaces independentes para cada dimensão dos pedidos @gracia-tinedo2015 @talwadker2014.

Como fruto desta abordagem, e uma vez que os geradores são definidos ao nível dos parâmetros, a combinação entre geradores sintéticos e reais torna-se bastante simples, isto porque o produtor apenas conhece uma interface que é independente da implementação concreta, assim podemos ter acessos reais e operações sintéticas, sendo o contrário igualmente válido @gracia-tinedo2015 @pang2026.

#figure(
  image("../images/producer.png", width: 60%),
  caption: [Interação do produtor com a interface de geração de conteúdo]
)

Ao recolher uma struct através da operação de dequeue, o produtor invoca os métodos disponibilizados por cada uma das interfaces, de relembrar que o conteúdo do bloco apenas é gerado quando a operação solicitada for um `WRITE`. De seguida, e tendo os parâmetros devidamente identificados, os mesmos são encapsulados num pedido que é inserido na fila para futura execução por parte do consumidor.

=== Acesso

Os pedidos de `READ` e `WRITE` necessitam de ser identificados pela zona do disco onde a operação irá ocorrer, neste sentido a interface `AccessGenerator` disponibiliza o método `nextAccess` que devolve o offset da próxima operação a realizar, sendo de realçar que nem todas as implementações concretas apresentam a mesma performance, pois algumas seguem distribuições enquanto outras utilizam aritmética simples @tracegen2024 @gracia-tinedo2015.

#figure(
  image("../images/access.png", width: 60%),
  caption: [Hierarquia da interface de acessos]
)

Dado que os acessos são realizados ao nível do bloco, todas as implementações devem conhecer o tamanho do bloco e o limite da zona do disco até onde é permitido ler ou escrever, deste modo os offsets devolvidos serão inferiores ou iguais ao limite e acima de tudo múltiplos do tamanho do bloco @tracegen2024.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```yaml
      type: sequential
      blocksize: 4096
      size: 65536
      ```
    ],
    raw_code_block[
      ```yaml
      type: random
      blocksize: 4096
      size: 65536
      ```
    ],
    raw_code_block[
      ```yaml
      type: zipfian
      blocksize: 4096
      size: 65536
      skew: 0.99
      ```
    ],
  ),
  caption: [Configuração dos geradores de acesso]
)

A implementação do tipo sequencial é responsável por devolver os offsets num padrão contínuo, sendo que o alcance do limite implica o reposicionamento no offset zero, esta estratégia beneficia claramente a localidade espacial, pois as zonas do disco são acedidas num padrão favorável @tracegen2024.

Por outro lado, os acessos totalmente aleatórios não favorecem quaisquer propriedades de localidade, daí que sejam especialmente úteis para evitar uma utilização eficiente da cache @tracegen2024. Por fim, os acessos zipfian seguem uma distribuição cuja skew pode ser manipulada pelo utilizador, neste sentido cargas de trabalho com hotspots são facilmente replicáveis por esta implementação @tracegen2024.

=== Operação

Os sistemas de armazenamento suportam uma infinidade de operações, no entanto o gerador de operações apenas disponibiliza `READ`, `WRITE`, `FSYNC`, `FDATASYNC` e `NOP` por serem as mais comuns e portanto adotadas pela maioria das @api:pl de @io @didona2022 @ren2023. Embora a operação `NOP` não faça rigorosamente nada, a mesma é útil para testar a performance do benchmark independente da capacidade do disco, permitindo identificar o débito máximo que o sistema de armazenamento pode almejar @ren2023.

#figure(
  image("../images/operation.png", width: 60%),
  caption: [Hierarquia da interface de operações]
)

A implementação do tipo constante é a mais simples, isto porque devolve sempre a mesma operação que foi definida previamente pelo utilizador. Em contrapartida, as operações percentuais são obtidas à custa de uma distribuição cujo somatório das probabilidade deve resultar em 100, exemplificando com a configuração abaixo, metade das operações serão `READS` e as restantes `WRITES` @ren2023.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```yaml
      type: constant
      operation: write
      ```
    ],
    raw_code_block[
      ```yaml
      type: percentage
      percentages:
          read: 50
          write: 50
      ```
    ],
    raw_code_block[
      ```yaml
      type: sequence
      operations:
          - write
          - fsync
      ```
    ],
  ),
  caption: [Configuração dos geradores de operações]
)

Por fim, a replicação de padrões é obtida com recurso à implementação de sequência, sendo o utilizador responsável por definir uma lista de operações que mais tarde será repetidamente devolvida, neste caso em concreto, se o método `nextOperation` fosse invocado cinco vezes, as operações seriam devolvidas pela ordem: `WRITE`, `FSYNC`, `WRITE`, `FSYNC`, `WRITE` @ren2023.

==== Barreiras

Em determinados cenários, torna-se necessário injetar operações de sincronização após a execução de um número definido de escritas, algo particularmente relevante na simulação de workloads reais onde os sistemas de ficheiros periodicamente forçam a persistência dos dados em disco @ren2023.

Para tal, o benchmark disponibiliza um mecanismo de barreiras que interceta o fluxo de operações e substitui a operação corrente por outra previamente definida, sendo esta injeção despoletada quando o número de operações monitorizadas atinge um limiar configurável @didona2022. Por exemplo, uma barreira com threshold de 1024 e trigger do tipo `WRITE` injeta uma operação de `FSYNC` a cada 1024 escritas, independentemente da lógica do gerador de operações subjacente.

#figure(
  raw_code_block[
    ```yaml
    barrier:
      - threshold: 1024
        trigger: write
        operation: fsync
      - threshold: 512
        trigger: read
        operation: fdatasync
    ```
  ],
  caption: [Configuração de múltiplas barreiras]
)

A composição de múltiplas barreiras é igualmente suportada, sendo estas ordenadas pelo critério de proximidade ao respetivo limiar, deste modo a barreira com menor número de operações em falta é avaliada prioritariamente @ren2023. Importa realçar que após cada injeção, a reordenação dinâmica é realizada para garantir que o escalonamento reflete o estado atualizado dos contadores, evitando assim situações de starvation entre barreiras com limiares distintos.

=== Conteúdo

A geração de conteúdo é sem dúvida a operação mais custosa, no entanto apenas torna-se necessária quando a operação selecionada for um `WRITE`, nesse sentido a interface `BlockGenerator` disponibiliza o método `nextBlock` que preenche um buffer passado como argumento @constantinescu2011 @meyer2012.

Embora a implementação principal desta interface seja aquela que combina duplicados e compressão, existem outras mais rudimentares que servem para testar cenários específicos com maior eficiência, isto porque o gerador de duplicados é capaz de simular os blocos dos outros geradores, mas com uma performance significativamente menor @koller2010 @zhu2008 @talasila2019.

#figure(
  image("../images/block.png", width: 60%),
  caption: [Hierarquia da interface de geração de blocos]
)

Tal como seria expectável, os geradores necessitam de conhecer o tamanho do bloco, deste modo podem garantir que os limites dos buffers jamais serão violados. A implementação mais simplista deste gerador corresponde ao constante, que devolve sempre o mesmo buffer, resultando numa deduplicação e compressibilidade interbloco máximas. Por outro lado, o aleatório tem exatamente o comportamento oposto, pois ao devolver buffers diferentes não existem duplicados e a entropia é elevada, resultando em dados virtualmente incompressíveis @constantinescu2011.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```yaml
      type: constant
      blocksize: 4096
      ```
    ],
    raw_code_block[
      ```yaml
      type: random
      blocksize: 4096
      ```
    ],
    raw_code_block[
      ```yaml
      type: dedup
      blocksize: 4096
      refill_buffers: false
      ```
    ],
  ),
  caption: [Configuração dos geradores de blocos]
)

Por fim, o gerador de duplicados e compressão procura seguir uma distribuição de duplicados definida pelo utilizador, esta estabelece a percentagem de blocos que terão X cópias, sendo que cada grupo de cópias tem associada uma distribuição de compressão, indicando que Y% dos blocos reduz cerca de Z% @constantinescu2011 @paulo2014.

Além disso, a opção `refill_buffers` permite a partilha do buffer base entre blocos, deste modo quando os mesmos são criados a zona de entropia máxima é obtida a partir do buffer, consequentemente todos os blocos partilham a mesma informação e portanto a compressibilidade interbloco atinge o limite @constantinescu2011 @paulo2014.

==== Deduplicação e Compressão

Para que o utilizador manipule a distribuição de duplicados e compressão, o benchmark oferece um ficheiro de configuração sobre o qual as informações são retiradas, bastando seguir o formato indicado @dedisbench @dedisbenchpp @paulo2013.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```yaml
      - percentage: 50
          repeats: 1
          compression:
          - percentage: 40
            reduction: 10
          - percentage: 60
            reduction: 50
      ```
    ],
    raw_code_block[
      ```yaml
      - percentage: 30
          repeats: 2
          compression:
          - percentage: 20
            reduction: 20
          - percentage: 80
            reduction: 10
      ```
    ],
    raw_code_block[
      ```yaml
      - percentage: 20
          repeats: 3
          compression:
          - percentage: 40
            reduction: 30
          - percentage: 60
            reduction: 0
      ```
    ],
  ),
  caption: [Especificação da distribuição de duplicados e compressão]
)

A distribuição de duplicados e compressão é definida de modo particular, inicialmente é realizada uma associação entre o número de cópias e a respetiva probabilidade, sendo mais tarde definidas as taxas de compressão dentro de cada grupo @constantinescu2011 @paulo2014.

#grid(
  columns: 2,
  gutter: 5pt,
  [
    #figure(
      image("../images/deduplication.png", width: 100%),
      caption: [Mapa dos duplicados],
    ) <dedup-map>
  ],
  [
    #figure(
      image("../images/compression.png", width: 100%),
      caption: [Mapa das taxas de compressão],
    ) <compression-map>
  ],
)

A @compression-map representa a estrutura sobre a qual as taxas de compressão são armazenadas para cada grupo, sendo basicamente um mapa que associa o número de repetições a uma lista formada por tuplos de percentagem cumulativa e respetiva redução @constantinescu2011 @paulo2014.

Por outro lado, a @dedup-map é responsável por gerir os blocos duplicados e tem um funcionamento semelhante ao de uma sliding window, onde os tuplos da lista são constituídos pelo identificador de bloco e cópias que faltam efetuar @talasila2019 @policroniades2004.

O funcionamento do algoritmo é bastante simples, inicialmente uma entrada do mapa é selecionada conforme as probabilidades do ficheiro de configuração, a partir daí, caso a lista não tenha atingido o limite de elementos, um novo é adicionado com o número de cópias igual ao de repetições @talasila2019.

Na situação em que a lista encontra-se completa, um dos elementos é selecionado aleatoriamente e o valor das cópias em falta é decrementado uma unidade, ao ser atingido o valor zero a entrada é definitivamente retirada da lista, pois o bloco já foi repetido as vezes necessárias @talasila2019.

Por fim, depois de selecionado o identificador do bloco, volta a ser sorteado um número aleatório para descobrir a taxa de compressão a aplicar, de relembrar que a distribuição é obtida pela entrada do mapa selecionada inicialmente @constantinescu2011 @paulo2014.

Apesar de ser bastante eficiente, esta abordagem acarreta o custo associado à geração pseudoaleatória, uma operação que tende a ser mais exigente computacionalmente do que as restantes envolvidas na geração de conteúdo. Para mitigar este custo, a implementação faz uso do gerador SHISHUA @shishua, que realiza gerações massivas em buffer, permitindo à aplicação recolher valores pseudo-aleatórios com latência reduzida. Desta forma, o custo permanece negligenciável quando comparado com o tempo das operações de @io, não constituindo um gargalo na avaliação do sistema de armazenamento.

=== Workloads Baseadas em Traces <trace-workloads>

Embora os geradores sintéticos ofereçam elevada flexibilidade na parametrização das workloads, a reprodução de comportamentos observados em ambientes de produção exige a utilização de traces reais, os quais capturam a sequência temporal de operações de @io executadas por sistemas em funcionamento @gracia-tinedo2015 @tracegen2024.

Neste sentido, cada um dos três geradores previamente descritos (acesso, operação e conteúdo) disponibiliza uma implementação do tipo `trace`, sendo esta responsável por consumir registos de um ficheiro binário e extrair a dimensão correspondente, nomeadamente o offset, tipo de operação e identificador de bloco @tracegen2024 @pang2026.

#figure(
  raw_code_block[
    ```cpp
    struct Record {
        uint64_t timestamp;
        uint32_t pid;
        uint64_t process;
        uint64_t offset;
        uint32_t size;
        uint32_t major;
        uint32_t minor;
        uint64_t block_id;
        Operation::OperationType operation;
    };
    ```
  ],
  caption: [Estrutura de um registo do trace]
)

A leitura dos traces é realizada por um componente partilhado entre todas as implementações `trace-based`, o qual mantém um buffer de leitura configurável pelo utilizador através do parâmetro `memory`, evitando assim carregamentos excessivos em memória quando o trace excede a capacidade disponível.

Uma vez que os geradores são definidos ao nível dos parâmetros individuais e o produtor conhece apenas a interface abstrata de cada um, a combinação entre geradores sintéticos e trace-based torna-se trivial @gracia-tinedo2015 @pang2026. Exemplificando, é possível utilizar acessos provenientes de um trace real enquanto as operações seguem uma distribuição percentual sintética e o conteúdo é gerado pelo modelo de deduplicação e compressão.

#figure(
  grid(
    columns: 2,
    gutter: 10pt,
    raw_code_block[
      ```yaml
      access:
        type: trace
        trace: homes.prismo
        extension: sample
        memory: 16384
      operation:
        type: percentage
        percentages:
          read: 70
          write: 30
      content:
        type: dedup
        refill_buffers: true
        distribution: [...]
      ```
    ],
    raw_code_block[
      ```yaml
      access:
        type: zipfian
        skew: 0.9
      operation:
        type: trace
        trace: homes.prismo
        extension: repeat
        memory: 16384
      content:
        type: trace
        trace: homes.prismo
        extension: regression
        memory: 16384
      ```
    ],
  ),
  caption: [Exemplos de configuração de workloads híbridas]
)

Esta abordagem constitui uma das principais contribuições do benchmark, pois permite colmatar as limitações temporais dos traces com a extensibilidade dos geradores sintéticos, resultando em workloads que preservam as propriedades estatísticas do ambiente real sem estarem confinadas à duração original da captura @tracegen2024 @pang2026.

=== Extensões de Trace <trace-extensions>

O problema fundamental da utilização de traces prende-se com a sua natureza finita, pois ao atingir o final do ficheiro torna-se necessário decidir como prosseguir com a geração de pedidos @tracegen2024. Para resolver esta limitação, o benchmark implementa três estratégias de extensão que diferem no grau de sofisticação e fidelidade ao trace original.

==== Repetição

A extensão mais elementar consiste na repetição cíclica do trace, onde ao atingir o final do ficheiro o leitor é reposicionado no início e os registos são novamente devolvidos pela mesma ordem @tracegen2024. Embora esta abordagem preserve perfeitamente a sequência original, a mesma não introduz variabilidade e portanto a workload resultante é estritamente periódica, algo que pode não refletir o comportamento real de um sistema em produção continuada.

==== Amostragem

A segunda estratégia opera em duas fases distintas, sendo a primeira dedicada à recolha de amostras representativas do trace através de reservoir sampling @vitter1985, garantindo que cada registo do trace tem igual probabilidade de ser incluído independentemente do tamanho do ficheiro @tracegen2024.

Ao atingir o final do trace, a segunda fase é iniciada com a construção de alias tables para cada dimensão @walker1977 @vose1991, sendo esta estrutura de dados capaz de gerar amostras em tempo constante $O(1)$ a partir das distribuições marginais observadas @tracegen2024. Desta forma, os registos sintéticos gerados após o trace preservam as frequências relativas de cada offset, operação e identificador de bloco, embora a correlação entre dimensões não seja mantida por estas serem amostradas de forma independente.

==== Regressão

A extensão mais sofisticada procura capturar não apenas as distribuições marginais mas também as correlações entre as várias dimensões do trace, recorrendo para isso a um modelo de regressão linear bivariada @tracegen2024.

À semelhança da amostragem, a primeira fase é dedicada à recolha de dados, sendo acumulados até `max_samples` registos nos vetores de offsets, operações e identificadores de bloco. Seguidamente, na transição para a segunda fase, dois modelos lineares acoplados são ajustados por mínimos quadrados:

$
"operation" = a_0 + a_1 dot "offset" + a_2 dot "block_id"
$

$
"block_id" = b_0 + b_1 dot "offset" + b_2 dot "operation"
$

A resolução é realizada através de decomposição ortogonal completa, garantindo estabilidade numérica mesmo perante sistemas mal condicionados. Para a geração de novos registos, os dois modelos são resolvidos em simultâneo como um sistema $2 times 2$, onde o offset é extrapolado linearmente a partir do último valor observado no trace e do passo médio entre registos consecutivos @tracegen2024.
$
y = a_0 + a_1 x + a_2 z
$

$
z = b_0 + b_1 x + b_2 y
$

Reorganizando:

$
y - a_2 z = a_0 + a_1 x
$

$
-b_2 y + z = b_0 + b_1 x
$

Na forma matricial:

$
mat(
  1, -a_2;
  -b_2, 1
)
mat(
  y;
  z
)
=
mat(
  a_0 + a_1 x;
  b_0 + b_1 x
)
$

#figure(
  table(
    columns: (1fr, 1fr, 1.5fr, 1.5fr),
    inset: 8pt,
    align: horizon + left,
    fill: (x, y) => if y == 0 { gray.lighten(60%) },
    table.header(
      [*Propriedade*], [*Repetição*], [*Amostragem*], [*Regressão*]
    ),
    [Extrapolação], [Cíclica], [Limitada ao reservatório], [Linear além do trace],
    [Correlações], [Preservadas], [Perdidas (independência)], [Capturadas (modelo linear)],
    [Memória], [$O(n_"buffer")$], [$O(n_"reservoir")$], [$O(1)$ (matrizes pequenas)],
    [Complexidade], [$O(1)$], [$O(1)$], [$O(1)$],
    [Variabilidade], [Nenhuma], [Elevada], [Moderada],
  ),
  caption: [Comparação entre as estratégias de extensão de traces]
)

Desta forma, a extensão por regressão é particularmente adequada quando se pretende prolongar a workload para além da duração do trace mantendo as dependências estruturais entre as dimensões, algo que a amostragem independente não consegue garantir @tracegen2024 @pang2026.

== Interfaces de I/O

Tendo em consideração o modelo de execução previamente descrito, o consumidor recebe os pedidos do produtor e procede de imediato ao desencapsulamento para compreender o tipo de operação em questão e assim facilitar o acesso aos restantes parâmetros, como offset e conteúdo @didona2022.

A interface `Engine` disponibiliza o método `submit` que aceita operações de qualquer tipo, assim o consumidor não é responsável por definir as alterações de comportamento associadas @ren2023. Mal o pedido seja dado por concluído, a struct é devolvida pela interface, permitindo ao consumidor fazer dequeue para que a zona de memória seja reutilizada mais tarde.

#figure(
  image("../images/consumer.png", width: 60%),
  caption: [Interação do consumidor com a interface de engine]
)

Um pedido obtido a partir da fila pode ser de três tipos distintos, onde as structs de abertura e fecho são caracterizadas pelos argumentos encontrados nas syscalls de `open` e `close`, importa realçar que tais estruturas não fazem sentido para a engine de @spdk, visto esta funcionar diretamente sobre o dispositivo de armazenamento e portanto não existir uma abstração do sistema de ficheiros @spdk_docs.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```c
      struct CloseRequest {
          int fd;
      };
      ```
    ],
    raw_code_block[
      ```c
      struct OpenRequest {
        int flags;
        mode_t mode;
        char* filename;
      };
      ```
    ],
    raw_code_block[
      ```c
      struct CommonRequest {
          int fd;
          size_t size;
          uint64_t offset;
          uint8_t* buffer;
          Metadata metadata;
          OperationType op;
      };
      ```
    ]
  ),
  caption: [Estrutura dos vários tipos de pedidos]
)

Perante a combinação de interfaces síncronas e assíncronas, o método `submit` nem sempre devolve uma struct para reutilização, pois, no caso das interfaces assíncronas nunca sabemos exatamente quando o pedido será dado por concluído e além disso não é possível esperar até que tal aconteça, caso contrário estaria a ser dado comportamento síncrono e as vantagens de paralelismo seriam perdidas @uring_kernel @rust_iouring_async.

/// Tendo isto em mente, o método `reap_left_completions` possibilita a espera forçosa dos pedidos pendentes, algo que deve ser utilizado entre a última submissão e a operação de `close` @didona2022.

=== POSIX

Com o objetivo de flexibilizar o benchmark, todas as implementações de `Engine` possuem uma configuração para manipulação dos parâmetros e respetivo comportamento, neste caso em concreto, ao tratar-se de uma interface bastante simplista, a única configuração possível ocorre na syscall `open` através das flags passadas como argumento @didona2022.

Posto isto, a estrutura de configuração indica o tipo de `Engine` selecionada, bem como uma lista das flags que o utilizador considera relevantes para a execução da workload, por questões de comodidade na implementação, somente as flags mais relevantes são suportadas.

#figure(
  raw_code_block[
    ```yaml
    engine:
      type: posix
      openflags:
        - O_CREAT
        - O_TRUNC
        - O_RDONLY
        - O_DIRECT
    ```
  ],
  caption: [Configuração de `PosixEngine`]
)

#figure(
  image("../images/flow_posix.png", width: 65%),
  caption: [Funcionamento interno da POSIX Engine]
)

Por ostentar comportamento síncrono, o método `reap_left_completions` não tem relevância prática, destarte a receção de pedidos é seguida da syscall associada ao tipo de operação, sendo mais tarde devolvido o código de erro, bem como a estrutura do pedido @didona2022.

=== AIO

Relativamente à interface libaio, a configuração é relativamente simples, sendo o parâmetro `entries` responsável por definir a profundidade máxima da fila de pedidos in-flight, o que corresponde ao número de buffers alinhados pré-alocados durante a inicialização do contexto através da syscall `io_queue_init` @didona2022.

A estratégia de submissão da `AioEngine` baseia-se na acumulação de pedidos num batch até que a capacidade máxima seja atingida, sendo nesse momento submetidos atomicamente através de `io_submit` @didona2022. As conclusões são recolhidas de forma bloqueante por `io_getevents`, que espera pela disponibilidade de pelo menos um resultado antes de retornar, processando até `entries` completions em simultâneo.

#figure(
  raw_code_block[
    ```yaml
    engine:
      type: aio
      entries: 128
      openflags:
        - O_CREAT
        - O_RDWR
        - O_DIRECT
    ```
  ],
  caption: [Configuração de `AioEngine`]
)

Para cada pedido in-flight, é mantido um buffer independente alinhado ao tamanho do bloco, garantindo compatibilidade com `O_DIRECT` e evitando cópias adicionais durante a submissão @didona2022. Um pool de índices disponíveis controla a reutilização segura dos buffers, sendo que quando não existem posições livres, a engine força a recolha de completions antes de aceitar novos pedidos, prevenindo assim a saturação do contexto.

=== io_uring

Ao fazer uso do sistema de ficheiros, os argumentos de abertura são semelhantes aos previamente referidos, portanto a configuração da `UringEngine` apresenta uma lista das mesmas flags @uring_kernel.

Em relação aos demais parâmetros, `entries` e `cq_entries` definem a profundidade da @sq e @cq respetivamente, por norma estes valores são potências de dois entre 64 e 256, isto porque valores pequenos diminuem o paralelismo, enquanto o contrário resulta num aumento do consumo de memória e desperdício da localidade da cache @didona2022.

Relativamente às flags para controlo do anel e processamento de @io, o utilizador usufruir de total liberdade de escolha, sendo de realçar a flag `IORING_SETUP_SQPOLL` que cria uma thread no kernel para pollar a @sq e assim os pedidos serem submetidos sem a necessidade de invocar a syscall `io_uring_enter`. Por outro lado, a flag `IORING_SETUP_SQ_AFF` estabelece a afinidade da thread do kernel, neste caso em particular, a mesma será fixada no core 0 e após de 100 milissegundos de inatividade entrará no estado de sleep @rust_iouring_async.

#figure(
  raw_code_block[
  ```yaml
    engine:
      type: uring
      openflags:
        - O_CREAT
        - O_RDWR
      entries: 128
      params:
        cq_entries: 128
        sq_thread_cpu: 0
        sq_thread_idle: 100
        flags:
          - IORING_SETUP_SQPOLL
          - IORING_SETUP_IOPOLL
          - IORING_SETUP_SQ_AFF
    ```
  ],
  caption: [Configuração de `UringEngine`]
)

#figure(
  image("../images/flow_uring.png", width: 75%),
  caption: [Funcionamento interno da io_uring Engine]
)

Tratando-se de uma interface assíncrona, o seu bom uso passa por diminuir a invocação de syscalls e manter os pedidos in-flight no máximo permitido, o que corresponde à capacidade da @sq @uring_kernel. Tendo isto em consideração, a `UringEngine` não executa os pedidos mal estes sejam recebidos, procura sim formar um batch para submeter vários em simultâneo @rust_iouring_async.

Depois do primeiro batch ser submetido, a estratégia é alterada para preservar a quantidade de pedidos in-flight, portanto mal seja encontrada uma @sqe dísponivel, a mesma é preparada e submetida independentemente de haver ou não um batch. É certo que esta abordagem aumenta as syscalls, porém quando combinada com a thread de polling do kernel, permite atingir débitos e @iops deveras elevados @uring_kernel.

=== SPDK

Uma vez que o @spdk possui um ficheiro de configuração próprio, utilizado para definir os @bdev, controladores de disco, tamanho dos blocos e afins, os parâmetros manipuláveis pelo benchmark a nível aplicacional são limitados @spdk_docs.

Posto isto, `spdk_threads` indica o número de threads lógicas que serão criadas e pelas quais os pedidos de @io serão distribuídos em round-robin, importa realçar que tais threads funcionam como uma abstração sobre o reactor, o qual é responsável por escalonar as tarefas e direcioná-las para que sejam executadas nos cores corretos @didona2022.

Desta feita, o número de cores realmente utilizados pelo runtime do @spdk é identificado por `reactor_mask`, neste caso em particular, `0XF` convertido para binário equivale a `1111`, assim os quatro primeiros cores do sistema estão disponíveis para escalonamento de tarefas @spdk_docs.

Embora as threads lógicas possam ser fixadas em qualquer core, o componente `SPDKRuntime` está fixado no primeiro core e em espera ativa por pedidos de @io vindos da aplicação, portanto qualquer outra thread fixada no mesmo core nunca será capaz de executar, afinal o runtime é interminável no consumo de recursos @didona2022.

#figure(
  raw_code_block[
    ```yaml
    engine:
      type: spdk
      spdk_threads: 1
      bdev_name: Malloc0
      reactor_mask: "0xF"
      json_config_file: spdk_bdev.json
    ```
  ],
  caption: [Configuração de `SPDKEngine`]
)

#figure(
  image("../images/flow_spdk.png", width: 85%),
  caption: [Funcionamento interno da SPDK Engine]
)

Ao iniciar o runtime do @spdk, o ambiente de execução muda completamente e torna-se difícil comunicar com os restante componentes do nível aplicacional, deste modo `SPDKEngine` serve essencialmente para transmitir os pedidos de @io através de um trigger partilhado pelo runtime @spdk_docs.

No momento em que este recebe um pedido, é necessário aguardar por uma zona de memória disponível, isto porque um buffer foi inicialmente alocado para propósitos de @dma. De seguida, o pedido é encapsulado numa mensagem própria do @spdk e transmitido a uma thread lógica, sendo esta responsável por submeter ao @bdev e executar a operação de callback quando o pedido estiver concluído @didona2022.

Por fim, como os pedidos vão acompanhados de um trigger, a `SPDKEngine` é notificada acerca da conclusão e portanto percebe que é seguro devolver a struct ao produtor @spdk_docs.

== Métricas e Relatório

Durante a execução de workloads, o benchmark é responsável por recolher métricas sobre cada uma das operações de @io realizadas, algo fundamental na caracterização e posterior avaliação do sistema de armazenamento, isto porque scripts estatísticos podem analisar o ficheiro de log resultante das métricas @didona2022 @ren2023.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```c
      struct BaseMetric : Metric {
        uint64_t sts;
        uint64_t ets;
        uint64_t block_id;
        uint32_t compression;
        OperationType op;
      };
      ```
    ],
    raw_code_block[
      ```c
      struct StandardMetric : BaseMetric {
        pid_t pid;
        uint64_t tid;
      };
      ```
    ],
    raw_code_block[
      ```c
      struct FullMetric : StandardMetric {
        uint64_t offset;
        size_t req_bytes;
        size_t proc_bytes;
        int32_t error_no;
        int32_t return_code;
      };
      ```
    ],
  ),
  caption: [Estrutura dos pacotes de métricas]
)

Tendo isto em consideração, o utilizador escolhe entre três pacotes de métricas que são progressivamente mais completos e suportam todos os parâmetros do pacote anterior. Assim sendo, `BaseMetric` corresponde à estrutura mais simples, contendo apenas os timestamp de início e fim, bem como o identificador do bloco utilizado e respetiva taxa de compressão, importa realçar que somente as operações de `WRITE` levam à geração de blocos, como tal qualquer outra operação apresenta um `block_id` igual a zero @didona2022.

#figure(
  raw_code_block[
  ```
  [prismo] [info] [type=1 block=1 cpr=0 sts=3480446313169 ets=3480446319309]
  [prismo] [info] [type=1 block=2 cpr=100 sts=3480446320554 ets=3480446323543]
  [prismo] [info] [type=1 block=3 cpr=100 sts=3480446324413 ets=3480446326723]
  [prismo] [info] [type=1 block=4 cpr=0 sts=3480446327460 ets=3480446329981]
  [prismo] [info] [type=1 block=5 cpr=100 sts=3480446330781 ets=3480446332925]
  [prismo] [info] [type=1 block=6 cpr=50 sts=3480446333681 ets=3480446336316]
  ```
  ],
  caption: [Estrutura do ficherio de log]
)

A estrutura do ficheiro de logging onde as métricas são armazenadas é de simples interpretação, neste caso em particular o pacote de métricas selecionado foi o `BasicMetric`, portanto os parâmetros presentes são idênticos aos da struct @didona2022.

Por fim, quanto mais detalhadas forem as métricas recolhidas, pior será o desempenho do benchmark, daí que exista uma opção de desativação de métricas para atingir o máximo de performance @ren2023. Ademais, como as métricas são escritas num ficheiro de logging, o sistema de armazenamento é sobrecarregado para além da execução do benchmark, algo que pode originar o enviesamento de resultados @didona2022.

=== Estatísticas e Relatório Final

Além do registo individual de métricas por operação, o benchmark agrega as observações recolhidas durante a execução e produz um relatório final com indicadores estatísticos para cada tipo de operação @ren2023 @didona2022.

As latências são registadas num histograma HDR @hdrhistogram capaz de calcular percentis com elevada precisão e baixo consumo de memória, disponibilizando os valores p50, p90, p95, p99, p99.9 e p99.99, métricas particularmente relevantes na caracterização da cauda da distribuição de latências @ren2023.

Adicionalmente, três séries temporais são mantidas com granularidade ao segundo: número de operações, largura de banda e latência média, sendo estas obtidas por agregadores que acumulam os valores por janela temporal @didona2022.

#figure(
  raw_code_block[
    ```json
    {
      "total_operations": 1000000,
      "runtime_sec": 123.45,
      "overall_iops": 8102.37,
      "overall_bandwidth_bytes_per_sec": 33187308,
      "overall_percentiles_ns": {
        "p50": 10000, "p90": 25000,
        "p95": 35000, "p99": 65000,
        "p99_9": 120000, "p99_99": 850000
      },
      "operations": [
        { "operation": "read", "count": 500000, ... },
        { "operation": "write", "count": 500000, ... }
      ]
    }
    ```
  ],
  caption: [Estrutura simplificada do relatório final]
)

Quando múltiplos jobs são executados em paralelo, o relatório contém os resultados individuais de cada job e um registo adicional resultante da fusão de todas as estatísticas, onde os histogramas de latência são combinados e os timestamps de início e fim são ajustados para refletir o intervalo global de execução @ren2023.

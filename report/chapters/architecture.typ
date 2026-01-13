#import "@preview/timeliney:0.4.0"
#import "@preview/wrap-it:0.1.1": wrap-content
#import "../utils/functions.typ" : raw_code_block

== Abordagem e Planeamento <chapter3>

Depois de esclarecido o problema da avaliação realista dos sistemas de armazenamento e compreendidos os conceitos em seu redor, este capítulo visa abordar a arquitetura do protótipo de benchmark, passando pela identificação dos respetivos componentes, estratégias adotadas para geração de conteúdo e integração com #link(<api>)[*APIs*] de #link(<io>)[*I/O*] cuja natureza é bastante diversa, isto fundamentalmente porque algumas são síncronas e outras assíncronas.

De seguida, serão apresentados resultados preliminares da performance do benchmark, procurando explicar as diferenças obtidas conforme as configurações e ambiente de teste, sendo isto fundamental para perceber se o overhead associado à geração de conteúdo impossibilita a saturação do sistema de armazenamento.

Por fim, e uma vez que somente o protótipo foi implementado, serão estabelecidas as próximas etapas do desenvolvimento do benchmark, algo que inevitavelmente passará pela integração com traces e extensão dos mesmos, no então outras configurações relativamente simples como speed up ou slow down seriam interessantes e contribuiriam para uma maior flexibilidade em termos de configuração.

=== Arquitetura

Numa primeira abordagem ao problema, percebemos que a geração de conteúdo é facilmente dissociável das operações solicitadas ao sistema de armazenamento, sendo estas realizadas por meio das #link(<api>)[*APIs*] de #link(<io>)[*I/O*]. Deste modo, a arquitetura pode ser dividida em dois grandes componentes que estabelecem cada um interfaces para manipulação da conduta.

Posto isto, a interface para geração de conteúdo abstrai as implementações concretas, daí que a sua utilização não implique desvios de padrão caso o utilizador escolha usufruir de dados sintéticos ou reais obtidos através de traces, do mesmo modo esta lógica é aplicável para a interface de abstração do disco.

Com o estabelecimento destes componentes, um produtor é responsável para invocar os métodos da interface de geração de conteúdo e encapsular os resultados num pedido de #link(<io>)[*I/O*], sendo este colocado numa blocking queue como forma de solicitação de execução.

Do outro lado, um consumidor está constantemente à escuta na queue com o objetivo de receber pedidos, mal isto ocorra, é realizada uma submissão na interface de #link(<io>)[*I/O*], sendo mais tarde a estrutura do pedido libertada e transmitida ao produtor para nova utilização.

==== Geração de Conteúdo Sintético

Na generalidade das interfaces, os pedidos de #link(<io>)[*I/O*] são caracterizados pelo tipo de operação, conteúdo e posição do disco onde o pedido será satisfeito, consequentemente o gerador de conteúdo sintético pode ser desacoplado nestas três funcionalidades, dando origem a interfaces que visam fornecer os parâmetros dos pedidos.

Como fruto desta abordagem, e uma vez que os geradores são definidos ao nível dos parâmetros, a combinação entre geradores sintéticos e reais torna-se bastante simples, isto porque o produtor apenas conhece uma interface que é independente da implementação concreta, assim podemos ter acessos reais e operações sintéticas, sendo o contrário igualmente válido.

#figure(
  image("../images/producer.png", width: 60%),
  caption: [Interação do produtor com a interface de geração de conteúdo]
)

Enquanto medida para reutilização de memória, produtor e consumidor partilham duas queues, uma direcionada ao envio de pedidos (produtor para consumidor) e outra responsável por identificar as structs cujo pedido já foi concluído (consumidor para produtor), e como tal podem ser reutilizadas pelo produtor.

Ao recolher uma struct, através da operação de dequeue, o produtor invoca os métodos disponibilizados por cada uma das interfaces, de relembrar que o conteúdo do bloco apenas é gerado quando a operação solicitada for um `WRITE`. De seguida, e tendo os parâmetros devidamente identificados, o mesmos são encapsulados num pedido que é inserido na queue para futura execução por parte do consumidor.

Uma vez que as queues apresentam capacidade limitada, e tendo em consideração que à partida o produtor será mais performante que o consumidor, isto permite alcançar buffering e backpressure em simultâneo, pois quando a capacidade limite for atingida, o produtor irá bloquear e portanto o consumidor jamais será sobrecarregado com uma quantidade infindável de pedidos, o que contribui para um uso eficiente da memória disponível.

===== Acesso

Os pedidos de `READ` e `WRITE` necessitam de ser identificados pela zona do disco onde a operação irá ocorrer, neste sentido a interface `AccessGenerator` disponibiliza o método `nextAccess` que devolve o offset da próxima operação a realizar, sendo de realçar que nem todas as implementações concretas apresentam a mesma performance, pois algumas seguem distribuições enquanto outras utilizam aritmética simples.

#figure(
  image("../images/access.png", width: 60%),
  caption: [Hierarquia da interface de acessos]
)

Dado que os acessos são realizados ao nível do bloco, todas as implementações devem conhecer o tamanho do bloco e o limite da zona do disco até onde é permitido ler ou escrever, deste modo os offsets devolvidos serão inferiores ou iguais ao limite e acima de tudo múltiplos do tamanho do bloco.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```yaml
      type: sequential
      blocksize: 4096
      limit: 65536
      ```
    ],
    raw_code_block[
      ```yaml
      type: random
      blocksize: 4096
      limit: 65536
      ```
    ],
    raw_code_block[
      ```yaml
      type: zipfian
      blocksize: 4096
      limit: 65536
      skew: 0.99
      ```
    ],
  ),
  caption: [Configuração dos geradores de acesso]
)

A implementação do tipo sequencial é responsável por devolver os offsets num padrão contínuo, sendo que o alcance do limite implica o reposicionamento no offset zero, esta estratégia beneficia claramente a localidade espacial, pois as zonas do disco são acedidas num padrão favorável.

Por outro lado, os acessos totalmente aleatórios não favorecem quaisquer propriedades de localidade, daí que sejam especialmente úteis para evitar uma utilização eficiente da cache. Por fim, os acessos zipfian seguem uma distribuição cuja skew pode ser manipulada pelo utilizador, neste sentido cargas de trabalho com hotspots são facilmente replicáveis por esta implementação.

===== Operação

Os sistemas de armazenamento suportam uma infinidade de operações, no entanto o gerador de operações apenas disponibiliza `READ`, `WRITE`, `FSYNC`, `FDATASYNC` e `NOP` por serem as mais comuns e portanto adotadas pela maioria das #link(<api>)[*APIs*] de #link(<io>)[*I/O*]. Embora a operação `NOP` não faça rigorosamente nada, a mesma é útil para testar a performance do benchmark independente da capacidade do disco, permitindo identificar o débito máximo que o sistema de armazenamento pode almejar.

#figure(
  image("../images/operation.png", width: 60%),
  caption: [Hierarquia da interface de operações]
)

A implementação do tipo constante é a mais simples, isto porque devolve sempre a mesma operação que foi definida previamente pelo utilizador. Em contrapartida, as operações percentuais são obtidas à custa de uma distribuição cujo somatório das probabilidade deve resultar em 100, exemplificando com a configuração abaixo, metade das operações serão `READs` e as restantes `WRITES`.

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

Por fim, a replicação de padrões é obtida com recurso à implementação de sequência, sendo o utilizador responsável por definir uma lista de operações que mais tarde será repetidamente devolvida, neste caso em concreto, se o método `nextOperation` fosse invocado cinco vezes, as operações seriam devolvidas pela ordem: `WRITE`, `FSYNC`, `WRITE`, `FSYNC`, `WRITE`.

===== Geração de Blocos

A geração de blocos é sem dúvida a operação mais custosa, no entanto apenas torna-se necessária quando a operação selecionada for um `WRITE`, nesse sentido a interface de `BlockGenerator` disponibiliza o método `nextBlock` que preenche um buffer passado como argumento.

Embora a implementação principal desta interface seja aquela que combina duplicados e compressão, existem outras mais rudimentares que servem para testar cenários específicos com maior eficiência, isto porque o gerador de duplicados é capaz de simular os blocos dos outros geradores, mas com uma performance significativamente menor.

#figure(
  image("../images/block.png", width: 60%),
  caption: [Hierarquia da interface de geração de blocos]
)

Tal como seria expectável, os geradores necessitam de conhecer o tamanho do bloco, deste modo podem garantir que os limites dos buffers jamais serão violados. A implementação mais simplista deste gerador corresponde ao constante, que devolve sempre o mesmo buffer, resultando numa deduplicação e compressibilidade interbloco máximas. Por outro lado, o aleatório tem exatamente o comportamento oposto, pois ao devolver buffers diferentes não existem duplicados e a entropia é elevada.

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

Por fim, o gerador de duplicados e compressão procura seguir uma distribuição de duplicados definida pelo utilizador, esta estabelece a percentagem de blocos que terão X cópias, sendo que cada grupo de cópias tem associada uma distribuição de compressão, indicando que Y% dos blocos reduz cerca de Z%.

Além disso, a opção `refill_buffers` permite a partilha do buffer base entre blocos, deste modo quando os mesmos são criados a zona de entropia máxima é obtida a partir do buffer, consequentemente todos os blocos partilham a mesma informação e portanto a compressibilidade interbloco atinge o limite.

====== Geração de Duplicados e Compressão

Para que o utilizador manipule a distribuição de duplicados e compressão, o benchmark oferece um ficheiro de configuração sobre o qual as informações são retiradas, bastando seguir o formato indicado.

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

A distribuição de duplicados e compressão é definida de modo particular, inicialmente é realizada uma associação entre o número de cópias e a respetiva probabilidade, sendo mais tarde definidas as taxas de compressão dentro de cada grupo.

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

A @compression-map representa a estrutura sobre a qual as taxas de compressão são armazenadas para cada grupo, sendo basicamente um mapa que associa o número de repetições a uma lista formada por tuplos de percentagem cumulativa e respetiva redução.

Por outro lado, a @dedup-map é responsável por gerir os blocos duplicados e tem um funcionamento semelhante ao de uma sliding window, onde os tuplos da lista são constituídos pelo identificador de bloco e cópias que faltam efetuar.

O funcionamento do algoritmo é bastante simples, inicialmente uma entrada do mapa é selecionada conforme as probabilidades do ficheiro de configuração, a partir daí, caso a lista não tenha atingido o limite de elementos, um novo é adicionado com o número de cópias igual ao de repetições.

Na situação em que a lista encontra-se completa, um dos elementos é selecionado aleatoriamente e o valor das cópias em falta é decrementado uma unidade, ao ser atingido o valor zero a entrada é definitivamente retirada da lista, pois o bloco já foi repetido as vezes necessárias.

Por fim, depois de selecionado o identificador do bloco, volta a ser sorteado um número aleatório para descobrir a taxa de compressão a aplicar, de relembrar que a distribuição é obtida pela entrada do mapa selecionada inicialmente.

Apesar de bastante eficiente, esta abordagem acarreta o problema da geração pseudo aleatória, algo que tende a ser bastante custoso relativamente às restantes operações, no entanto esta implementação faz uso de um buffer gerido pelo SHISHUA, deste modo gerações massivas são realizadas periodicamente enquanto a aplicação limita-se a recolher dados do buffer.

==== Integração de Interfaces de I/O

Sabendo que o consumidor está à escuta de pedidos enviados pelo produtor, quando os mesmos são recebidos procede-se de imediato ao desencapsulamento para compreender o tipo de operação em questão e assim facilitar o acesso aos restantes parâmetros, como offset e conteúdo.

A interface `Engine` disponibiliza o método `submit` que aceita operações de qualquer tipo, assim o consumidor não é responsável por definir as alterações de comportamento associadas. Mal o pedido seja dado por concluído, a struct é devolvida pela interface, permitindo ao consumidor fazer dequeue para que a zona de memória seja reutilizada mais tarde.

#figure(
  image("../images/consumer.png", width: 60%),
  caption: [Interação do consumidor com a interface de engine]
)

Um pedido obtido a partir da queue pode ser de três tipos distintos, onde as structs de abertura e fecho são caracterizadas pelos argumentos encontrados nas syscalls de `open` e `close`, importa realçar que tais estruturas não fazem sentido para a engine de #link(<spdk>)[*SPDK*], visto esta funcionar diretamente sobre o dispositivo de armazenamento e portanto não existir uma abstração do sistema de ficheiros.

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

Perante a combinação de interfaces síncronas e assíncronas, o método `submit` nem sempre devolve uma struct para reutilização, pois, no caso das interfaces assíncronas nunca sabemos exatamente quando o pedido será dado por concluído e além disso não é possível esperar até que tal aconteça, caso contrário estaria a ser dado comportamento síncrono e as vantagens de paralelismo seriam perdidas.

/// Tendo isto em mente, o método `reap_left_completions` possibilita a espera forçosa dos  pedidos pendentes, algo que deve ser utilizado entre a última submissão e a operação de `close`.

===== POSIX

#let posix_config = figure(
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

#let posix_body = [
  Com o objetivo de flexibilizar o benchmark, todas as implementações de `Engine` possuem uma configuração para manipulação dos parâmetros e respetivo comportamento, neste caso em concreto, ao tratar-se de uma interface bastante simplista, a única configuração possível ocorre na syscall `open` através das flags passadas como argumento.

  Posto isto, a estrutura de configuração indica o tipo de `Engine` selecionada, bem como uma lista das flags que o utilizador considera relevantes para a execução da workload, por questões de comodidade na implementação, somente as flags mais relevantes são suportadas.
]

#wrap-content(
  posix_config,
  posix_body,
  align: top + right,
  columns: (2fr, 1.4fr),
)

#figure(
 image("../images/flow_posix.png", width: 65%),
 caption: [Funcionamento interno da POSIX Engine]
)

Por ostentar comportamento síncrono, o método `reap_left_completions` não tem relevância prática, destarte a receção de pedidos é seguida da syscall associada ao tipo de operação, sendo mais tarde devolvido o código de erro, bem como a estrutura do pedido.

===== Uring

#let uring_config = figure(
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

#let uring_body = [
  Ao fazer uso do sistema de ficheiros, os argumentos de abertura são semelhantes aos previamente referidos, portanto a configuração da `UringEngine` apresenta uma lista das mesmas flags.

  Em relação aos demais parâmetros, `entries` e `cq_entries` definem a profundidade da #link(<sq>)[*SQ*] e #link(<cq>)[*CQ*] respetivamente, por norma estes valores são potências de dois entre 64 e 256, isto porque valores pequenos diminuem o paralelismo, enquanto o contrário resulta num aumento do consumo de memória e desperdício da localidade da cache.

  Relativamente às flags para controlo do anel e processamento de #link(<io>)[*I/O*], o utilizador usufruir de total liberdade de escolha, sendo de realçar a flag `IORING_SETUP_SQPOLL` que cria uma thread no kernel para pollar a #link(<sq>)[*SQ*] e assim os pedidos serem submetidos sem a necessidade de invocar a syscall `io_uring_enter`. Por outro lado, a flag `IORING_SETUP_SQ_AFF` estabelece a afinidade da thread do kernel, neste caso em particular, a mesma será fixada no core 0 e após de 100 milissegundos de inatividade entrará no estado de sleep.
]

#wrap-content(
  uring_config,
  uring_body,
  align: top + right,
  columns: (2fr, 1.4fr),
)

#figure(
    image("../images/flow_uring.png", width: 75%),
    caption: [Funcionamento interno da Uring Engine]
)

Tratando-se de uma interface assíncrona, o seu bom uso passa por diminuir a invocação de syscalls e manter os pedidos in-flight no máximo permitido, o que corresponde à capacidade da #link(<sq>)[*SQ*]. Tendo isto em consideração, a `UringEngine` não executa os pedidos mal estes sejam recebidos, procura sim formar um batch para submeter vários em simultâneo.

Depois do primeiro batch ser submetido, a estratégia é alterada para preservar a quantidade de pedidos in-flight, portanto mal seja encontrada uma #link(<sqe>)[*SQE*] dísponivel, a mesma é preparada e submetida independentemente de haver ou não um batch. É certo que esta abordagem aumenta as syscalls, porém quando combinada com a thread de polling do kernel, permite atingir débitos e #link(<iops>)[*IOPS*] deveras elevados.

===== SPDK

#let spdk_config = figure(
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

#let spdk_body = [
  Uma vez que o #link(<spdk>)[*SPDK*] possui um ficheiro de configuração próprio, utilizado para definir os #link(<bdev>)[*bdevs*], controladores de disco, tamanho dos blocos e afins, os parâmetros manipuláveis pelo benchmark a nível aplicacional são limitados.

  Posto isto, `spdk_threads` indica o número de threads lógicas que serão criadas e pelas quais os pedidos de #link(<io>)[*I/O*] serão distribuídos em round-robin, importa realçar que tais threads funcionam como uma abstração sobre o reactor, o qual é responsável por escalonar as tarefas e direcioná-las para que sejam executadas nos cores corretos.

  Desta feita, o número de cores realmente utilizados pelo runtime do #link(<spdk>)[*SPDK*] é identificado por `reactor_mask`, neste caso em particular, `0XF` convertido para binário equivale a `1111`, assim os quatro primeiros cores do sistema estão disponíveis para escalonamento de tarefas.

  Embora as threads lógicas possam ser fixadas em qualquer core, o componente `SPDKRuntime` está fixado no primeiro core e em espera ativa por pedidos de #link(<io>)[*I/O*] vindos da aplicação, portanto qualquer outra thread fixada no mesmo core nunca será capaz de executar, afinal o runtime é interminável no consumo de recursos.
]

#wrap-content(
  spdk_config,
  spdk_body,
  align: top + right,
  columns: (2fr, 1.6fr),
)

#figure(
  image("../images/flow_spdk.png", width: 85%),
  caption: [Funcionamento interno da SPDK Engine]
)

Ao iniciar o runtime do #link(<spdk>)[*SPDK*], o ambiente de execução muda completamente e torna-se difícil comunicar com os restante componentes do nível aplicacional, deste modo `SPDKEngine` serve essencialmente para transmitir os pedidos de #link(<io>)[*I/O*] através de um trigger partilhado pelo runtime.

No momento em que este recebe um pedido, é necessário aguardar por uma zona de memória disponível, isto porque um buffer foi inicialmente alocado para propósitos de #link(<dma>)[*DMA*]. De seguida, o pedido é encapsulado numa mensagem própria do #link(<spdk>)[*SPDK*] e transmitido a uma thread lógica, sendo esta responsável por submeter ao #link(<bdev>)[*bdev*] e executar a operação de callback quando o pedido estiver concluído.

Por fim, como os pedidos vão acompanhados de um trigger, a `SPDKEngine` é notificada acerca da conclusão e portanto percebe que é seguro devolver a struct ao produtor.

==== Recolha de Métricas

Durante a execução de workloads, o benchmark é responsável por recolher métricas sobre cada uma das operações de #link(<io>)[*I/O*] realizadas, algo fundamental na caracterização e posterior avaliação do sistema de armazenamento, isto porque scripts estatísticos podem analisar o ficheiro de log resultante das métricas.

#figure(
  grid(
    columns: 3,
    gutter: 5pt,
    raw_code_block[
      ```c
      struct BaseMetric : Metric {
        int64_t sts;
        int64_t ets;
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

Tendo isto em consideração, o utilizador escolhe entre três pacotes de métricas que são progressivamente mais completos e suportam todos os parâmetros do pacote anterior. Assim sendo, `BaseMetric` corresponde à estrutura mais simples, contendo apenas os timestamp de início e fim, bem como o identificador do bloco utilizado e respetiva taxa de compressão, importa realçar que somente as operações de `WRITE` levam à geração de blocos, como tal qualquer outra operação apresenta um `block_id` igual a zero.

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

A estrutura do ficheiro de logging onde as métricas são armazenadas é de simples interpretação, neste caso em particular o pacote de métricas selecionado foi o `BasicMetric`, portanto os parâmetros presentes são idênticos aos da struct.

Por fim, quanto mais detalhadas forem as métricas recolhidas, pior será o desempenho do benchmark, daí que exista uma opção de desativação de métricas para atingir o máximo de performance. Ademais, como as métricas são escritas num ficheiro de logging, o sistema de armazenamento é sobrecarregado para além da execução do benchmark, algo que pode originar o enviesamento de resultados.

=== Resultados Preliminares

Com o objetivo de testar o protótipo, em particular o desempenho das várias interface de #link(<io>)[*I/O*], foram desenvolvidas workloads de características distintas, projetadas para avaliar o sistema de armazenamento sob diferentes padrões de acesso, leituras e escritas intensivas, bem como cenários de alta concorrência.

+ *nop:* não são realizadas quaisquer operações ao nível do sistema de armazenamento, sendo por isso ideal na identificação do débito máximo por parte da interface de #link(<io>)[*I/O*], consequentemente o grosso do tempo de execução é gasto em espaço de utilizador.

+ *wseq:* as escritas são realizadas do modo sequencial, seguindo o tamanho dos blocos. Ademais o conteúdo gerado é constante, como tal é frequentemente repetido o mesmo bloco e a taxa de compressão é máxima.

+ *rwmix:* as operações são divididas igualmente entre `READs` e `WRITEs`, sem a evidência de padrões, pois a seleção é aleatória. De igual modo, os blocos e acessos são obtidos através de uma distribuição uniforme, como tal não existem duplicados e nenhuma zona do disco é particularmente popular, o que inviabiliza uma utilização eficiente da cache.

+ *zipf:* os acessos são obtidos por uma distribuição zipfian com skew de 0.9, o que aumenta a frequência dos offsets mais baixos. De resto, os blocos seguem uma determinada distribuição de duplicados e compressão, onde as operações são realizadas sob o padrão `READ`, `WRITE`, `NOP`, `WRITE`.

+ *zipf_fsync*: esta workload é essencialmente igual à zipf, contudo difere pelo facto de possuir uma barreira onde a cada 1024 escritas é lançado um `FSYNC` para sincronização dos conteúdos no disco.

Sabendo que a memória principal e mecanismos de cache do sistema operativo influenciam a execução do benchmark, os offsets das workloads vão até ao limite de quatro vezes a capacidade da #link(<ram>)[*RAM*]. No entanto, por motivos de conveniência, o máximo de operações realizadas corresponde a dez milhões e a flag `O_DIRECT` foi desativada para fazer uso da page cache e assim diminuir o tempo de execução.

Tendo isto em consideração, as workloads foram replicadas num ambiente controlado para garantir a reprodutibilidade dos resultados e a comparabilidade entre os vários testes, tendo sido utilizada a seguinte especificação de hardware e software:

- *OS:* Ubuntu 22.04.5 LTS (Jammy Jellyfish) x86_64
- *CPU:* 12th Gen Intel(R) Core(TM) i5-12500 (12) @ 4.60 GHz
- *RAM:* 64 GiB DDR4 @ 3200 MT/s, 2 x 32 GiB modules
- *Disco:* NVMe Sandisk Corp 256 GB, non-rotational

Por fim, a configuração dos backends de #link(<io>)[*I/O*] é constante entre a replicação das workloads, sendo de destacar a interface Uring com uma #link(<sq>)[*SQE*] de profundidade 128 e ativação da flag `IORING_SETUP_SQPOLL` para criar uma thread do kernel dedicada a fazer polling na #link(<sq>)[*SQE*] e assim evitar o custo das syscalls. Por outro lado, a interface #link(<spdk>)[*SPDK*] inicializa um reactor nos quatro primeiros cores e cinco threads lógicas para servir os pedidos de #link(<io>)[*I/O*], sendo estes satisfeitos por um #link(<bdev>)[*bdev*] associado a um controlador de #link(<nvme>)[*NVMe*].

#let performance-table(workload_name, ..content) = figure(
  table(
    columns: (1fr, 1.6fr, 1fr, 1fr, 1fr, 1.2fr, 1.2fr),
    inset: 6pt,
    align: horizon + left,
    fill: (x, y) => if y == 0 or x == 0 { gray.lighten(60%) },
    table.header(
      [*Engine*], [*Mean $plus.minus$ $sigma$ (s)*], [*Min (s)*],
      [*Max (s)*], [*User (s)*], [*System (s)*], [*IOPS (k/s)*]
    ),
    ..content
  ),
  // kind: "performance",
  // supplement: "Performance",
  caption: [Execução da workload #workload_name]
)

#performance-table("nop",
  [*POSIX*], [0.567 $plus.minus$ 0.192], [0.392], [0.801], [1.107], [0.010], [17636],
  [*Libaio*], [2.458 $plus.minus$ 0.093], [2.089], [2.515], [2.858], [1.853], [4068],
  [*Uring*], [1.073 $plus.minus$ 0.097], [0.925], [1.257], [1.411], [1.069], [9319],
  [*SPDK*], [9.472 $plus.minus$ 0.045], [9.420], [9.503], [55.362], [0.153], [1055],
)

#performance-table("wsqe",
  [*POSIX*], [20.991 $plus.minus$ 2.387], [19.527], [23.745], [24.323], [9.889], [476],
  [*Libaio*], [22.661 $plus.minus$ 3.445], [18.688], [25.142], [27.294], [9.587], [441],
  [*Uring*], [23.829 $plus.minus$ 2.768], [20.695], [25.941], [47.970], [84.578], [419],
  [*SPDK*], [19.910 $plus.minus$ 0.084], [19.817], [19.981], [116.922], [0.311], [502],
)

#performance-table("rwmix",
  [*POSIX*], [95.796 $plus.minus$ 11.202], [82.862], [102.407], [97.451], [12.140], [104],
  [*Libaio*], [79.481 $plus.minus$ 28.754], [49.505], [106.832], [81.150], [12.664], [125],
  [*Uring*], [53.931 $plus.minus$ 27.617], [27.578], [82.659], [108.344], [75.874], [185],
  [*SPDK*], [19.800 $plus.minus$ 0.093], [19.706], [19.891], [116.341], [0.291], [505]
)

#performance-table("zipf",
  [*POSIX*], [36.625 $plus.minus$ 3.801], [32.361], [39.655], [36.625], [12.039], [273],
  [*Libaio*], [36.608 $plus.minus$ 1.372], [35.111], [37.805], [36.975], [11.971], [273],
  [*Uring*], [27.835 $plus.minus$ 0.758], [26.974], [28.404], [49.214], [52.578], [359],
  [*SPDK*], [21.733 $plus.minus$ 0.151], [21.636], [21.907], [116.751], [4.987], [460],
)

#performance-table("zipf_fsync",
  [*POSIX*], [107.84 $plus.minus$ 39.384], [66.800], [145.327], [149.822], [31.932], [92],
  [*Libaio*], [161.73 $plus.minus$ 33.294], [132.694], [198.074], [195.341], [27.219], [61],
  [*Uring*], [159.28 $plus.minus$ 2.240], [156.999], [161.477], [314.117], [191.201], [62],
  [*SPDK*], [21.803 $plus.minus$ 0.181], [21.672], [22.009], [117.774], [4.910], [458],
)

// análise dos resultados

=== Próximas Etapas

Embora o protótipo possua imensas funcionalidades, tendo inclusive finalizado alguns componentes, dos quais se destacam as implementações de backends de #link(<io>)[*I/O*] e geração de conteúdo sintético, ainda restam pontos diferenciadores relativamente aos demais benchmarks.

#figure(
  timeliney.timeline(
    show-grid: true,
    {
      import timeliney: *

      headerline(group(([*2026*], 6)))
      headerline(
        group(
          [*Feb*],
          [*Mar*],
          [*Apr*],
          [*May*],
          [*Jun*],
          [*Jul*],
        ),
      )

      taskgroup(
        title: [*Research*],
        style: (stroke: 5pt + black), {
          task("Realistic content generation", (0, 1), style: (stroke: 5pt + gray))
          task("Trace-based and synthetic workloads", (0, 2), style: (stroke: 5pt + gray))
          task("Temporal and spatial locality", (1, 2), style: (stroke: 5pt + gray))
        }
      )

      taskgroup(
        title: [*Development*],
        style: (stroke: 5pt + black), {
          task("FIU trace parser", (2, 3), style: (stroke: 5pt + gray))
          task("Hybrid workload generator", (3, 4), style: (stroke: 5pt + gray))
          task("Thread and process parallelism", (3, 4), style: (stroke: 5pt + gray))
        }
      )

      taskgroup(
        title: [*Evaluation*],
        style: (stroke: 5pt + black), {
          task("Workload validation", (4, 5), style: (stroke: 5pt + gray))
          task("Storage systems evaluation", (4, 6), style: (stroke: 5pt + gray))
          task("Performance metrics analysis", (4, 6), style: (stroke: 5pt + gray))
        }
      )

      taskgroup(
        title: [*Thesis*],
        style: (stroke: 5pt + black), {
          task("Writing of the dissertation", (2, 6), style: (stroke: 5pt + gray))
        }
      )
    }
  ),
  caption: [Calendarização das próximas tarefas]
)

Deste modo, antes de partir para a implementação das workloads híbridas que partilham a geração de conteúdo sintético e realista, é necessário realizar um estudo sobre a melhor forma de atingir isso sem penalizar significativamente a performance do benhcmark ao ponto de não conseguir saturar o disco.

Tendo isso alcançado, resta a avaliação intensiva do benchmark através das múltiplas combinações entre backends, geradores de conteúdo e parâmetros gerais da workload, sendo isto tudo desenvolvido em paralelo com a escrita da dissertação.
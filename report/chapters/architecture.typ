#import "../utils/functions.typ" : raw_code_block
#import "../utils/diagrams.typ" : *

= Prismo <chapter3>

Depois de esclarecido o problema da avaliação realista dos sistemas de armazenamento e compreendidos os conceitos em seu redor, este capítulo apresenta o Prismo, focando-se na sua arquitetura, nos principais componentes e no modo como estes cooperam para executar uma carga de trabalho @didona2022 @ren2023.

== Princípios de Desenho <design-principles>

Antes de descrever a arquitetura, importa enunciar os princípios que a orientam, os quais decorrem diretamente das lacunas identificadas no @chapter2 e determinam as decisões tomadas ao longo do capítulo.

*Independência entre geração e submissão.* A descrição de uma carga não deve depender da interface através da qual os pedidos alcançam o dispositivo, pelo que a construção de cada pedido e a sua submissão são responsabilidades separadas, podendo a mesma carga ser executada sobre qualquer @api de @io @didona2022 @ren2023.

*Conteúdo descrito por distribuições.* As propriedades de deduplicação e compressão não são expressas por uma taxa única aplicada a todos os blocos, mas por distribuições que atribuem a cada grupo de cópias a sua própria repartição de compressibilidade, reproduzindo assim a heterogeneidade observada em ambientes reais @paulo2013 @dedisbenchpp.

*_Traces_ como fonte de qualquer dimensão.* Um _trace_ não é tratado como uma carga indivisível, mas como origem possível para cada parâmetro do pedido tomado isoladamente, o que permite combinar dimensões reais com dimensões sintéticas e tirar partido de registos incompletos @tracegen2024 @gracia-tinedo2015.

*Execução para lá da duração do registo.* Sendo os _traces_ disponíveis demasiado curtos para conduzir um dispositivo moderno a um regime estacionário, a sua reprodução tem de poder prosseguir depois de esgotado o ficheiro, preservando as propriedades estatísticas observadas @pang2026 @ameri2016.

== Visão Geral

A geração de conteúdo é dissociável das operações solicitadas ao sistema de armazenamento, sendo estas realizadas por meio das @api:pl de @io. Deste modo, a arquitetura divide-se em dois grandes blocos, a geração dos parâmetros da carga e a submissão de pedidos ao dispositivo, cada um deles exposto através de uma interface que abstrai as implementações concretas @didona2022 @ren2023.

Tal abstração é o que permite ao utilizador alternar entre dados sintéticos e registos reais obtidos a partir de _traces_ sem alterar o restante da descrição, aplicando-se o mesmo raciocínio à interface que abstrai o acesso ao dispositivo @tracegen2024 @gracia-tinedo2015.

#figure(
  architecture-overview(),
  caption: [Visão geral da arquitetura do Prismo]
) <visao-geral>

Qualquer execução parte da descrição da carga que o utilizador fornece num ficheiro de configuração, onde escolhe o gerador de cada dimensão do pedido, sintético ou baseado num _trace_, e a interface de @io com os respetivos parâmetros. É a partir desta descrição que o Prismo instancia os geradores e o motor antes de a execução começar, conforme a @visao-geral ilustra, ficando o produtor e o consumidor a conhecer apenas as interfaces abstratas que estes implementam.

Instanciados os componentes, a execução de uma carga envolve a sua orquestração segundo o modelo produtor-consumidor que a mesma figura representa @didona2022 @ren2023. O produtor invoca os geradores que definem o padrão de acesso (por exemplo, sequencial ou aleatório), o tipo de operação (incluíndo, leitura ou escrita) e as características do conteúdo (tais como, duplicado ou compressível). Em seguida, encapsula o resultado num pedido de @io e coloca-o numa fila concorrente. O consumidor, por sua vez, retira os pedidos dessa fila e submete-os à interface selecionada.

Concluído o pedido, a estrutura que o transporta é devolvida ao produtor por um segundo canal, permitindo a sua reutilização sem novas alocações. É este ciclo que define o fluxo do _benchmark_, e é em torno dele que se organizam as secções seguintes, começando pelo modelo de execução e terminando nas métricas recolhidas.

== Modelo de Execução <execution-model>

O ciclo representado na @visao-geral assenta num conjunto de mecanismos que determinam durante quanto tempo, com que paralelismo e a que ritmo a carga é executada, desde os canais que ligam o produtor ao consumidor até à rampa de aquecimento, passando pelo critério de terminação e pela replicação do par em vários _jobs_, sendo todos eles independentes do conteúdo dos pedidos e da interface que os submete.

=== Canais de Comunicação

A comunicação entre produtor e consumidor é realizada através de duas filas concorrentes _lock-free_ @moodycamel: a primeira transporta os pedidos preenchidos do produtor para o consumidor, enquanto a segunda devolve as estruturas cujo pedido já foi concluído, possibilitando a sua reutilização sem alocações dinâmicas durante a execução.

Uma vez que as filas apresentam capacidade limitada, e tendo em consideração que à partida o produtor será mais rápido que o consumidor, este mecanismo permite acumular pedidos à espera de execução e travar o produtor em simultâneo, pois quando a capacidade limite for atingida, o produtor irá bloquear e portanto o consumidor jamais será sobrecarregado com uma quantidade infindável de pedidos, o que contribui para um uso eficiente da memória disponível.

O _benchmark_ disponibiliza dois modos de operação para os canais: bloqueante e não-bloqueante. No modo bloqueante, a remoção de um elemento suspende a _thread_ caso a fila esteja vazia, sendo esta retomada quando um novo elemento é inserido, resultando num consumo energético reduzido @didona2022. Em contrapartida, o modo não-bloqueante mantém a _thread_ em espera ativa até que um elemento esteja disponível, sacrificando ciclos de @cpu em troca de menor latência de resposta @ren2023.

Para maximizar o débito, as operações de inserção e remoção são realizadas em lote, transferindo até 64 pacotes por invocação, o que amortiza o custo de sincronização entre _threads_ e melhora a utilização da _cache_ do processador @ren2023. Além disso, um _pool_ de 1024 pacotes é pré-alocado durante a inicialização do canal, eliminando a necessidade de alocação de memória no caminho crítico de execução @didona2022.

=== Terminação

O controlo de terminação define o critério de paragem da carga, sendo suportadas as duas estratégias configuráveis que a @conf-terminacao exemplifica @ren2023. A terminação por iterações encerra a execução após a geração de um número fixo de pedidos, enquanto a terminação por tempo de execução impõe um limite temporal em milissegundos.

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
) <conf-terminacao>

A verificação da condição de terminação temporal é otimizada para evitar o custo excessivo de invocações ao relógio do sistema, sendo a consulta real do tempo realizada apenas a cada 4096 iterações @ren2023. Esta verificação diferida do tempo reduz significativamente o custo adicional em cargas de trabalho de alta frequência sem comprometer a precisão do limite temporal estabelecido.

=== Paralelismo

O _benchmark_ suporta a execução paralela de múltiplos _jobs_ sobre o mesmo dispositivo, sendo cada _job_ constituído por um par produtor-consumidor independente que opera sobre canais dedicados @ren2023 @didona2022. O número de _jobs_ é definido pelo parâmetro `numjobs`, resultando na criação de $2 times n$ _threads_, ou seja, uma de produção e outra de consumo.

Cada _job_ instancia os seus próprios geradores de acesso, operação e conteúdo, sendo o espaço de endereçamento automaticamente particionado entre os _workers_ para evitar colisões de _offset_ @ren2023. Deste modo, o gerador de acessos recebe o identificador do _worker_ e o número total de _jobs_, dividindo o espaço disponível em partições equitativas.

Esta abordagem permite avaliar o comportamento do sistema de armazenamento sob carga concorrente, algo fundamental na caracterização de cenários _multi-tenant_ e na identificação de contenção entre _threads_ de @io @didona2022.

=== Rampa de Aquecimento

Em determinadas avaliações, é desejável que a carga de trabalho aumente progressivamente até atingir o débito máximo, evitando assim o enviesamento dos resultados iniciais causado pela inicialização de _caches_ e estruturas internas do sistema de armazenamento @ren2023.

Para este efeito, e conforme a @conf-rampa ilustra, o _benchmark_ disponibiliza uma rampa de aquecimento configurável que realiza interpolação linear entre um rácio inicial e final ao longo de uma duração especificada em milissegundos. Quando o rácio corrente é inferior a 1.0, o produtor introduz um atraso proporcional à duração do lote, regulando assim o débito de submissão sem alterar a lógica dos geradores @ren2023.

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
) <conf-rampa>

Por esta lógica, quando o rácio inicial é inferior ao final, a rampa de aquecimento aumenta gradualmente o débito de submissão, sendo o contrário inverso igualmente válido, oferecendo ao utilizador a flexibilidade de acelerar ou desacelerar a carga de trabalho conforme necessário @ren2023.

== Geração de Cargas de Trabalho <workload-generation>

Na generalidade das interfaces, os pedidos de @io são caracterizados pelo tipo de operação, conteúdo e _offset_, ou seja a posição no disco onde o pedido será satisfeito, consequentemente a geração de cargas de trabalho pode ser desacoplada nestas três funcionalidades, dando origem a interfaces independentes para cada dimensão dos pedidos @gracia-tinedo2015 @talwadker2014.

Como fruto desta abordagem, e uma vez que os geradores são definidos ao nível dos parâmetros, a combinação entre geradores sintéticos e reais não exige qualquer tratamento adicional, isto porque o produtor apenas conhece uma interface que é independente da implementação concreta, assim é possível ter acessos reais e operações sintéticas, sendo o contrário igualmente válido @gracia-tinedo2015 @pang2026.

#figure(
  producer-flow(),
  caption: [Interação do produtor com a interface de geração de conteúdo]
) <produtor>

Tal como representado na @produtor, ao retirar um pacote da fila, o produtor invoca os métodos disponibilizados por cada uma das interfaces, de relembrar que o conteúdo do bloco apenas é gerado quando a operação solicitada for um `WRITE`. De seguida, e tendo os parâmetros devidamente identificados, os mesmos são encapsulados num pedido que é inserido na fila para futura execução por parte do consumidor.

=== Acesso

Os pedidos de `READ` e `WRITE` necessitam de ser identificados pelo _offset_ onde a operação irá ocorrer, conforme a hierarquia apresentada na @hier-acesso, neste sentido o gerador de acessos devolve o _offset_ da próxima operação a realizar, sendo de realçar que nem todas as implementações concretas apresentam o mesmo desempenho, pois algumas seguem distribuições enquanto outras utilizam aritmética simples @tracegen2024 @gracia-tinedo2015.

#figure(
  access-hierarchy(),
  caption: [Hierarquia da interface de acessos]
) <hier-acesso>

Dado que os acessos são realizados ao nível do bloco, todas as implementações devem conhecer o tamanho do bloco e o limite da zona do disco até onde é permitido ler ou escrever, deste modo os _offsets_ devolvidos serão inferiores ou iguais ao limite e acima de tudo múltiplos do tamanho do bloco @tracegen2024.

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
) <conf-acesso>

Partindo das configurações reunidas na @conf-acesso, o gerador sequencial devolve os _offsets_ num padrão contínuo, sendo que o alcance do limite implica o reposicionamento no _offset_ zero, esta estratégia beneficia claramente a localidade espacial, pois as zonas do disco são acedidas num padrão favorável @tracegen2024.

Por outro lado, os acessos totalmente aleatórios não favorecem quaisquer propriedades de localidade, daí que sejam especialmente úteis para evitar uma utilização eficiente da _cache_ @tracegen2024. Por fim, os acessos Zipfian seguem uma distribuição cujo grau de assimetria pode ser manipulado pelo utilizador, neste sentido cargas de trabalho que beneficiam da localidade temporal são facilmente replicáveis por esta implementação @tracegen2024.

=== Operação

Os sistemas de armazenamento suportam diversas operações, conforme a @hier-operacao, no entanto o gerador de operações apenas disponibiliza `READ`, `WRITE`, `FSYNC`, `FDATASYNC` e `NOP` por serem as mais comuns e portanto adotadas pela maioria das @api:pl de @io @didona2022 @ren2023. Embora a operação `NOP` não faça rigorosamente nada, a mesma é útil para testar o desempenho do _benchmark_ independente da capacidade do disco, permitindo identificar o débito máximo que o _benchmark_ consegue sustentar quando o dispositivo não constitui limitação @ren2023.

#figure(
  operation-hierarchy(),
  caption: [Hierarquia da interface de operações]
) <hier-operacao>

O gerador constante devolve sempre a mesma operação que foi definida previamente pelo utilizador. Em contrapartida, as operações percentuais são obtidas à custa de uma distribuição cujo somatório das probabilidade deve resultar em 100, exemplificando com a configuração da @conf-operacao, metade das operações serão `READS` e as restantes `WRITES` @ren2023.

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
) <conf-operacao>

Conforme se observa na @conf-operacao, a replicação de padrões é obtida com recurso ao gerador de sequência, sendo o utilizador responsável por definir uma lista de operações que mais tarde será repetidamente devolvida, neste caso em concreto, se o gerador fosse solicitado cinco vezes, as operações seriam devolvidas pela ordem: `WRITE`, `FSYNC`, `WRITE`, `FSYNC`, `WRITE` @ren2023.

*Barreiras.* Em determinados cenários, torna-se necessário injetar operações de sincronização após a execução de um número definido de escritas, algo particularmente relevante na simulação de cargas de trabalho reais onde os sistemas de ficheiros periodicamente forçam a persistência dos dados em disco @ren2023.

Para tal, o _benchmark_ disponibiliza um mecanismo de barreiras que interceta o fluxo de operações e substitui a operação corrente por outra previamente definida, sendo esta injeção despoletada quando o número de operações monitorizadas atinge um limiar configurável @didona2022. Por exemplo, uma barreira com limiar de 1024 e gatilho do tipo `WRITE` injeta uma operação de `FSYNC` a cada 1024 escritas, independentemente da lógica do gerador de operações subjacente.

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
) <conf-barreiras>

A composição de múltiplas barreiras é igualmente suportada, tal como a @conf-barreiras ilustra, sendo estas ordenadas pelo critério de proximidade ao respetivo limiar, deste modo a barreira com menor número de operações em falta é avaliada prioritariamente @ren2023. Importa realçar que após cada injeção, a reordenação dinâmica é realizada para garantir que o escalonamento reflete o estado atualizado dos contadores, evitando assim situações de inanição entre barreiras com limiares distintos.

=== Conteúdo

A geração de conteúdo, cuja hierarquia a @hier-bloco apresenta, é sem dúvida a operação mais custosa, no entanto apenas torna-se necessária quando a operação selecionada for um `WRITE`, nesse sentido o gerador de conteúdo preenche o _buffer_ associado ao pedido @constantinescu2011 @meyer2012.

Embora o gerador principal seja aquele que combina duplicados e compressão, existem outros mais rudimentares que servem para testar cenários específicos com maior eficiência, isto porque o gerador de duplicados é capaz de simular os blocos dos outros geradores, mas com um desempenho significativamente menor @koller2010 @zhu2008 @talasila2019.

#figure(
  content-hierarchy(),
  caption: [Hierarquia da interface de geração de blocos]
) <hier-bloco>

Tal como se observa na @conf-bloco, os geradores necessitam de conhecer o tamanho do bloco, deste modo podem garantir que os limites dos _buffers_ jamais serão violados. A variante mais elementar deste gerador corresponde ao constante, que devolve sempre o mesmo _buffer_, resultando numa deduplicação e compressibilidade interbloco máximas. Por outro lado, o aleatório tem exatamente o comportamento oposto, pois ao devolver _buffers_ diferentes não existem duplicados e a entropia é elevada, resultando em dados virtualmente incompressíveis @constantinescu2011.

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
) <conf-bloco>

Por fim, o gerador de duplicados e compressão procura seguir uma distribuição de duplicados definida pelo utilizador, esta estabelece a percentagem de blocos que terão X cópias, sendo que cada grupo de cópias tem associada uma distribuição de compressão, indicando que Y% dos blocos reduz cerca de Z% @constantinescu2011 @paulo2014.

Além disso, a opção `refill_buffers` permite a partilha do _buffer_ base entre blocos, deste modo quando os mesmos são criados a zona de entropia máxima é obtida a partir do _buffer_, consequentemente todos os blocos partilham a mesma informação e portanto a compressibilidade interbloco atinge o limite @constantinescu2011 @paulo2014.

*Configuração das distribuições.* Para que o utilizador manipule a distribuição de duplicados e compressão, o _benchmark_ oferece um ficheiro de configuração sobre o qual as informações são retiradas, bastando seguir o formato indicado na @conf-distribuicao @dedisbench @dedisbenchpp @paulo2013.

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
) <conf-distribuicao>

A distribuição de duplicados e compressão é definida de modo particular, inicialmente é realizada uma associação entre o número de cópias e a respetiva probabilidade, sendo mais tarde definidas as taxas de compressão dentro de cada grupo @constantinescu2011 @paulo2014.

#grid(
  columns: (1.3fr, 1fr),
  gutter: 5pt,
  [
    #figure(
      dedup-map(),
      caption: [Mapa dos duplicados],
    ) <dedup-map>
  ],
  [
    #figure(
      compression-map(),
      caption: [Mapa das taxas de compressão],
    ) <compression-map>
  ],
)

A @compression-map representa a estrutura sobre a qual as taxas de compressão são armazenadas para cada grupo, sendo basicamente um mapa que associa o número de repetições a uma lista formada por tuplos de percentagem cumulativa e respetiva redução @constantinescu2011 @paulo2014.

Por outro lado, a @dedup-map é responsável por gerir os blocos duplicados e tem um funcionamento semelhante ao de uma janela deslizante, onde os tuplos da lista são constituídos pelo identificador de bloco e cópias que faltam efetuar @talasila2019 @policroniades2004.

O funcionamento do algoritmo é o seguinte, inicialmente uma entrada do mapa é selecionada conforme as probabilidades do ficheiro de configuração, a partir daí, caso a lista não tenha atingido o limite de elementos, um novo é adicionado com o número de cópias igual ao de repetições @talasila2019.

Na situação em que a lista encontra-se completa, um dos elementos é selecionado aleatoriamente e o valor das cópias em falta é decrementado uma unidade, ao ser atingido o valor zero a entrada é definitivamente retirada da lista, pois o bloco já foi repetido as vezes necessárias @talasila2019.

Por fim, depois de selecionado o identificador do bloco, volta a ser sorteado um número aleatório para descobrir a taxa de compressão a aplicar, de relembrar que a distribuição é obtida pela entrada do mapa selecionada inicialmente @constantinescu2011 @paulo2014.

Apesar de eficiente, esta abordagem acarreta o custo associado à geração pseudoaleatória, uma operação que tende a ser mais exigente computacionalmente do que as restantes envolvidas na geração de conteúdo, pelo que o desenho prevê que os valores sejam produzidos em lote e consumidos à medida que cada bloco é construído. Desta forma, o custo permanece negligenciável quando comparado com o tempo das operações de @io, não constituindo um gargalo na avaliação do sistema de armazenamento.

== Cargas Baseadas em _Traces_ <trace-workloads>

Embora os geradores sintéticos ofereçam elevada flexibilidade na parametrização das cargas de trabalho, a reprodução de comportamentos observados em ambientes de produção exige a utilização de _traces_ reais, os quais capturam a sequência temporal de operações de @io executadas por sistemas em funcionamento @gracia-tinedo2015 @tracegen2024.

Neste sentido, cada um dos três geradores descritos na @workload-generation (acesso, operação e conteúdo) disponibiliza uma implementação do tipo `trace`, sendo esta responsável por consumir registos de um ficheiro binário e extrair a dimensão correspondente, nomeadamente o _offset_, tipo de operação e identificador de bloco @tracegen2024 @pang2026.

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
  caption: [Estrutura de um registo do _trace_]
) <trace-record>

Cada registo apresenta a estrutura indicada na @trace-record, sendo a leitura realizada por um componente partilhado entre todos os geradores baseados em _traces_, o qual mantém um _buffer_ de leitura configurável pelo utilizador através do parâmetro `memory`, evitando assim carregamentos excessivos em memória quando o _trace_ excede a capacidade disponível.

Uma vez que os geradores são definidos ao nível dos parâmetros individuais e o produtor conhece apenas a interface abstrata de cada um, a combinação entre geradores sintéticos e baseados em _traces_ resulta diretamente do desenho @gracia-tinedo2015 @pang2026. A @conf-hibridas exemplifica duas destas combinações, utilizando a primeira acessos provenientes de um _trace_ real enquanto as operações seguem uma distribuição percentual sintética, e extraindo a segunda do _trace_ as operações e o conteúdo sobre uma distribuição Zipfian de acessos.

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
  caption: [Exemplos de configuração de cargas híbridas]
) <conf-hibridas>

Esta abordagem constitui uma das principais contribuições do _benchmark_, pois permite colmatar as limitações temporais dos _traces_ com a extensibilidade dos geradores sintéticos, resultando em cargas que preservam as propriedades estatísticas do ambiente real sem estarem confinadas à duração original da captura @tracegen2024 @pang2026.

=== Extensões de _Trace_ <trace-extensions>

O problema fundamental da utilização de _traces_ prende-se com a sua natureza finita, pois ao atingir o final do ficheiro torna-se necessário decidir como prosseguir com a geração de pedidos @tracegen2024. Para resolver esta limitação, o _benchmark_ implementa três estratégias de extensão que diferem no grau de sofisticação e fidelidade ao _trace_ original.

*Repetição.* A extensão mais elementar consiste na repetição cíclica do _trace_, onde ao atingir o final do ficheiro o leitor é reposicionado no início e os registos são novamente devolvidos pela mesma ordem @tracegen2024. Embora esta abordagem preserve perfeitamente a sequência original, a mesma não introduz variabilidade e portanto a carga de trabalho resultante é estritamente periódica, algo que pode não refletir o comportamento real de um sistema em produção continuada.

*Amostragem.* A segunda estratégia opera em duas fases distintas, sendo a primeira dedicada à recolha de amostras representativas do _trace_ através de amostragem por reservatório @vitter1985, garantindo que cada registo do _trace_ tem igual probabilidade de ser incluído independentemente do tamanho do ficheiro @tracegen2024.

Ao atingir o final do _trace_, a segunda fase é iniciada com a construção de uma _alias table_ para cada dimensão @walker1977 @vose1991. Esta estrutura reparte os valores observados por tantas colunas quantos os valores distintos, cabendo em cada coluna um valor principal e um alternativo, de tal modo que sortear uma coluna ao acaso e decidir entre os dois com um lançamento ponderado devolve uma amostra em tempo constante $O(1)$ que respeita as distribuições marginais observadas @tracegen2024. Desta forma, os registos sintéticos gerados após o _trace_ preservam as frequências relativas de cada _offset_, operação e identificador de bloco, embora a correlação entre dimensões não seja mantida por estas serem amostradas de forma independente.

*Regressão.* A extensão mais sofisticada procura capturar não apenas as distribuições marginais mas também as correlações entre as várias dimensões do _trace_, recorrendo para isso a dois modelos de regressão linear que relacionam a operação e o identificador de bloco entre si e com o _offset_ de cada registo @tracegen2024.

À semelhança da amostragem, a primeira fase é dedicada à recolha de dados, sendo guardados os primeiros `max_samples` registos enquanto o _trace_ continua a ser reproduzido sem alterações, e retendo-se de cada um o _offset_ $x_i$, o identificador de bloco $z_i$ e a operação $y_i$, esta última representada pelo código numérico do respetivo tipo, em que o zero corresponde à leitura e o um à escrita.

Nesta formulação, o _offset_ assume o papel de variável independente, isto porque é a única dimensão que pode ser prolongada sem recorrer ao modelo, ao passo que a operação e o identificador de bloco são explicados cada um pelo _offset_ e pela dimensão restante:

$
y = a_0 + a_1 x + a_2 z
$

$
z = b_0 + b_1 x + b_2 y
$

Nestas equações, $a_0$ e $b_0$ correspondem aos termos independentes, ou seja, ao valor de base de cada dimensão, enquanto $a_1$ e $b_1$ traduzem a variação da operação e do identificador de bloco ao longo do disco, por exemplo uma maior concentração de escritas nos _offsets_ mais elevados, e $a_2$ e $b_2$ quantificam a influência que cada uma destas dimensões exerce sobre a outra.

Os seis coeficientes são ajustados por mínimos quadrados, ou seja, escolhidos de modo a minimizar a soma dos quadrados das diferenças entre os valores observados nos $n$ registos recolhidos e os previstos pelo modelo, sendo o ajuste de $b_0$, $b_1$ e $b_2$ idêntico ao seguinte, apenas com os papéis de $y_i$ e $z_i$ trocados:

$
min_(a_0, a_1, a_2) sum_(i=1)^n (y_i - a_0 - a_1 x_i - a_2 z_i)^2
$

A resolução é realizada através de decomposição ortogonal completa, que garante estabilidade numérica e devolve uma solução mesmo quando as colunas do sistema são linearmente dependentes, algo que acontece, por exemplo, num _trace_ composto apenas por escritas, onde a operação é constante e portanto indistinguível do termo independente. Concluído o ajuste, os registos recolhidos são descartados, uma vez que a partir daí apenas os coeficientes são necessários.

Esgotado o _trace_, a geração de cada novo registo começa pelo _offset_, extrapolado linearmente a partir do último valor recolhido $x_n$ e do passo médio $Delta$ entre registos consecutivos, o qual corresponde à média das diferenças entre _offsets_ sucessivos, pelo que o $k$-ésimo registo sintético é posicionado em:

$
x_(n+k) = x_n + k Delta, quad Delta = (x_n - x_1) / (n - 1)
$

Conhecido o _offset_, a operação e o identificador de bloco não podem ser calculados um após o outro, visto cada equação depender do valor que a outra devolve, daí que ambas sejam resolvidas em simultâneo, passando para o lado esquerdo os termos que envolvem as incógnitas, o que dá origem ao seguinte sistema $2 times 2$:

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
  a_0 + a_1 x_(n+k);
  b_0 + b_1 x_(n+k)
)
$

Sempre que o determinante $1 - a_2 b_2$ é não nulo, o sistema admite uma solução única, sendo os valores reais assim obtidos convertidos num registo válido, ou seja, a operação é arredondada ao código mais próximo entre os tipos suportados, o identificador de bloco ao inteiro não negativo mais próximo, e o _offset_ reconduzido à partição do dispositivo atribuída ao _job_, tal como acontece com qualquer _offset_ lido do _trace_ @tracegen2024.

#figure(
  table(
    columns: (1fr, 1fr, 1.5fr, 1.5fr),
    inset: 8pt,
    align: horizon + left,
    fill: (x, y) => if y == 0 { gray.lighten(60%) },
    table.header(
      [*Propriedade*], [*Repetição*], [*Amostragem*], [*Regressão*]
    ),
    [Extrapolação], [Cíclica], [Limitada ao reservatório], [Linear além do _trace_],
    [Correlações], [Preservadas], [Perdidas (independência)], [Capturadas (modelo linear)],
    [Memória], [$O(n_"buffer")$], [$O(n_"reservoir")$], [$O(1)$ (matrizes pequenas)],
    [Complexidade], [$O(1)$], [$O(1)$], [$O(1)$],
  ),
  caption: [Comparação entre as estratégias de extensão de _traces_]
) <comp-extensoes>

A @comp-extensoes resume os compromissos assumidos por cada estratégia, sendo a extensão por regressão particularmente adequada quando se pretende prolongar a carga para além da duração do _trace_ mantendo as dependências estruturais entre as dimensões, algo que a amostragem independente não consegue garantir @tracegen2024 @pang2026.

== Interfaces de E/S

Tendo em consideração o modelo de execução descrito na @execution-model, o consumidor recebe os pedidos do produtor e procede de imediato ao desencapsulamento para compreender o tipo de operação em questão e assim facilitar o acesso aos restantes parâmetros, como _offset_ e conteúdo @didona2022.

Conforme representado na @consumidor, a interface de submissão aceita operações de qualquer tipo, assim o consumidor não é responsável por definir as alterações de comportamento associadas @ren2023. Mal o pedido seja dado por concluído, a estrutura é devolvida pela interface, permitindo ao consumidor retirá-la da fila para que a zona de memória seja reutilizada mais tarde.

#figure(
  consumer-flow(),
  caption: [Interação do consumidor com a interface de submissão]
) <consumidor>

Além da submissão de pedidos, a interface assegura a abertura do ficheiro ou dispositivo alvo antes de o produtor e o consumidor entrarem em execução, bem como o respetivo fecho depois de ambos terminarem, delimitando assim o ciclo de vida de cada _job_, sendo estas duas operações dispensadas pelo motor do @spdk, visto este aceder diretamente ao dispositivo de armazenamento sem passar por qualquer sistema de ficheiros @spdk_docs.

Perante a combinação de interfaces síncronas e assíncronas, a submissão de um pedido nem sempre permite devolver de imediato a estrutura que o transporta, pois no caso das interfaces assíncronas nunca se sabe exatamente quando o pedido será dado por concluído e além disso não é possível esperar até que tal aconteça, caso contrário estaria a ser dado comportamento síncrono e as vantagens de paralelismo seriam perdidas @uring_kernel @rust_iouring_async.

Daqui decorre um segundo problema para o motor no final de cada carga, isto porque numa interface assíncrona a última submissão não coincide com a última conclusão. Podem por isso existir pedidos em curso no momento em que o _job_ termina, os quais o motor tem de aguardar antes de fechar o ficheiro, sob pena de a execução terminar com escritas por confirmar e estruturas por devolver.

=== POSIX

Com o objetivo de flexibilizar o _benchmark_, todas as implementações de `Engine` possuem uma configuração para manipulação dos parâmetros e respetivo comportamento, neste caso em concreto, e por se tratar da interface com menos parâmetros expostos, a única configuração possível ocorre na chamada `open` através das _flags_ passadas como argumento @didona2022.

Posto isto, e conforme a @conf-posix demonstra, a estrutura de configuração indica o motor selecionado, bem como uma lista das _flags_ que o utilizador considera relevantes para a execução da carga de trabalho, por questões de comodidade na implementação, somente as _flags_ mais relevantes são suportadas.

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
) <conf-posix>

#figure(
  posix-flow(),
  caption: [Funcionamento interno do motor POSIX]
) <fluxo-posix>

Por ostentar comportamento síncrono, o motor POSIX não conhece o problema dos pedidos pendentes, visto a receção de cada pedido ser seguida da chamada ao sistema associada ao tipo de operação, que apenas retorna depois de o pedido estar concluído, pelo que o código de erro e a estrutura do pedido são devolvidos de imediato e nenhum pedido fica pendente no final da execução @didona2022.

=== AIO

Relativamente à interface libaio, cuja configuração a @conf-aio apresenta, tudo se resume a um parâmetro, sendo `entries` responsável por definir a profundidade máxima da fila de pedidos em curso, o que corresponde ao número de _buffers_ alinhados pré-alocados durante a inicialização do contexto através da chamada ao sistema `io_queue_init` @didona2022.

Tal como a @fluxo-posix representa para o caso síncrono, cada motor define a forma como os pedidos atravessam a interface, baseando-se a estratégia da libaio na acumulação de pedidos num lote até que a capacidade máxima seja atingida, sendo nesse momento submetidos atomicamente através de `io_submit` @didona2022. As conclusões são recolhidas de forma bloqueante por `io_getevents`, que espera pela disponibilidade de pelo menos um resultado antes de retornar, processando até `entries` conclusões em simultâneo.

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
) <conf-aio>

Para cada pedido em curso, é mantido um _buffer_ independente alinhado ao tamanho do bloco, garantindo compatibilidade com `O_DIRECT` e evitando cópias adicionais durante a submissão @didona2022. Um _pool_ de índices disponíveis controla a reutilização segura dos _buffers_, sendo que quando não existem posições livres, o motor força a recolha de conclusões antes de aceitar novos pedidos, prevenindo assim a saturação do contexto.

=== io_uring

Ao fazer uso do sistema de ficheiros, os argumentos de abertura são semelhantes aos da @conf-posix, pelo que, conforme a @conf-uring, a configuração da `UringEngine` apresenta uma lista das mesmas _flags_ @uring_kernel.

Conforme a @fluxo-uring ilustra, os pedidos são depositados no anel de submissão e recolhidos do anel de conclusão, definindo os parâmetros `entries` e `cq_entries` a profundidade da @sq e da @cq respetivamente, por norma estes valores são potências de dois entre 64 e 256, isto porque valores pequenos diminuem o paralelismo, enquanto o contrário resulta num aumento do consumo de memória e desperdício da localidade da _cache_ @didona2022.

Relativamente às _flags_ para controlo do anel e processamento de @io, o utilizador usufruir de total liberdade de escolha, sendo de realçar a _flag_ `IORING_SETUP_SQPOLL` que cria uma _thread_ no _kernel_ para pollar a @sq e assim os pedidos serem submetidos sem a necessidade de invocar a chamada ao sistema `io_uring_enter`. Por outro lado, a _flag_ `IORING_SETUP_SQ_AFF` estabelece a afinidade da _thread_ do _kernel_, sendo tanto o núcleo escolhido como o período de inatividade definidos pelo utilizador, tal como na configuração da @conf-uring, caso em que a _thread_ será fixada no núcleo zero e após 100 milissegundos de inatividade entrará em suspensão @rust_iouring_async.

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
) <conf-uring>

#figure(
  uring-flow(),
  caption: [Funcionamento interno do motor io_uring]
) <fluxo-uring>

Tratando-se de uma interface assíncrona, o seu bom uso passa por diminuir a invocação de chamadas ao sistema e manter os pedidos em curso no máximo permitido, o que corresponde à capacidade da @sq @uring_kernel. Tendo isto em consideração, a `UringEngine` não executa os pedidos mal estes sejam recebidos, procura sim formar um lote para submeter vários em simultâneo @rust_iouring_async.

Depois de o primeiro lote ser submetido, a estratégia é alterada para preservar a quantidade de pedidos em curso, portanto mal seja encontrada uma @sqe dísponivel, a mesma é preparada e submetida independentemente de haver ou não um lote. É certo que esta abordagem aumenta as chamadas ao sistema, porém quando combinada com a _thread_ de _polling_ do _kernel_, permite atingir débitos e @iops deveras elevados @uring_kernel.

=== SPDK

Uma vez que o @spdk possui um ficheiro de configuração próprio, utilizado para definir os @bdev, controladores de disco, tamanho dos blocos e afins, os parâmetros manipuláveis pelo _benchmark_ a nível aplicacional são limitados @spdk_docs.

Posto isto, `spdk_threads` indica o número de _threads_ lógicas que serão criadas e pelas quais os pedidos de @io serão distribuídos em _round-robin_, importa realçar que tais _threads_ funcionam como uma abstração sobre o _reactor_, o qual é responsável por escalonar as tarefas e direcioná-las para que sejam executadas nos núcleos corretos @didona2022.

Conforme a @conf-spdk indica, o número de núcleos realmente utilizados pelo _runtime_ do @spdk é identificado por `reactor_mask`, neste caso em particular, `0XF` convertido para binário equivale a `1111`, assim os quatro primeiros núcleos do sistema estão disponíveis para escalonamento de tarefas @spdk_docs.

Embora as _threads_ lógicas possam ser fixadas em qualquer núcleo, o componente `SPDKRuntime` está fixado no primeiro núcleo e em espera ativa por pedidos de @io vindos da aplicação, portanto qualquer outra _thread_ fixada no mesmo núcleo nunca será capaz de executar, afinal o _runtime_ é interminável no consumo de recursos @didona2022.

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
) <conf-spdk>

#figure(
  spdk-flow(),
  caption: [Funcionamento interno do motor SPDK]
) <fluxo-spdk>

Ao iniciar o _runtime_ do @spdk, o ambiente de execução muda completamente e torna-se difícil comunicar com os restante componentes do nível aplicacional, deste modo `SPDKEngine` serve essencialmente para transmitir os pedidos de @io através de um gatilho partilhado pelo _runtime_ @spdk_docs.

No momento em que este recebe um pedido, é necessário aguardar por uma zona de memória disponível, isto porque um _buffer_ foi inicialmente alocado para propósitos de @dma. De seguida, o pedido é encapsulado numa mensagem própria do @spdk e transmitido a uma _thread_ lógica, sendo esta responsável por submeter ao @bdev e executar a operação de _callback_ quando o pedido estiver concluído @didona2022.

Por fim, e conforme a @fluxo-spdk representa, como os pedidos vão acompanhados de um gatilho, o motor do @spdk é notificado acerca da conclusão e portanto percebe que é seguro devolver a estrutura ao produtor @spdk_docs.

== Métricas e Relatório

Durante a execução de cargas de trabalho, o _benchmark_ é responsável por recolher métricas sobre cada uma das operações de @io realizadas, algo fundamental na caracterização e posterior avaliação do sistema de armazenamento, isto porque _scripts_ estatísticos podem analisar o ficheiro de registo resultante das métricas @didona2022 @ren2023.

#figure(
  grid(
    columns: (1.15fr, 0.8fr, 1.05fr),
    gutter: 5pt,
    raw_code_block[
      ```yaml
      base:
        type: operação
        block: id do bloco
        cpr: taxa de compressão
        sts: instante inicial
        ets: instante final
        proc: bytes processados
      ```
    ],
    raw_code_block[
      ```yaml
      standard:
        # campos de base
        pid: processo
        tid: thread
      ```
    ],
    raw_code_block[
      ```yaml
      full:
        # campos de standard
        req: bytes pedidos
        offset: posição
        ret: código de retorno
        errno: código de erro
      ```
    ],
  ),
  caption: [Campos registados por cada pacote de métricas]
) <pacotes-metricas>

Tendo isto em consideração, e conforme a @pacotes-metricas apresenta, o utilizador escolhe entre três pacotes de métricas progressivamente mais completos, incluindo cada um todos os campos do anterior, de modo a ajustar o detalhe recolhido às necessidades da avaliação. Importa realçar que somente as operações de `WRITE` levam à geração de blocos, como tal qualquer outra operação apresenta um identificador de bloco igual a zero @didona2022.

#figure(
  raw_code_block[
  #set text(size: 9.5pt)
  ```
  [prismo] [info] [type=1 block=1 cpr=0 sts=3480446313169 ets=3480446319309 proc=4096]
  [prismo] [info] [type=1 block=2 cpr=100 sts=3480446320554 ets=3480446323543 proc=4096]
  [prismo] [info] [type=1 block=3 cpr=100 sts=3480446324413 ets=3480446326723 proc=4096]
  [prismo] [info] [type=1 block=4 cpr=0 sts=3480446327460 ets=3480446329981 proc=4096]
  [prismo] [info] [type=1 block=5 cpr=100 sts=3480446330781 ets=3480446332925 proc=4096]
  [prismo] [info] [type=1 block=6 cpr=50 sts=3480446333681 ets=3480446336316 proc=4096]
  ```
  ],
  caption: [Estrutura do ficheiro de registo]
) <ficheiro-log>

A @ficheiro-log exemplifica a estrutura do ficheiro onde as métricas são armazenadas, a qual dispensa processamento adicional, dado cada linha corresponder a um pedido e conter os campos separados por espaços, neste caso em particular o pacote selecionado foi o mais elementar, portanto os campos presentes coincidem com os da primeira coluna da @pacotes-metricas, surgindo a operação codificada pelo respetivo valor numérico, em que o um corresponde à escrita @didona2022.

Por fim, quanto mais detalhadas forem as métricas recolhidas, pior será o desempenho do _benchmark_, daí que o registo possa ser desativado por completo para atingir o máximo de desempenho @ren2023. Ademais, como as métricas são escritas num ficheiro de registo, o dispositivo que o acolhe suporta carga para além da execução do _benchmark_, algo que pode enviesar os resultados caso coincida com o dispositivo avaliado, bastando porém destiná-lo a outro alvo para que a escrita deixe de competir com a carga em medição @didona2022.

=== Estatísticas e Relatório Final

Além do registo individual de métricas por operação, o _benchmark_ agrega as observações recolhidas durante a execução e produz o relatório final que a @relatorio-final resume, com indicadores estatísticos para cada tipo de operação @ren2023 @didona2022.

As latências são registadas num histograma HDR @hdrhistogram, estrutura que permite obter percentis sem armazenar cada observação individualmente, disponibilizando os valores p50, p90, p95, p99, p99.9 e p99.99, métricas particularmente relevantes na caracterização da cauda da distribuição de latências @ren2023.

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
) <relatorio-final>

Quando múltiplos _jobs_ são executados em paralelo, o relatório contém os resultados individuais de cada _job_ e um registo adicional resultante da fusão de todas as estatísticas, onde os histogramas de latência são combinados e os instantes de início e fim são ajustados para refletir o intervalo global de execução @ren2023.

== Implementação <implementation>

O Prismo encontra-se implementado em C++20, escolha que decorre do requisito de manter o custo da geração de conteúdo muito abaixo do débito do dispositivo, o que exige controlo explícito sobre a disposição da memória e a ausência de um _garbage collector_.

Essa exigência estende-se às bibliotecas adotadas, começando pela fila concorrente que liga o produtor ao consumidor, a moodycamel::ConcurrentQueue 1.0.4 @moodycamel, e seguindo pelo gerador pseudoaleatório SHISHUA @shishua, cujo débito em lote sustenta a construção de cada bloco sem se tornar o fator limitante da execução.

Quanto às interfaces de @io, cada uma assenta diretamente na biblioteca da respetiva tecnologia, nomeadamente a libaio 0.3.113 @libaio, a liburing 2.14 @liburing e o @spdk 26.01 @spdk_docs, sem qualquer camada intermédia entre o motor e a interface que este representa, pelo que o comportamento medido corresponde ao da própria interface.

Completam o conjunto as bibliotecas de apoio, concretamente a Eigen 5.0.1 @eigen para o ajuste dos modelos lineares da extensão por regressão, a nlohmann/json 3.12.0 @nlohmann_json para a leitura das configurações e a escrita dos relatórios, e o spdlog 1.17.0 @spdlog para o registo por operação.

A estas juntam-se o Boost.Pool 1.90.0 @boost_pool, que gere a memória dos blocos retidos pelo gerador de duplicados enquanto aguardam as respetivas cópias, e a argparse 3.2 @argparse, que interpreta os argumentos da linha de comandos, sendo a compilação orquestrada pelo Meson 1.12.1 @meson.

Além do próprio _benchmark_, resultam ainda deste trabalho duas ferramentas autónomas, o Astroide, que converte os _traces_ do @fiu para o formato binário consumido pelo Prismo, e o Deltoide, que analisa os dados efetivamente escritos em disco e deles extrai as distribuições de duplicados e compressibilidade, recorrendo à zstd 1.5.7 @zstd para aferir esta última, permitindo assim confirmar que o conteúdo submetido corresponde ao configurado.

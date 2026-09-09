#import "../utils/charts.typ" : tool-bars, tool-lines, cpu-stack, component-bars, trace-lines, workload-lines
#import "../utils/functions.typ" : question_block, validation_point_block, doc_table, cell_yes, cell_no, cell_partial

== Avaliação Experimental <chapter4>

Após a descrição da arquitetura e dos mecanismos que sustentam a geração de workloads realistas, importa agora avaliar experimentalmente o Prismo, por um lado validando a sua correção e comparando o desempenho com as ferramentas de referência, e por outro demonstrando que a incorporação de propriedades de conteúdo nas workloads revela comportamentos dos sistemas de armazenamento que, de outro modo, permaneceriam invisíveis.

Neste sentido, são definidas sete perguntas de investigação e quatro pontos de validação que orientam as experiências realizadas:

#question_block[
/ Q1: As propriedades intrínsecas dos dados, nomeadamente a compressibilidade e a taxa de duplicados, influenciam o desempenho dos sistemas de armazenamento?
]

#question_block[
/ Q2: Diferentes distribuições de duplicados e compressibilidade resultam em comportamentos distintos por parte dos sistemas avaliados?
]

#question_block[
/ Q3: A escolha da interface de @io influencia significativamente o desempenho medido pelo benchmark, e em que medida essa influência varia consoante o tipo de workload?
]

#question_block[
/ Q4: As workloads baseadas em traces reproduzem fielmente as propriedades observadas nos dados originais, e as estratégias de extensão preservam essas características?
]

#question_block[
/ Q5: Distribuições de acesso com forte localidade revelam comportamentos relacionados com mecanismos de cache que não são exercitados por workloads aleatórias?
]

#question_block[
/ Q6: A escolha do sistema de armazenamento condiciona o benefício obtido a partir das propriedades dos dados, e qual o custo computacional associado às otimizações sensíveis ao conteúdo?
]

#question_block[
/ Q7: Em que medida a avaliação produzida pelo Prismo difere daquela obtida através dos benchmarks existentes, e que conclusões sobre os sistemas de armazenamento avaliados se tornam possíveis a partir dessa diferença?
]

#validation_point_block[
/ V1: O Prismo é capaz de gerar workloads de @io reprodutíveis que incorporam propriedades realistas de conteúdo, nomeadamente distribuições de duplicados e compressibilidade.
]

#validation_point_block[
/ V2: As medições produzidas são estáveis ao longo da execução e comparáveis entre ferramentas, garantindo que as variações observadas decorrem das propriedades das workloads e não de efeitos alheios.
]

#validation_point_block[
/ V3: O Prismo fornece todas as informações relevantes para a análise e avaliação do sistema de armazenamento, de modo a fundamentar as configurações dos sistemas para workloads específicas.
]

#validation_point_block[
/ V4: As conclusões alcançadas através do Prismo sobre os sistemas de armazenamento avaliados não são passíveis de obtenção com os benchmarks existentes, decorrendo essa diferença do realismo do conteúdo gerado e não da instrumentação da ferramenta.
]

Posto isto, o capítulo inicia-se pela descrição da metodologia experimental, avançando depois para a validação da ferramenta através da demonstração de equivalência com os benchmarks de referência em workloads genéricas. De seguida, são analisados cenários onde as funcionalidades exclusivas do Prismo se revelam determinantes, nomeadamente a geração de conteúdo com propriedades de deduplicação e compressão, a comparação entre interfaces de @io e a replicação de workloads baseadas em traces. Por fim, explora-se a localidade de acesso enquanto eixo complementar, antes de sintetizar as conclusões.

=== Metodologia <methodology>

A avaliação experimental assenta na execução de um conjunto alargado de workloads sobre a mesma máquina e sob condições controladas, sendo esta secção responsável por descrever o ambiente utilizado, as ferramentas comparadas, o procedimento seguido e as métricas recolhidas, de modo a que os resultados apresentados nas secções seguintes possam ser corretamente interpretados e reproduzidos.

==== Setup Experimental

Todas as experiências foram conduzidas numa única máquina, evitando assim que diferenças de hardware ou de configuração entre execuções se reflitam nas métricas recolhidas. As especificações do sistema encontram-se descritas na @hardware, sendo de realçar a capacidade de memória disponível, pois a condição de terminação de algumas workloads é calculada com base nesta.

#figure(
  doc_table(
    columns: (1fr, 1.6fr),
    header: ([Componente], [Especificação]),
    [Sistema operativo], [Ubuntu 20.04.6 LTS (Focal Fossa)],
    [Kernel], [Linux 5.4.0-216-generic],
    [Arquitetura], [x86_64],
    [Processador], [2 $times$ Intel Xeon Gold 6342],
    [Núcleos], [48 físicos (24 por processador), 96 threads],
    [Frequência], [800 MHz base, 2.80 GHz máxima],
    [Memória], [188.23 GiB, DDR4-3200],
    [Dispositivo de armazenamento], [Dell Enterprise @nvme P5600 MU U.2, 1.46 TiB],
  ),
  caption: [Especificações da máquina utilizada nas experiências]
) <hardware>

O sistema opera sobre Ubuntu 20.04.6 LTS com kernel Linux 5.4.0-216-generic, versão que condiciona as funcionalidades disponíveis nas interfaces assíncronas, em particular no io_uring, cuja implementação tem vindo a ser progressivamente otimizada desde a sua introdução @uring_kernel.

Convém realçar que todos os acessos são efetuados com a flag `O_DIRECT`, o que elimina a intervenção da page cache e garante que os pedidos atingem efetivamente o dispositivo, sendo esta uma condição indispensável para que as métricas reflitam o comportamento do sistema de armazenamento e não o da memória @didona2022 @ren2023. Esta garantia é integral quando o dispositivo é acedido diretamente, sem sistema de ficheiros interposto, no entanto os sistemas de ficheiros avaliados impõem-lhe restrições que serão detalhadas adiante.

==== Ferramentas Comparadas

A avaliação confronta o Prismo, na versão 1.0.0, com o @fio e o Vdbench, duas das ferramentas mais utilizadas na avaliação de sistemas de armazenamento, nas versões mais recentes de cada uma, respetivamente a 3.42 e a 5.04.07 @fio_docs @vdbench.

Estas ferramentas não partilham, no entanto, o mesmo âmbito de aplicação, pois enquanto o @fio suporta as mesmas interfaces de @io que o Prismo, apesar de o acesso ao @spdk ser conseguido através de um plugin externo, o Vdbench opera exclusivamente sobre POSIX síncrono, o que restringe a comparação entre as três ferramentas a esse cenário @fio_docs @vdbench.

#figure(
  doc_table(
    columns: (3fr, 1fr, 1fr, 1fr),
    header: ([Interface], [Prismo], [FIO], [Vdbench]),
    [POSIX], cell_yes, cell_yes, cell_yes,
    [libaio], cell_yes, cell_yes, cell_no,
    [io_uring], cell_yes, cell_yes, cell_no,
    [SPDK], cell_yes, cell_partial[Plugin], cell_no,
  ),
  caption: [Interfaces suportadas por cada ferramenta]
) <interfaces>

As interfaces comuns a mais do que uma ferramenta foram configuradas de forma equivalente, operando o io_uring e o libaio com 128 entradas na fila de submissão, sendo no primeiro caso ativado o polling do kernel através das flags `IORING_SETUP_SQPOLL` e `IORING_SETUP_SQ_AFF`, enquanto o @spdk recorre a uma máscara de quatro reactors e oito threads lógicas.

#figure(
  doc_table(
    columns: (3fr, 1fr, 1fr, 1fr),
    header: ([Funcionalidade], [Prismo], [FIO], [Vdbench]),
    [Distribuição de duplicados], cell_yes, cell_partial[Taxa global], cell_partial[Rácio global],
    [Distribuição de compressibilidade], cell_yes, cell_partial[Taxa global], cell_partial[Rácio global],
    [Replay de traces], cell_yes, cell_partial[Limitado], cell_no,
    [Extensão sintética de traces], cell_yes, cell_no, cell_no,
  ),
  caption: [Funcionalidades suportadas por cada ferramenta]
) <ferramentas>

Esta equivalência nem sempre é alcançável no que toca ao conteúdo, uma vez que o Vdbench não dispõe de barreiras de sincronização nem de geração de conteúdo constante, sendo a distribuição Zipfian aproximada através do parâmetro `hotband`, aproximações que devem ser tidas em conta na leitura dos resultados @vdbench.

==== Campanha Experimental

A campanha experimental é constituída por quinze workloads base, cada uma isolando exatamente uma dimensão relativamente à anterior, o que permite atribuir as diferenças observadas a um único fator. Estas workloads encontram-se descritas na @workloads-base, e posteriormente replicadas para as quatro interfaces de @io avaliadas, do que resulta um total de sessenta configurações.

#[
#show figure: set block(breakable: true)
#figure(
  doc_table(
    columns: (auto, 1.2fr, 1.6fr),
    header: ([\#], [Dimensão isolada], [Parâmetros principais]),
    fill: (x, y) => if x == 0 { gray.lighten(60%) },
    [*01*], [Débito sequencial de escrita], [Escrita, sequencial, conteúdo constante],
    [*02*], [Débito sequencial de leitura], [Leitura, sequencial, conteúdo constante],
    [*03*], [Tamanho do bloco], [Escrita, sequencial, blocos de 64 KiB],
    [*04*], [Acesso aleatório], [Leitura, aleatório],
    [*05*], [Contenção entre leituras e escritas], [50/50 leitura e escrita, aleatório],
    [*06*], [Localidade de acesso], [50/50 leitura e escrita, Zipf(0.9)],
    [*07*], [Rácio assimétrico], [90/10 escrita e leitura, sequencial],
    [*08*], [Custo da durabilidade], [Sequência de operações, `fsync` a cada 1024 escritas],
    [*09*], [Paralelismo], [50/50 leitura e escrita, aleatório, 3 jobs],
    [*10*], [Compressibilidade isolada], [Zipf(0.9), três níveis de compressão],
    [*11*], [Duplicados e compressibilidade], [Zipf(0.9), três níveis de duplicados e compressão],
    [*12*], [Localidade real e operações sintéticas], [Acessos do trace homes, 70/30 leitura e escrita],
    [*13*], [Operações reais e acessos sintéticos], [Operações do trace cheetah, Zipf(0.9)],
    [*14*], [Replay integral de um fileserver], [Trace homes, extensão por repetição],
    [*15*], [Replay integral de um webmail], [Trace webmail, extensão por amostragem e regressão],
  ),
  caption: [Workloads base da campanha experimental]
) <workloads-base>
]

A dimensão das workloads foi fixada em 752.91 GiB, valor que corresponde a quatro vezes a memória disponível, garantindo assim que o conjunto de dados manipulado não é passível de acomodação em cache e que os pedidos atingem efetivamente o dispositivo. Nas workloads mais demoradas, em particular aquelas assentes em barreiras de sincronização, alcançar este volume implicaria execuções incomportáveis, daí que nestes casos a condição de paragem seja de quinze minutos de execução, duração suficiente para que o sistema atinja um regime estacionário @traeger2008 @tarasov2011.

Cada configuração corresponde a uma única execução, sendo a estabilidade das medições aferida a partir das séries temporais recolhidas ao longo dessa execução, conforme descrito adiante @traeger2008 @tarasov2011.

===== Estabilização do Sistema entre Execuções

Antes de cada execução é aplicado um procedimento de limpeza que garante o isolamento entre medições, evitando que o estado deixado pela execução anterior contamine os resultados da seguinte. Este procedimento inicia-se com um `sync`, que força a escrita para o disco de todas as páginas ainda pendentes em memória, assegurando deste modo que nenhuma operação da execução anterior transita para a janela de medição seguinte.

De seguida, é escrito o valor 3 em `/proc/sys/vm/drop_caches`, invalidando não só a page cache mas também as estruturas de dentries e inodes mantidas pelo kernel. Esta invalidação assume particular importância nos sistemas de ficheiros avaliados, uma vez que a flag `O_DIRECT` não impede o recurso à cache quando as otimizações de conteúdo se encontram ativas.

Por fim, o procedimento aguarda cinco minutos antes de iniciar a execução seguinte, período durante o qual o dispositivo permanece em repouso e conclui as tarefas internas de manutenção, como o garbage collection e o esvaziamento dos buffers. Sem esta pausa, uma workload intensiva em escritas deixaria o dispositivo num estado degradado, penalizando artificialmente a execução subsequente @traeger2008 @tarasov2011.

==== Sistemas de Armazenamento Avaliados

As workloads são executadas sobre três sistemas de armazenamento distintos, sendo o primeiro o próprio dispositivo @nvme acedido sem qualquer sistema de ficheiros interposto, cenário que serve a comparação entre ferramentas e entre interfaces de @io, enquanto o Btrfs e o @zfs são avaliados por implementarem otimizações sensíveis às propriedades dos dados, nomeadamente compressão e deduplicação.

#figure(
  doc_table(
    columns: (1.3fr, 1fr, 1fr, 1fr),
    header: ([Sistema], [Versão], [Compressão], [Deduplicação]),
    [@nvme `/dev/nvme0n1`], [Kernel 5.4], [Não], [Não],
    [Btrfs], [btrfs-progs 5.4.1-2], [zstd, nível 3], [Offline, via bees 0.11],
    [@zfs], [2.4.0], [zstd, nível 3], [Inline],
  ),
  caption: [Sistemas de armazenamento avaliados e respetiva configuração]
) <sistemas>

Em ambos os sistemas de ficheiros a compressão recorre ao zstd no nível 3, valor que estabelece o compromisso entre a qualidade da compressão e a rapidez com que esta é alcançada, visto níveis superiores comprimirem mais, no entanto a um custo computacional que enviesaria a avaliação do sistema de armazenamento em detrimento da avaliação do próprio algoritmo @btrfs_docs.

No @zfs o recordsize foi ainda fixado em 4 KiB, de modo a coincidir com os blocos manipulados pela generalidade das workloads. Esta decisão revela-se indispensável, isto porque a deduplicação opera ao nível do record, daí que um valor superior implicasse que blocos duplicados de 4 KiB jamais originassem records idênticos, tornando a otimização inoperante face ao conteúdo gerado @zfs_docs.

As estratégias de deduplicação diferem igualmente, visto o @zfs atuar no caminho crítico de @io enquanto o Btrfs delega a tarefa no bees, um serviço que percorre o sistema de ficheiros em segundo plano recorrendo a um índice limitado a 1 GiB @bees. Tal diferença condiciona a leitura dos resultados, dado que no Btrfs a redução de espaço apenas se manifesta após a passagem do serviço, ao contrário do @zfs onde é imediata, embora ao custo de latência acrescida nas escritas @koller2010 @meyer2012.

Importa realçar que a garantia oferecida pela flag `O_DIRECT` deixa de ser absoluta quando estas otimizações se encontram ativas. No Btrfs, tanto as leituras de dados comprimidos como as escritas sobre inodes com checksums acabam por transitar pela page cache, enquanto no @zfs a deduplicação e as escritas diretas são mutuamente incompatíveis, o que obrigou a desativar a propriedade `direct` nos conjuntos de dados avaliados @btrfs_docs @zfs_docs.

Desta forma, os resultados obtidos sobre sistemas de ficheiros não são diretamente comparáveis com os do acesso direto ao dispositivo no que respeita ao efeito da page cache, limitação que decorre da natureza das otimizações avaliadas e não da metodologia adotada.

Em qualquer dos casos, o Prismo, tal como o @fio e o Vdbench, emite pedidos de leitura e escrita de tamanho fixo sobre um ficheiro previamente alocado, exercitando por isso o caminho de dados e não as operações de metadados. Assim sendo, não se trata de uma avaliação de sistemas de ficheiros, mas antes da forma como cada sistema reage às propriedades do conteúdo que lhe é submetido.

==== Métricas

As métricas recolhidas dividem-se entre aquelas reportadas pelas próprias ferramentas e as obtidas ao nível do sistema. Do primeiro grupo fazem parte o débito, os @iops e a latência, esta última caracterizada não apenas pelo valor médio mas também pelos percentis p50, p99 e p99.9, pois a média isoladamente esconde o comportamento da cauda da distribuição @traeger2008 @tarasov2011.

Já as métricas de sistema, nomeadamente a utilização de @cpu e de @ram, são recolhidas através do `pcp dstat` com uma frequência de amostragem de um segundo, que constitui a única fonte comum às três ferramentas e portanto a única que permite uma comparação justa do consumo de recursos.

Nas workloads que exercitam deduplicação e compressão é ainda registado o espaço efetivamente ocupado em disco, pois só através deste é possível confirmar que as otimizações do sistema de armazenamento foram de facto acionadas pelo conteúdo gerado.

===== Agregação de Métricas

Uma vez recolhidas, as métricas são apresentadas através do valor reportado pela ferramenta, acompanhado do desvio padrão calculado sobre a respetiva série temporal. Deste modo, as barras de erro presentes nas figuras adiante traduzem a oscilação da medição ao longo da execução, sendo descartadas as primeiras amostras de modo a excluir o período de arranque.

No entanto, os percentis de latência constituem um caso particular, dado que os relatórios registam apenas o valor já calculado sobre a totalidade da execução, não sendo por isso possível acompanhar a sua evolução temporal nem associar-lhes uma medida de dispersão.

=== Validação do Prismo <validation>

Previamente a utilizar o Prismo para avaliar sistemas de armazenamento, é necessário estabelecer confiança na ferramenta, daí que esta secção procure demonstrar que os resultados produzidos são fiáveis e comparáveis aos das ferramentas de referência em workloads genéricas, ao mesmo tempo que valida a correção dos mecanismos de geração de conteúdo.

==== Débito dos Componentes

Antes de confrontar o Prismo com as ferramentas de referência, importa determinar o débito máximo que os seus componentes conseguem sustentar, pois qualquer limite imposto pela própria ferramenta comprometeria a atribuição dos resultados ao sistema de armazenamento. Para o efeito, cada gerador foi exercitado isoladamente, sem submissão de pedidos, ao longo de 100 milhões de invocações.

#figure(
  grid(
    columns: 2, gutter: 6pt, row-gutter: 10pt,
    component-bars("components.csv", "Acesso"),
    component-bars("components.csv", "Conteúdo"),
    component-bars("components.csv", "Operação"),
    component-bars("components.csv", "Extensão"),
  ),
  caption: [Débito máximo de cada componente do Prismo]
) <componentes>

Os valores reunidos na @componentes revelam uma disparidade de duas ordens de grandeza entre variantes, sendo o gerador de operações constante o mais rápido, com 844.8 milhões de operações por segundo, enquanto o gerador de conteúdo com deduplicação se fica pelos 4.8 milhões, diferença que se explica pelo trabalho envolvido, dado que o primeiro devolve um valor fixo e o segundo constrói um bloco de 4096 bytes respeitando uma distribuição de duplicados e de compressibilidade.

Uma workload combina sempre um gerador de cada categoria, atuando estes em série na preparação de cada pedido, pelo que o débito da configuração resulta da soma dos respetivos tempos. Convém realçar que uma extensão de trace pode assumir o papel de qualquer um destes geradores, admitindo-se por isso configurações que recorrem a três extensões em simultâneo.

Nestes termos, a configuração menos favorável corresponde a três extensões por regressão, que consomem 213.7 nanossegundos cada e limitam o Prismo a 1.6 milhões de operações por segundo. Já a pior combinação entre geradores convencionais, reunindo acesso Zipfian, operações por percentagem e conteúdo com deduplicação, totaliza 294.0 nanossegundos e permite 3.4 milhões de operações por segundo.

Assim sendo, mesmo a configuração mais exigente mantém-se cerca de catorze vezes acima do débito máximo observado nas experiências, que foi de 113 015 @iops na workload 02 (demonstrado adiante), margem suficiente para acomodar dispositivos consideravelmente mais rápidos do que o utilizado. Deste modo, nenhuma combinação de geradores constitui o fator limitante da avaliação, e os resultados apresentados traduzem o comportamento do sistema de armazenamento.

==== Reprodutibilidade

A validação assenta nas workloads 01 a 09 executadas sobre o dispositivo @nvme através da interface POSIX, único cenário em que as três ferramentas operam sobre configurações muito semelhantes e podem por isso ser confrontadas diretamente.

O primeiro requisito a verificar é a estabilidade das medições, pois uma ferramenta cujos valores oscilem acentuadamente não permite distinguir o efeito da workload do simples ruído experimental.

Esta estabilidade é quantificada pelo coeficiente de variação das séries por segundo recolhidas ao longo de cada execução, apresentado na @reprodutibilidade.

#figure(
  tool-lines("validation-cv.csv", ylabel: [Coeficiente de variação (%)]),
  caption: [Coeficiente de variação do débito de operações por workload]
) <reprodutibilidade>

Os valores obtidos pelo Prismo situam-se entre 0.50% e 2.71%, gama que confirma tratar-se de medições estáveis, sendo de realçar que em sete das nove workloads a oscilação é inferior à do Vdbench e em quatro delas inferior também à do @fio.

A workload 03 destaca-se por apresentar a maior dispersão nas três ferramentas, comportamento que não é imputável aos benchmarks mas ao dispositivo, pois trata-se da única workload com blocos de 64 KiB e o débito alcançado esgota periodicamente a cache interna do @nvme. Por outro lado, o Vdbench exibe oscilações acima de 9% em várias workloads, o que é consistente com as pausas introduzidas pela máquina virtual do Java.

Estes valores fixam o critério de leitura adotado no restante capítulo, dado que uma diferença entre duas medições só é considerada efetiva quando excede a oscilação que a própria medição apresenta. Na prática, e tomando o valor mais elevado registado pelo Prismo, diferenças inferiores a 3% são tratadas como equivalência e não como vantagem de uma ferramenta sobre a outra @traeger2008 @tarasov2011.

Convém realçar que esta análise caracteriza a estabilidade da medição e não a variabilidade entre execuções independentes, a qual exigiria a repetição integral da campanha e não foi avaliada, conforme se assinala nas limitações.

==== Equivalência em Workloads Genéricas

Aferida a estabilidade das medições, importa agora verificar se o Prismo produz valores comparáveis aos das ferramentas de referência quando submetido às mesmas condições, confronto que incide sobre o débito de operações, a latência e o consumo de recursos.

#figure(
  tool-bars("validation-iops.csv", ylabel: [Milhares de @iops]),
  caption: [Débito de operações por workload em cada ferramenta]
) <validacao-iops>

O débito apresentado na @validacao-iops revela concordância entre as três ferramentas em praticamente todas as workloads, com desvios que se mantêm abaixo do limiar de dispersão nos cenários dominados pelo dispositivo, ou seja naqueles assentes em acessos aleatórios. Nestas condições o dispositivo satura muito antes de qualquer ferramenta se aproximar do seu limite, pelo que as três medem inevitavelmente a mesma realidade.

As workloads sequenciais afastam-se ligeiramente deste padrão, com uma vantagem para o Prismo na ordem dos cinco pontos percentuais, atribuível ao modelo produtor-consumidor descrito no @chapter3, uma vez que a preparação dos pedidos decorre numa thread distinta daquela que os submete e permite manter o dispositivo ocupado enquanto o bloco seguinte é construído.

A workload 07 constitui a única exceção relevante, com o Prismo a ficar cerca de um quinto abaixo do @fio. Ambas as ferramentas executaram exatamente o mesmo trabalho, com idêntico número de operações, volume escrito e repartição entre leituras e escritas, diferindo apenas na duração, pelo que a explicação tem de residir no custo por pedido e não na carga submetida.

Descartam-se desde logo duas hipóteses, dado que a geração de conteúdo é equivalente nas duas ferramentas, visto o parâmetro `buffer_compress_percentage` do @fio ativar automaticamente o `refill_buffers` @fio_docs, e dado que a @componentes demonstra que os geradores sustentam um débito duas ordens de grandeza superior ao exigido por esta workload.

Esta leitura é corroborada pela workload 03, que recorre igualmente à regeneração de conteúdo mas com blocos dezasseis vezes maiores, reduzindo na mesma proporção o número de pedidos, e onde o Prismo volta a apresentar vantagem. Deste modo, tudo indica tratar-se de um custo que se manifesta por pedido e não por byte transferido.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("validation-latency.csv", ylabel: [Latência média (µs)],
              width: 6.0cm, height: 4.6cm, legend: false),
    tool-bars("validation-p99.csv", ylabel: [Latência p99 (µs)],
              width: 6.0cm, height: 4.6cm),
  ),
  caption: [Latência média e percentil 99 por workload em cada ferramenta]
) <validacao-latencia>

A latência média confirma a equivalência estabelecida pelo débito, sendo o painel esquerdo da @validacao-latencia essencialmente uma imagem espelhada da figura anterior, o que demonstra medir a instrumentação do Prismo a mesma realidade que as ferramentas consagradas.

O percentil 99, no painel direito, revela porém um padrão que a média esconde, pois o Prismo apresenta uma cauda mais pesada nas workloads que combinam escritas com concorrência, chegando a duplicar o valor do @fio, enquanto nas sequenciais a situação se inverte a seu favor.

Este comportamento é atribuível ao mesmo modelo produtor-consumidor que explica a vantagem no débito, uma vez que a fila de pedidos impõe backpressure ao produtor sempre que a capacidade limite é atingida, penalizando os pedidos que nela aguardam sem afetar o débito agregado. Assim sendo, o Prismo privilegia a ocupação do dispositivo em detrimento da previsibilidade individual de cada pedido, compromisso que importa ter presente sempre que a cauda da distribuição seja o objeto de estudo.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("validation-cpu.csv", ylabel: [Utilização de @cpu (%)],
              width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("validation-ram.csv", ylabel: [Memória utilizada (GiB)],
              width: 6.0cm, height: 4.4cm),
  ),
  caption: [Consumo de recursos por workload em cada ferramenta]
) <validacao-recursos>

Por fim, o consumo de recursos apresentado na @validacao-recursos demonstra que as decisões arquiteturais do Prismo não acarretam um custo desproporcional, sendo a utilização de @cpu indistinguível da do @fio, ao passo que o Vdbench se destaca por executar sobre a máquina virtual do Java @vdbench.

Ao nível da memória utilizada pela máquina a distância é mais nítida, embora modesta em termos absolutos, pois o Prismo ocupa cerca de meio gigabyte acima do @fio, diferença que decorre do pool de pacotes pré-alocado durante a inicialização do canal descrito na @chapter3, enquanto o Vdbench requer perto de três gigabytes adicionais. Tratando-se de uma máquina com 188 GiB, nenhum destes valores condiciona a avaliação.

==== Fator Limitante da Avaliação

O débito dos componentes, analisado no início desta secção, demonstrou que nenhum gerador limita a avaliação, no entanto essa medição incidiu sobre cada peça isoladamente e não sobre a execução completa. A repartição do tempo de @cpu recolhida pelo `pcp dstat` permite confirmar a conclusão em condições reais.


#figure(
  cpu-stack("validation-cpu-types.csv"),
  caption: [Repartição do tempo de @cpu durante a execução do Prismo]
) <validacao-cpu-tipos>

A @validacao-cpu-tipos apresenta as componentes de utilizador, sistema e espera por @io, correspondendo o remanescente até 100% a tempo ocioso, que se situa acima de 95% em todas as workloads com um único job e em 91.6% na workload 09. Estes valores decorrem de a máquina disponibilizar 96 threads de execução enquanto o benchmark ocupa apenas uma, ou três no caso da workload 09.

Mais relevante é a proporção entre as componentes ativas, visto a espera por @io representar entre 29% e 48% do tempo não ocioso nas workloads com um único job, valor que ascende a 70% na workload 09. Por outras palavras, o processador passa mais tempo à espera do dispositivo do que a executar código do benchmark, seja em espaço de utilizador ou dentro do kernel.

Convém realçar que a componente de utilizador, onde reside a geração de conteúdo e a preparação dos pedidos, não ultrapassa 0.77% em qualquer workload, mantendo-se sempre abaixo da componente de sistema. Assim sendo, o custo do Prismo é dominado pelas chamadas ao sistema inerentes à interface POSIX e não pela lógica própria da ferramenta.

Em suma, os resultados apresentados ao longo desta secção medem a capacidade do sistema de armazenamento e não o limite das ferramentas utilizadas, conclusão que sustenta a interpretação de todas as comparações realizadas no restante capítulo @traeger2008 @didona2022.

==== Validação da Geração de Conteúdo

A equivalência demonstrada até aqui atesta a fiabilidade da instrumentação, no entanto nada diz sobre a propriedade que distingue o Prismo, ou seja, a capacidade de gerar conteúdo com distribuições de duplicados e compressibilidade controladas. Assim sendo, o #link("https://github.com/dsrhaslab/prismo/blob/main/tools/deltoide/README.md")[Deltoide] é aplicado sobre os dados efetivamente escritos, extraindo as distribuições presentes no dispositivo de armazenamento.

A workload 11 foi configurada com três grupos de duplicados, cada um com a sua própria repartição de compressibilidade, sendo os valores configurados e os medidos apresentados na @conteudo.

#figure(
  doc_table(
    columns: (0.5fr, 0.8fr, 0.7fr, 1.4fr, 1.4fr),
    header: ([Cópias], [Configurado], [Medido], [Redução configurada], [Redução medida]),
    [0], [50.0%], [51.1%], [50% sem redução \ 50% a 50% de redução], [49.7% sem redução \ 50.3% a 49.7% de redução],
    [1], [35.0%], [34.6%], [70% a 30% de redução \ 30% a 20% de redução], [71.2% a 30.2% de redução \ 28.8% a 19.8% de redução],
    [3], [15.0%], [14.3%], [100% sem redução], [100% sem redução],
  ),
  caption: [Distribuição de duplicados e compressibilidade configurada e medida]
) <conteudo>

Os desvios observados na @conteudo não ultrapassam 1.1% na repartição de duplicados nem 1.2% na de compressibilidade, valores que confirmam uma reprodução fiel a distribuição solicitada. Além disso, observa-se um comportamento particular do algoritmo de geração de duplicados: à medida que os blocos repetidos avançam através da janela, a percentagem medida para o último nível de cópias nunca pode exceder a percentagem solicitada, uma vez que este corresponde ao último estágio.

Estes resultados fundamentam o V1, dado que a distribuição medida sobre os dados escritos corresponde à configurada, e não a uma aproximação global como a praticada pelas ferramentas de referência, cujas configurações apenas admitem uma taxa única de duplicados e de compressibilidade @fio_docs @vdbench.

=== Impacto das Propriedades dos Dados no Desempenho <data-properties>

Estabelecida a credibilidade do Prismo enquanto instrumento de medição, esta secção explora o eixo que o distingue das ferramentas de referência, nomeadamente o impacto das propriedades intrínsecas dos dados no desempenho dos sistemas de armazenamento. Na prática, benchmarks que ignoram a compressibilidade e a taxa de duplicados tendem a produzir avaliações que não refletem o comportamento real dos sistemas sensíveis ao conteúdo.

Toda a análise decorre sobre o Btrfs e o @zfs, únicos sistemas avaliados que reagem ao conteúdo, começando pelo estabelecimento de uma linha de base com dados aleatórios, uma vez que só a comparação entre workloads que diferem exclusivamente nas propriedades do conteúdo, executadas sobre o mesmo sistema, permite isolar o contributo dessas propriedades.

==== Linha de Base por Sistema de Armazenamento

As workloads 04, 05 e 06 operam sobre conteúdo aleatório, logo incompressível e sem duplicados, pelo que o débito de operações obtido traduz aquilo que cada sistema de ficheiros consegue entregar quando as suas otimizações nada têm para explorar. Entre estas destaca-se a workload 06, que partilha com as duas seguintes (workloads 10 e 11) a distribuição Zipfian de acessos e constitui por isso a referência mais próxima.

#figure(
  tool-bars("impact-baseline.csv", ylabel: [Milhares de @iops],
            xlabel: [Workload]),
  caption: [Débito de operações do Prismo com conteúdo aleatório em cada sistema de ficheiros]
) <impacto-baseline>

A @impacto-baseline evidencia desde logo uma diferença estrutural entre os dois sistemas, com o Btrfs a entregar entre três e quatro vezes o débito do @zfs em todas as workloads. Esta distância decorre do custo que o @zfs impõe a cada operação, resultante da combinação entre a semântica copy-on-write, a verificação de checksums e o recordsize de 4 KiB adotado, que multiplica o número de registos a gerir face ao valor por omissão.

Merece destaque o facto de a workload 04, composta exclusivamente por leituras, apresentar o débito mais baixo em ambos os sistemas, enquanto a workload 05, com metade das operações a serem escritas, mais do que duplica esse valor no Btrfs. Uma explicação plausível reside no encaminhamento das escritas através da cache, conforme exposto na metodologia, retornando estas sem aguardar o dispositivo.

Por outro lado, a workload 06 fica ligeiramente abaixo da workload 05 nos dois sistemas, apesar de a distribuição Zipfian concentrar os acessos numa fração reduzida do dispositivo, resultado que contraria a expectativa de a localidade favorecer o desempenho e que será retomado na secção dedicada aos efeitos de cache.

Convém realçar que a dispersão registada nestas workloads é bastante superior à observada sobre o dispositivo em acesso direto, situando-se entre 10% e 18% do valor médio, o que decorre de os sistemas de ficheiros introduzirem trabalho assíncrono que não acompanha o ritmo dos pedidos, oscilando por isso o débito instantâneo conforme essas tarefas são despachadas.

==== Compressão

A workload 10 escreve conteúdo com compressibilidade controlada segundo três níveis de redução, cenário que o @fio e o Vdbench apenas conseguem aproximar através de uma taxa global aplicada a todos os blocos, sendo o débito de operações obtido por cada ferramenta em cada sistema de ficheiros apresentado na @impacto-compressao.

#figure(
  tool-bars("impact-compression.csv", ylabel: [Milhares de @iops],
            xlabel: [Sistema de ficheiros]),
  caption: [Débito de operações na workload 10 em cada sistema de ficheiros]
) <impacto-compressao>

Confrontando a @impacto-compressao com a linha de base, verifica-se que o Prismo alcança mais 26% de débito no Btrfs e mais 32% no @zfs do que na workload 06, que partilha com esta a distribuição Zipfian de acessos. O mecanismo que sustenta este ganho parece claro, o conteúdo compressível permite ao sistema de ficheiros armazenar fisicamente menos dados do que aqueles que lhe são entregues, reduzindo na mesma medida o trabalho pedido ao dispositivo e libertando-o para aceitar mais operações no mesmo intervalo.

Convém realçar, no entanto, que esta comparação não isola o efeito do conteúdo, visto a workload 10 apresentar também uma proporção superior de escritas, as quais, conforme observado na própria linha de base, tendem a elevar o débito por retornarem sem aguardar o dispositivo. Assim sendo, ambas as diferenças atuam no mesmo sentido e o ganho não é integralmente imputável à compressibilidade.

É o confronto entre ferramentas que procura eliminar esta ambiguidade, dado que o Prismo e o @fio executam exatamente a mesma workload, com idêntico padrão de acessos e idêntica proporção de escritas, diferindo unicamente no conteúdo submetido. No @zfs o Prismo supera o @fio em cerca de 31%, diferença que atinge o dobro da dispersão registada e é por isso a única desta secção que o critério de leitura adotado permite declarar.

No entanto, merece particular destaque o facto de as duas configurações terem sido deliberadamente igualadas na compressibilidade média, pois a distribuição do Prismo, com metade dos blocos incompressíveis, 30% a reduzir metade e 20% a reduzir três quartos, produz exatamente os mesmos 30% que o @fio aplica de forma uniforme a todos os blocos.

Deste modo, a diferença observada não é imputável a uma carga globalmente mais compressível, mas ao modo como essa compressibilidade se distribui pelos blocos. Por outras palavras, o sistema de armazenamento responde à forma da distribuição e não apenas ao seu valor médio, propriedade que uma taxa única é por construção incapaz de exprimir.

No Btrfs a relação aparenta inverter-se, ficando o Prismo cerca de 16% abaixo do @fio, diferença que não deve porém ser interpretada como uma inversão efetiva, dado que a dispersão das medições ronda os 13% e os intervalos das duas ferramentas se sobrepõem numa extensão considerável, obrigando assim o critério estabelecido na secção anterior a tratá-las como equivalentes.

Convém realçar que a elevada dispersão do Btrfs decorre da sua própria arquitetura, dado que a compressão opera sobre extents de dimensão superior ao bloco de 4 KiB submetido, agrupando num mesmo extent blocos de compressibilidade distinta. Deste modo, a redução alcançada depende de quais os blocos que ficam agrupados, variando ao longo da execução de uma forma que o @zfs, ao comprimir cada record isoladamente, não apresenta.

Determinar se existe de facto uma diferença no Btrfs exigiria a medição do espaço ocupado em disco, única grandeza capaz de revelar quanto foi efetivamente reduzido em cada caso, e cuja ausência constitui a principal limitação desta subsecção @btrfs_docs.

==== Deduplicação

A workload 11 acrescenta à compressibilidade uma distribuição de duplicados repartida por três grupos, exercitando deste modo as duas otimizações em conjunto, sendo de recordar que a deduplicação opera de forma distinta nos dois sistemas de ficheiros, inline no @zfs e diferida no Btrfs, o que condiciona o momento em que os seus efeitos se tornam observáveis.

#figure(
  tool-bars("impact-dedup.csv", ylabel: [Milhares de @iops],
            xlabel: [Sistema de ficheiros]),
  caption: [Débito de operações na workload 11 em cada sistema de ficheiros]
) <impacto-dedup>

A @impacto-dedup reproduz de forma quase exata o comportamento da workload anterior, mantendo-se as diferenças entre ambas abaixo de 2% nos dois sistemas, valor muito inferior à dispersão registada, pelo que a introdução de duplicados não produziu qualquer efeito mensurável no débito.

Este resultado admite duas leituras que os dados disponíveis não permitem separar, visto tanto poder significar que a deduplicação não chegou a ser acionada, como que foi acionada sem que daí resultasse ganho de desempenho.

No Btrfs a primeira hipótese é a mais provável, dado que o bees opera em segundo plano e a janela de medição termina antes de este percorrer os dados escritos, ao contrário da compressão, aplicada no caminho crítico.

Já no @zfs, onde a deduplicação atua no caminho crítico e a propriedade `direct` foi desativada precisamente para a manter operacional, a ausência de efeito admite duas explicações distintas. A primeira decorre da própria configuração das workloads, visto a workload 11 apresentar uma compressibilidade média de 22% contra os 30% da workload 10, pelo que o ganho trazido pelos duplicados pode estar a ser anulado por uma redução por compressão inferior em oito pontos percentuais.

A segunda explicação aponta para o recurso que limita a execução, visto o @zfs consumir cinco vezes mais processador que o Btrfs e ocupar perto de sessenta gigabytes de memória, conforme se apresenta na @impacto-recursos. Neste caso, como o custo dominante reside no anfitrião e não no disco, evitar escritas físicas não aumenta o débito, que permanece indiferente à presença de duplicados.

Convém realçar que a primeira explicação constitui igualmente uma limitação do desenho experimental, dado que as duas workloads não diferem apenas na presença de duplicados, o que impede o isolamento do contributo da deduplicação.

==== Custo Computacional das Otimizações

A redução do volume escrito não é gratuita, dado que a compressão e a deduplicação consomem processador e memória em troca das operações de @io poupadas, custo que a @impacto-recursos apresenta para a workload 11, onde ambas as otimizações se encontram ativas.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("impact-cpu.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Sistema de ficheiros], width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("impact-ram.csv", ylabel: [Memória utilizada (GiB)],
              xlabel: [Sistema de ficheiros], width: 6.0cm, height: 4.4cm),
  ),
  caption: [Consumo de recursos na workload 11 em cada sistema de ficheiros]
) <impacto-recursos>

O contraste apresentado na @impacto-recursos é acentuado, dado que o @zfs consome cerca de cinco vezes mais processador do que o Btrfs e ocupa perto de sessenta gigabytes de memória contra pouco mais de dez, custo que reflete a natureza inline das suas otimizações e o dimensionamento do ARC.

Particularmente esclarecedora é a comparação da memória entre ferramentas no @zfs, onde o Prismo ocupa cerca de oito gigabytes menos do que o @fio apesar de submeter exatamente o mesmo volume de dados lógicos. Uma vez que o ARC retém os blocos no estado em que são armazenados, ou seja já comprimidos, esta diferença só se explica se o conteúdo do Prismo estiver a ser efetivamente reduzido em maior grau.

No Btrfs a leitura mais informativa reside igualmente no processador, onde o @fio consome praticamente o dobro do Prismo para um débito que, conforme estabelecido, não é distinguível do ruído da medição. Esta assimetria é coerente com a forma das duas distribuições, visto metade dos blocos do Prismo serem incompressíveis e portanto descartados precocemente pelo algoritmo, enquanto os do @fio, uniformemente compressíveis a 30%, obrigam ao trabalho completo em cada bloco @btrfs_docs.

Deste modo, o custo de comprimir depende não apenas da quantidade de dados redutíveis mas do modo como essa redutibilidade se distribui, o que reforça a conclusão avançada na subsecção da compressão sobre a insuficiência de uma taxa única para caracterizar o conteúdo.

Em suma, um benchmark que ignore as propriedades do conteúdo subestima em cerca de um terço o débito que o @zfs entrega perante dados realistas, resultado que demonstra não ser a fidelidade do conteúdo um requisito acessório, mas antes condição para que a avaliação seja representativa. Estabelecido o efeito das propriedades dos dados, importa agora averiguar em que medida a interface de @io condiciona os valores medidos @koller2010 @meyer2012.

=== Comparação de Interfaces de I/O <io-interfaces>

O suporte a múltiplas interfaces de @io constitui uma das funcionalidades distintivas do Prismo, daí que faça todo o sentido avaliar o impacto da escolha da interface no desempenho observado. Embora o @fio suporte as mesmas interfaces, o acesso ao @spdk é conseguido através de um plugin cuja utilização é deveras complexa, não sendo por isso suportado nativamente. Por outro lado, o Vdbench opera exclusivamente sobre POSIX síncrono. Deste modo, a comparação entre as três ferramentas é possível para POSIX, enquanto para io_uring, libaio e @spdk a comparação é restrita ao Prismo e ao @fio.

Todas as execuções recorrem ao dispositivo acedido diretamente e partilham a parametrização descrita adiante, o que permite separar dois efeitos distintos. As diferenças entre interfaces medidas com a mesma ferramenta traduzem o custo do próprio mecanismo de submissão, ao passo que as diferenças entre ferramentas dentro da mesma interface só podem ser imputadas ao modo como cada uma a utiliza.

==== Configuração das Interfaces

A interface POSIX opera de forma síncrona através das chamadas `pread` e `pwrite`, mantendo por isso um único pedido em curso de cada vez, condição que a torna a referência natural contra a qual as restantes são confrontadas, afinal qualquer ganho observado traduz o benefício de sobrepor operações.

O libaio e o io_uring recebem em ambas as ferramentas uma profundidade de fila de 128 pedidos, sendo este o valor que fixa quantas operações podem aguardar conclusão ao mesmo tempo e portanto o parâmetro determinante deste confronto. No io_uring é adicionalmente ativado o polling do kernel, ficando a thread responsável fixada no primeiro core do processador @uring_kernel.

Já o @spdk dispensa por completo a intervenção do kernel, acedendo ao dispositivo a partir do espaço de utilizador através da abstração de @bdev. Além disso, o Prismo é configurado com uma máscara de quatro reactors e oito threads lógicas, enquanto o @fio recorre ao plugin `spdk_bdev` respeitando a profundidade de fila das restantes interfaces assíncronas @spdk_docs.

Convém realçar que apenas o libaio e o io_uring admitem uma comparação rigorosa entre ferramentas, dado que o modelo de reactors do Prismo não encontra correspondência direta nos parâmetros do plugin, pelo que os valores do @spdk devem ser lidos com a devida reserva.

==== Workloads Sequenciais

As workloads 01 e 02 percorrem o dispositivo de forma sequencial com blocos de 4 KiB, a primeira em escrita e a segunda em leitura, constituindo por isso o cenário mais favorável à submissão assíncrona, uma vez que o padrão de acessos é previsível e permite ao dispositivo antecipar os pedidos seguintes.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("interfaces-wl01.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("interfaces-wl02.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm),
  ),
  caption: [Débito de operações nas workloads 01 e 02 em cada interface de @io]
) <interfaces-seq>

A @interfaces-seq revela um ganho considerável das interfaces assíncronas sobre o POSIX, que no Prismo ascende a cerca de cinco vezes na escrita e quatro na leitura, resultado esperado visto o POSIX síncrono bloquear a thread em cada operação e permitir por isso um único pedido em curso, enquanto as restantes mantêm dezenas em execução ao mesmo tempo.

Convém realçar que o Prismo iguala ou supera o @fio em todas as interfaces nestas duas workloads, com vantagem particularmente nítida no libaio, onde alcança perto de 20% acima. Assim sendo, a arquitetura produtor-consumidor mostra-se adequada a padrões previsíveis, nos quais o produtor consegue antecipar a preparação dos pedidos enquanto o consumidor aguarda as conclusões.

O @spdk apresenta, no entanto, um comportamento que contraria a expectativa, dado situar-se entre 10% e 14% abaixo do io_uring e do libaio no Prismo, quando seria de esperar que a eliminação do kernel do caminho crítico produzisse o débito mais elevado de todos.

Convém realçar que o mesmo padrão se observa no @fio, cujo @spdk fica igualmente abaixo das interfaces do kernel, afastando-se assim a hipótese de a causa residir na implementação de qualquer das ferramentas e apontando antes para o modo como esta interface lida com as características da workload.

Porém, no caso do Prismo, a explicação mais provável reside na configuração de reactors adotada, que reserva quatro núcleos e oito threads lógicas independentemente do perfil da workload, repartição que não é necessariamente a mais favorável a um padrão sequencial servido por um único produtor. Assim sendo, importa admitir que este resultado não fica cabalmente explicado pelos dados recolhidos.

==== Saturação da Largura de Banda

As workloads anteriores mantiveram o bloco em 4 KiB, dimensão que obriga a submeter um elevado número de pedidos para movimentar um volume modesto de dados e que coloca por isso o esforço do lado da submissão. A workload 03 altera exclusivamente este parâmetro, elevando-o para 64 KiB, reduzindo em 16 vezes o número de operações necessárias para transferir a mesma quantidade de dados.

Deste modo, o dispositivo deixa de ser solicitado pela cadência dos pedidos e passa a sê-lo pelo volume que deles resulta, permitindo assim averiguar se a vantagem das interfaces assíncronas se mantém quando o estrangulamento muda de natureza.

#figure(
  tool-bars("interfaces-wl03.csv", ylabel: [Milhares de @iops],
            xlabel: [Interface], width: 8.5cm, height: 4.6cm),
  caption: [Débito de operações na workload 03 em cada interface de @io]
) <interfaces-bloco>

Conforme se observa na @interfaces-bloco, as quatro interfaces produzem resultados indistinguíveis entre si e entre ferramentas, situando-se todas próximo das 28 mil operações por segundo. Uma vez que este valor corresponde a cerca de 1.8 GiB por segundo, conclui-se que o fator limitante deixou de ser a submissão de pedidos e passou a ser a largura de banda do próprio dispositivo.

Merece destaque o facto de esta convergência abranger igualmente o @spdk, cujo acesso em espaço de utilizador não lhe confere qualquer vantagem neste cenário, resultado que reforça a ideia de que a limitação se encontra no próprio dispositivo, e não no caminho de acesso utilizado.

Por fim, importa reter que a escolha da interface apenas é determinante enquanto o estrangulamento reside no número de operações submetidas, pois a partir do momento em que o volume de dados satura o dispositivo qualquer interface atinge o mesmo limite.

==== Workloads Aleatórias e Mistas

As workloads 04 e 05 substituem o acesso sequencial por acessos aleatórios distribuídos por toda a extensão do dispositivo, o que impede qualquer antecipação por parte deste e obriga cada pedido a suportar integralmente a latência do acesso. Nestas condições, o débito deixa de depender predominantemente da rapidez com que os dados são transferidos e passa a ser limitado pela capacidade de manter pedidos em curso, pelo que a profundidade da fila assume um papel determinante.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("interfaces-wl04.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("interfaces-wl05.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm),
  ),
  caption: [Débito de operações nas workloads 04 e 05 em cada interface de @io]
) <interfaces-rand>

O ganho das interfaces assíncronas é aqui muito superior ao observado nas workloads sequenciais, atingindo no Prismo cerca de catorze vezes o débito do POSIX na leitura aleatória, amplificação que se explica pela latência de cada acesso, integralmente exposta à aplicação numa interface síncrona e sobreposta entre pedidos concorrentes nas restantes.

O confronto entre ferramentas revela, porém, uma diferença assinalável, com o @fio a alcançar aproximadamente o dobro do Prismo na workload 04 e cerca de 60% acima na workload 05, discrepância que constitui a maior registada em todo o capítulo e que não decorre da configuração, idêntica em ambas as ferramentas.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("interfaces-lat-wl04.csv", ylabel: [Latência média (µs)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("interfaces-lat-wl05.csv", ylabel: [Latência média (µs)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm),
  ),
  caption: [Latência média nas workloads 04 e 05 em cada interface de @io]
) <interfaces-lat>

A @interfaces-lat esclarece a origem desta diferença, dado que a latência reportada pelo Prismo nas interfaces assíncronas duplica a do @fio, ao passo que em POSIX ambas coincidem ao décimo de microssegundo. Uma vez que o débito resulta do quociente entre os pedidos em curso e a latência de cada um, e sendo a profundidade configurada idêntica, o dobro da latência traduz-se necessariamente em metade do débito.

Convém realçar que a coincidência em POSIX é significativa, visto as duas ferramentas produzirem resultados equivalentes enquanto não existem pedidos pendentes, divergindo apenas quando estes surgem. Esta diferença é, portanto, atribuível à gestão dos pedidos pendentes, e não à instrumentação.

Merece particular destaque o facto de o Prismo obter praticamente o mesmo valor no io_uring e no libaio, duas interfaces que partilham apenas o carácter assíncrono e diferem por completo na implementação, o que localiza o estrangulamento num ponto anterior à interface e comum a ambas.

Três candidatos podem desde logo ser excluídos, dado que a @componentes demonstra sustentarem os geradores um débito duas ordens de grandeza superior ao exigido por esta workload, sendo além disso a profundidade configurada respeitada em ambas as ferramentas.

Também o canal entre produtor e consumidor fica afastado, visto medições realizadas sobre este isoladamente atingirem 10.2 de milhões operações por segundo na variante não bloqueante e 9.99 milhões na bloqueante, valores que excedem em mais de cinquenta vezes o débito aqui observado e que tornam a escolha entre as duas variantes irrelevante para o resultado.

Resta assim o ciclo do consumidor, que alterna entre submeter pedidos e recolher conclusões numa única thread, e onde o tempo despendido a recolher atrasa a reposição da fila. Convém realçar, no entanto, que esta explicação permanece por confirmar, pois a latência reportada não permite distinguir o tempo passado no dispositivo daquele que decorre dentro do próprio Prismo.

==== Concorrência

A workload 09 replica o padrão aleatório misto da workload 05, distribuindo-o por três jobs independentes, cada um com a sua fila e respetiva thread submissora, o que permite averiguar se cada interface acompanha o aumento do número de produtores ou se algum recurso partilhado impede essa escalabilidade.

#figure(
  tool-bars("interfaces-wl09.csv", ylabel: [Milhares de @iops],
            xlabel: [Interface], width: 8.5cm, height: 4.6cm),
  caption: [Débito de operações na workload 09 em cada interface de @io]
) <interfaces-conc>

A @interfaces-conc mostra que o libaio do Prismo escala com o número de jobs, passando de cerca de 215 mil operações por segundo com um único job para 326 mil com três, valor que iguala o do @fio e constitui o único cenário assíncrono em que as duas ferramentas convergem.

O io_uring não acompanha esta evolução em qualquer das ferramentas, mantendo-se ambas próximas do valor obtido com um único job, com a diferença de o @fio partir já das 344 mil operações por segundo enquanto o Prismo estagna nas 215 mil.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("interfaces-cpu-1job.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false),
    tool-bars("interfaces-cpu-3jobs.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm),
  ),
  caption: [Utilização de @cpu com um job e com três jobs em cada interface de @io]
) <interfaces-recursos>

A @interfaces-recursos, que confronta a workload 05 com a workload 09, oferece a explicação mais provável, dado que o io_uring do Prismo eleva o consumo de processador em mais de metade ao passar de um para três jobs sem qualquer ganho de débito, enquanto o libaio o aumenta apenas 12% e entrega em contrapartida mais 52%.

Esta penalização da performance decorre das threads de polling do kernel, que giram em espera ativa e que a configuração adotada fixa todas no mesmo core do processador, conforme descrito anteriormente, competindo portanto três instâncias por um único núcleo sem que o tempo assim despendido se traduza em pedidos submetidos.

O @spdk exibe neste cenário a degradação mais acentuada de todo o capítulo, caindo de 238 mil operações por segundo com um único job para 87 mil com três, ou seja pouco mais de um terço, enquanto o @fio mantém nesta interface o mesmo débito das restantes.

A origem desta degradação é, no entanto, a mesma que penaliza o io_uring, pois a máscara de reactors encontra-se definida ao nível da interface e não do job, sendo por isso replicada tal e qual pelas três instâncias.

Deste modo, os quatro núcleos que a máscara reserva passam a ser disputados pelos três jobs em simultâneo, sem que qualquer deles disponha de recursos exclusivos, o que explica a subida do consumo de processador sem retorno em débito.

Assim sendo, as duas interfaces que fixam afinidade ao processador exibem o mesmo comportamento, enquanto o libaio, por não fixar nenhuma, escala sem dificuldade. Convém realçar que a limitação não reside nas interfaces mas no modelo de configuração adotado, que exprime a afinidade uma única vez e não a reparte pelos jobs existentes.

Em suma, a interface de @io condiciona fortemente o débito medido, com ganhos que vão de nulos, quando o dispositivo satura, até catorze vezes nos acessos aleatórios, disparidade que fundamenta a necessidade de um benchmark capaz de as exercitar a todas. Convém realçar, contudo, que nenhuma interface se revela superior em todos os cenários, pois o @spdk vence nos acessos aleatórios com um único job mas fica atrás nas workloads sequenciais e degrada-se perante concorrência, sendo por isso desaconselhadas recomendações absolutas. Estabelecido este efeito, importa agora verificar se as workloads derivadas de traces reproduzem fielmente as propriedades dos dados originais.

=== Workloads Baseadas em Traces <trace-eval>

De todas as funcionalidades do Prismo, a replicação de traces é aquela que mais o distingue das ferramentas de referência, uma vez que nenhuma delas consegue reproduzir em conjunto os padrões de acesso, o mix de operações e as propriedades do conteúdo registados numa execução real.

Replicar o trace não é, porém, suficiente, dado que os registos disponíveis cobrem uma fração ínfima do tempo necessário para um dispositivo moderno atingir o regime estacionário. Esta secção averigua se a reprodução é fiel e em que medida as estratégias de extensão preservam as características originais.

==== Traces Utilizados

Os traces utilizados provêm do repositório do @fiu e resultam da instrumentação de três servidores em produção, apresentando a estrutura já descrita na @chapter2. Cada registo inclui uma assinatura do conteúdo, componente indispensável ao presente trabalho, pois é através dela que se reconstitui a distribuição de duplicados sem aceder aos dados originais @koller2010.

#figure(
  doc_table(
    columns: (1fr, 0.7fr, 0.6fr, 0.6fr, 0.7fr, 0.7fr),
    align: (x, y) => if x == 0 or y == 0 { horizon + left } else { horizon + right },
    header: ([Trace], [Registos], [Volume], [Escritas], [Duplicados], [Workloads]),
    [homes], [2.0 M], [7.7 GiB], [92%], [36.5%], [12 e 14],
    [webmail], [0.7 M], [2.6 GiB], [96%], [37.7%], [15],
    [cheetah], [22.7 M], [86.6 GiB], [52%], [22.3%], [13],
  ),
  caption: [Traces utilizados, com as proporções medidas nos primeiros 100 mil registos]
) <traces-perfil>

O primeiro aspeto a reter da @traces-perfil é a dimensão destes ficheiros, dado que mesmo o cheetah, de longe o mais extenso, cobre apenas 11.5% dos 752.91 GiB que uma workload da campanha movimenta, ficando os restantes dois abaixo de 1.1%. Sem extensão, nenhum deles conduziria o dispositivo a um regime estacionário.

Merece destaque a distância entre servidores, com a proporção de escritas a variar dos 96% do webmail aos 52% do cheetah, único dedicado a servir páginas web e por isso o único onde as leituras pesam quase tanto quanto as escritas.

Convém realçar que qualquer destas percentagens é configurável no @fio e no Vdbench, dado tratar-se de rácios globais. A limitação não reside portanto no valor em si, mas no facto de cada percentagem resumir a execução inteira a um único número, ocultando a forma como a grandeza evolui entre o primeiro e o último pedido @fio_docs @vdbench.

==== Fidelidade do Replay

Uma workload baseada em traces atravessa dois momentos distintos, pois enquanto o ficheiro dispõe de registos por consumir cada pedido corresponde ao que foi observado no servidor original, ao passo que, esgotado o ficheiro, é a extensão que assume a geração. A fidelidade exigida a cada um difere por conseguinte, tratando-se no primeiro de reprodução literal e no segundo de semelhança estatística.

As figuras seguintes acompanham a execução do trace homes com as três estratégias, assinalando uma linha vertical a transição ao fim dos primeiros 100 mil registos, aos quais a experiência foi limitada apesar de o ficheiro disponibilizar mais de dois milhões. Sendo o material anterior idêntico nas três, as séries sobrepõem-se necessariamente, e qualquer divergência que aí se observasse denunciaria distorção da ferramenta.

O eixo horizontal conta os pedidos submetidos, em milhares, sendo recolhida uma medição a cada mil. O offset constitui uma propriedade do pedido individual e apresenta-se por isso tal como foi submetido, ao passo que as duas restantes grandezas são proporções, as quais apenas se definem sobre um conjunto de pedidos.

Daí que estas últimas sejam calculadas sobre os dois mil pedidos centrados em cada ponto, janela suficientemente estreita para revelar as oscilações e suficientemente larga para que a proporção não varie entre extremos por efeito de meia dúzia de pedidos.

Convém realçar que as três séries partilham a primeira metade por construção, pelo que a leitura destas figuras deve concentrar-se no que sucede depois da linha vertical, onde cada estratégia passa a responder pela totalidade dos registos submetidos.

===== Padrões de Acesso

A primeira dimensão a examinar é o offset de cada pedido, do qual depende a localidade dos acessos e, por consequência, o partido que o dispositivo consegue tirar de leituras antecipadas e de escritas contíguas.

#figure(
  trace-lines("traces-offsets.csv", ylabel: [Offset acedido (GiB)]),
  caption: [Evolução dos acessos ao longo da execução do trace homes]
) <traces-offsets>

A @traces-offsets revela um percurso irregular, com quase metade dos pontos a recair na vizinhança dos 328 GiB enquanto os restantes se espalham entre o primeiro gigabyte e os 431 GiB, alternância entre concentração e dispersão que as distribuições convencionais dificilmente produzem.

Embora as extensões por repetição e por amostragem devolvam nuvens semelhantes à original, tal semelhança não deve ser tomada por equivalência. A repetição submete os offsets pela ordem observada, nada acrescentando ao segundo ciclo, enquanto a amostragem os extrai do reservatório e os sorteia de novo, conservando o conjunto de endereços mas não a ordem por que foram visitados.

A consequência é relevante, dado que blocos acedidos pelo servidor em instantes próximos passam a surgir dispersos por toda a execução, sendo precisamente essa proximidade que as caches exploram intensamente @paulo2014.

Já a extensão por regressão rompe com ambas, desenhando uma única reta que parte dos 357 GiB e recua 775.8 KiB a cada pedido, visto o offset ser extrapolado a partir do último valor do trace e do passo médio entre registos. Sendo esse passo negativo, a extensão percorre o dispositivo em sentido inverso, substituindo o padrão irregular do servidor por um varrimento sequencial.

Assim sendo, das três estratégias apenas a repetição preserva a localidade original, sendo de admitir que as restantes produzam, na segunda metade da execução, um padrão de acessos cujo efeito no dispositivo pouco tem em comum com o do servidor instrumentado.

===== Mix de Operações

A segunda dimensão respeita ao tipo de cada pedido, cuja proporção determina o caminho percorrido dentro do sistema de armazenamento. Uma leitura obriga a localizar o bloco e a trazê-lo do dispositivo sempre que este não se encontre em cache, ao passo que uma escrita atravessa a compressão e a deduplicação antes de ser confirmada, sendo o dado efetivamente gravado mais tarde.

#figure(
  trace-lines("traces-operations.csv", ylabel: [Escritas na janela (%)]),
  caption: [Evolução do mix de operações ao longo da execução do trace homes]
) <traces-operacoes>

O mix de operações é a dimensão que melhor sobrevive à transição, oscilando na @traces-operacoes entre os 76% e os 100% de escritas durante o replay, oscilação que a extensão por repetição devolve intacta enquanto a amostragem a achata numa linha constante nos 91.5%. Este valor coincide com a média do trace, do que se conclui reter a alias table apenas a frequência com que cada tipo de operação ocorre, tomada isoladamente e sem memória da ordem por que os pedidos se sucediam.

O comportamento da extensão por regressão exige atenção ao modo como a operação é representada, dado que o trace a codifica através do valor numérico do respetivo tipo, correspondendo o zero à leitura e o um à escrita.

Ora o modelo linear devolve um número real que é depois arredondado e limitado a esse domínio, e sendo o trace homes dominado por escritas o valor previsto parte de 1.20 e desce até 0.95 ao longo dos 100 mil registos sintéticos, intervalo em que o arredondamento conduz invariavelmente ao valor um.

A série fixa-se portanto nos 100% e a workload deixa de emitir um único pedido de leitura, ficando por exercitar metade do efeito que o conteúdo duplicado produz, dado que a deduplicação tanto evita escritas de blocos já presentes como permite satisfazer acessos a partir de conteúdo que a cache retém @koller2010.

===== Duplicados de Conteúdo

Resta a dimensão que motiva o recurso a estes traces, ou seja, a repetição de conteúdo. Ao contrário das duas anteriores, esta não se lê no pedido em si mas na assinatura que o acompanha, sendo a distribuição dessas repetições ao longo do tempo, e não apenas a sua quantidade total, que determina aquilo que a deduplicação consegue eliminar.

#figure(
  trace-lines("traces-signatures.csv", ylabel: [Duplicados na janela (%)]),
  caption: [Evolução das assinaturas de conteúdo ao longo da execução do trace homes]
) <traces-assinaturas>

A @traces-assinaturas apresenta a percentagem de blocos repetidos a variar entre os 21% e os 46% ao longo do replay, do que se depreende distribuírem-se os duplicados de forma desigual no tempo, alternando períodos em que o mesmo conteúdo é reescrito sucessivas vezes com outros em que quase todos os blocos são distintos.

Uma taxa global de 36.5%, como a que o @fio e o Vdbench admitem, descreve a média destes períodos mas não a alternância entre eles, sendo esta que determina se um índice parcial de deduplicação ainda retém o duplicado no momento em que a cópia é submetida @paulo2014.

A extensão por repetição volta a submeter os identificadores de bloco pela mesma ordem, pelo que a curva da segunda metade reproduz exatamente a da primeira. Importa realçar, no entanto, que a medição incide sobre a janela e não sobre a execução completa, dado que a totalidade do conteúdo do segundo ciclo já se encontra em disco e é por isso integralmente duplicado.

Por outro lado, a extensão por amostragem produz um resultado aparentemente contraditório, visto a proporção medida na janela descer para 9.9%, contra os 31% do replay, enquanto a proporção calculada sobre a totalidade dos registos sintéticos sobe para 54.7%, acima dos 36.5% do próprio trace.

A explicação reside na dimensão do reservatório, que retém cerca de 63 mil identificadores distintos dos quais a extensão sorteia 100 mil de forma independente, pelo que os mais frequentes voltam a sair repetidamente ao longo da execução e elevam a contagem global, ao passo que duas ocorrências do mesmo identificador ficam em média muito afastadas entre si e raramente caem na mesma janela.

Deste modo, a amostragem preserva a quantidade de duplicados mas destrói a sua concentração temporal, e é esta última que condiciona o proveito retirado pelos mecanismos de deduplicação.

Por fim, a extensão por regressão anula os duplicados por completo, dado que o identificador de bloco é previsto por um modelo linear no offset, o qual progride de forma estritamente monótona, do que resulta uma sequência de identificadores igualmente monótona onde valor algum se repete.

Um sistema de armazenamento avaliado nestas condições suporta o custo de consultar e manter a tabela de deduplicação sem jamais registar uma eliminação, sendo por isso medido no seu pior caso.

===== Comparação entre Estratégias

Confrontando com o previsto na @chapter3, as extensões por repetição e por amostragem comportam-se conforme antecipado, conservando a repetição todas as correlações à custa de uma periodicidade estrita, enquanto a amostragem retém apenas as distribuições marginais de cada dimensão.

Já a extensão por regressão não confirma a expectativa de capturar as dependências entre dimensões, isto porque o identificador de bloco resulta de uma função de hash sem relação linear com o offset, acabando a estratégia mais sofisticada por ser a menos variável das três.

Daí que a escolha da estratégia deva depender da propriedade que se pretende exercitar, sendo a repetição preferível quando importa preservar a localidade e o conteúdo, e a amostragem quando se procura variabilidade sem compromisso com a ordem original.

==== Desempenho das Workloads Baseadas em Traces

Conhecido o grau de fidelidade alcançado, importa perceber que comportamento estas cargas produzem no sistema de armazenamento, confrontando as workloads que extraem do trace as três dimensões com aquelas que dele retiram apenas uma.

As workloads 14 e 15 assentam por inteiro no trace, ao passo que a 12 e a 13 conservam somente uma dimensão real e geram sinteticamente as restantes, extraindo a primeira os acessos do homes sobre operações sintéticas e a segunda o mix de operações do cheetah sobre uma distribuição Zipfian.

Os valores da @traces-iops resultam de execuções sobre o @zfs através da interface POSIX, pelo que devem ser confrontados com os da @data-properties e nunca com os da @io-interfaces. Além disso, apresentam-se unicamente os valores do Prismo, dado que nenhuma das ferramentas de referência replica traces desta natureza @fio_docs @vdbench.

#figure(
  tool-bars("traces-iops.csv", ylabel: [Milhares de @iops],
            xlabel: [Workload], width: 8.5cm, height: 4.6cm, legend: false),
  caption: [Débito de operações do Prismo nas workloads baseadas em traces]
) <traces-iops>

As quatro workloads distribuem-se entre as 3485 e as 4169 operações por segundo, sendo a maior diferença entre duas delas inferior ao desvio padrão da workload 12, pelo que o critério estabelecido na @validation obriga a tratá-las como equivalentes.

As workloads híbridas ladeiam as restantes, ficando a 12 abaixo de ambas e a 13 acima, distribuição que afasta qualquer efeito sistemático decorrente da substituição de dimensões reais por sintéticas.

Além disso, a workload 12 é a mais dispersa e a única dominada por leituras, aproximando-se por aí da workload 04, a mais lenta de toda a linha de base do @zfs, o que sugere ser a proporção de leituras, e não a proveniência dos acessos, a condicionar o débito.

Esta leitura é corroborada pelo confronto com a linha de base do @zfs apresentada na @impacto-baseline, dado que o débito da workload 05 se situa dentro do intervalo de dispersão de cada uma das quatro, ficando estas por seu turno 85% acima da workload 04, composta exclusivamente por leituras.

As workloads 14 e 15 submetem conteúdo genuinamente duplicado, ao passo que as híbridas escrevem blocos aleatórios, sem que daí resulte vantagem para as primeiras. O resultado é consistente com o observado na subsecção da deduplicação, onde a introdução de duplicados também não alterou o débito do @zfs, reforçando a leitura aí avançada de não ser o dispositivo o recurso que limita a execução nesta configuração.

Deste modo, o débito não constitui a grandeza através da qual uma workload baseada em traces se distingue de uma sintética, visto qualquer delas se situar na banda já coberta pelas secções anteriores. O que verdadeiramente as separa é a estrutura temporal do conteúdo e dos acessos, cuja influência a instrumentação adotada não permitiu isolar.

Determinar esse efeito exigiria acompanhar o espaço ocupado em disco e a taxa de acerto da tabela de deduplicação ao longo da execução, grandezas que as ferramentas utilizadas não expõem por intervalo, constituindo a sua ausência a principal limitação desta subsecção.

==== Comparação de Capacidades

Independentemente dos valores medidos, importa situar o Prismo face às ferramentas de referência quanto àquilo que cada uma consegue reproduzir a partir de um trace, comparação que a subsecção anterior tornou impossível ao nível do débito precisamente por nenhuma das outras duas oferecer mecanismo equivalente.

#figure(
  doc_table(
    columns: (2.2fr, auto, auto, auto),
    header: ([Capacidade], [Prismo], [FIO], [Vdbench]),
    [Replicação dos acessos], cell_yes, cell_partial[Limitado], cell_no,
    [Replicação das operações], cell_yes, cell_no, cell_no,
    [Replicação do conteúdo], cell_yes, cell_no, cell_no,
    [Combinação com geração sintética], cell_yes, cell_no, cell_no,
    [Extensão para lá da duração original], cell_yes, cell_no, cell_no,
  ),
  caption: [Capacidades de replicação de traces suportadas por cada ferramenta]
) <traces-capacidades>

O Prismo é a única das três ferramentas a reproduzir em conjunto os acessos, as operações e o conteúdo de um trace, visto o @fio admitir apenas a repetição de um padrão de acessos previamente descrito e o Vdbench não oferecer mecanismo equivalente @fio_docs @vdbench.

Merece destaque a combinação com geração sintética, que permite isolar o contributo de cada dimensão ao substituir as restantes por valores controlados, sem a qual não seria possível determinar se um comportamento observado decorre do padrão de acessos ou das propriedades do conteúdo.

Em suma, a replicação é fiel enquanto o ficheiro dura, no entanto nenhuma das estratégias de extensão consegue prolongá-la sem sacrificar alguma das propriedades originais, limitação que importa ter presente sempre que a execução se estenda muito para lá do material disponível. Estabelecido este eixo, importa agora averiguar de que modo a localidade dos acessos condiciona o desempenho observado.

=== Efeitos de Localidade e Cache <locality>

Em ambientes de produção, as workloads exibem frequentemente padrões de acesso com forte localidade espacial e temporal, o que ativa mecanismos internos de cache e prefetching nos dispositivos e sistemas de ficheiros. No entanto, estes comportamentos não são exercitados por workloads puramente aleatórias, como tal esta secção procura avaliar em que medida diferentes distribuições de acesso influenciam o desempenho observado.

Toda a análise que se segue incide sobre as workloads executadas no dispositivo em acesso direto, condição em que a flag `O_DIRECT` afasta a page cache e garante que o medido decorre do dispositivo. Os mecanismos aqui exercitados são por isso os internos do @nvme e não os do sistema operativo, ressalva que condiciona a leitura de tudo o que se segue.

==== Sequencial e Aleatório

A dimensão isolada nesta subsecção é a ordenação dos acessos, confrontando-se as workloads sequenciais 01 e 02 com as aleatórias 04 e 05, todas elas assentes em blocos de 4 KiB e submetidas através da interface POSIX.

#figure(
  tool-bars("locality-iops.csv", ylabel: [Milhares de @iops],
            xlabel: [Workload], width: 8.5cm, height: 4.6cm, legend: false),
  caption: [Débito de operações do Prismo em cada padrão de acesso]
) <localidade-iops>

A @localidade-iops evidencia uma disparidade considerável, dado que a workload 02 alcança 113 mil operações por segundo enquanto a workload 04, que dela difere por aceder ao dispositivo de forma aleatória, se fica pelas 13.2 mil, ou seja 8.6 vezes menos.

O mecanismo subjacente é conhecido, visto o acesso sequencial permitir ao dispositivo antecipar os blocos seguintes e servi-los a partir do buffer interno, ao passo que o acesso aleatório obriga cada pedido a suportar integralmente o custo de traduzir o endereço e de alcançar a célula correspondente.

Convém realçar que esta disparidade é integralmente imputável ao padrão de acessos, dado que o produtor apenas aciona o gerador de conteúdo quando a operação é de escrita, conforme descrito no @chapter3, e ambas as workloads se limitam a ler. A configuração de conteúdo que as distingue permanece por isso inoperante ao longo de toda a execução.

Assim sendo, a ordenação dos acessos constitui um dos fatores de maior amplitude medidos ao longo do capítulo, a par da escolha da interface de @io, estabelecendo assim a referência contra a qual os resultados da subsecção seguinte devem ser interpretados.

==== Localidade Zipfian

As workloads 05 e 06 constituem o par mais controlado de toda a campanha, dado partilharem a repartição das operações em partes iguais, o conteúdo aleatório regenerado e a condição de paragem, diferindo unicamente na distribuição que governa os offsets.

Contrariando a expectativa, a @localidade-iops mostra a workload 06 a ficar 14.3% abaixo da 05, com 19.2 mil operações por segundo contra 22.4 mil, penalização que a latência média confirma ao subir de 44.6 para 52 microssegundos.

A mesma inversão já havia sido registada na @impacto-baseline sobre o Btrfs e o @zfs, tendo ficado por explicar. Ao reproduzir-se agora sobre o dispositivo em acesso direto, o sistema de ficheiros fica desde logo afastado das causas possíveis.

A expectativa de que a localidade favoreça o desempenho provém dos suportes rotativos, nos quais a proximidade entre endereços poupa deslocação mecânica. Sendo de estado sólido o dispositivo utilizado, conforme a @hardware, essa poupança não existe, pelo que a ausência de ganho não constitui em si uma surpresa.

A medição revela porém algo mais do que a ausência de ganho, tratando-se de uma penalização consistente para a qual não foi possível apurar causa. Uma conjetura apontaria para o paralelismo interno do dispositivo, admitindo que a concentração dos acessos reduzisse a distribuição dos pedidos pelos componentes que o servem.

Tal conjetura não é, no entanto, verificável a partir das medições recolhidas, visto o mapeamento entre endereços lógicos e componentes físicos ser interno ao controlador e nunca exposto ao sistema operativo, podendo até endereços contíguos ficar alojados em componentes distintos.

Regista-se por isso o resultado sem explicação estabelecida, ficando demonstrado que a distribuição Zipfian penaliza este dispositivo de forma reprodutível face à uniforme, ao passo que o esclarecimento da causa exigiria instrumentação ao nível do controlador, indisponível no âmbito deste trabalho.

==== Estabilidade e Cauda da Latência

A penalização apurada na subsecção anterior assenta em valores médios, os quais nada dizem quanto à regularidade com que são alcançados. Importa por isso examinar a dispersão das medições e a cauda da distribuição de latências, grandezas que revelam se a distribuição de acessos afeta igualmente a previsibilidade do sistema.

#figure(
  grid(
    columns: 2, gutter: 4pt,
    tool-bars("locality-p99.csv", ylabel: [Latência p99 (µs)],
              xlabel: [Workload], width: 6.0cm, height: 4.6cm, legend: false),
    tool-bars("locality-cv.csv", ylabel: [Coeficiente de variação (%)],
              xlabel: [Workload], width: 6.0cm, height: 4.6cm, legend: false),
  ),
  caption: [Percentil 99 e dispersão do débito em cada padrão de acesso]
) <localidade-cauda>

A @localidade-cauda mostra o contraste entre padrões a acentuar-se nos percentis, dado que as workloads sequenciais registam um p99 uma ordem de grandeza abaixo do das restantes, disparidade superior à que o débito médio já denunciava.

A penalização mantém-se no confronto entre a distribuição uniforme e a Zipfian, dado o percentil 99 da workload 06 superar em 30% o da workload 05, com uma dispersão quase quatro vezes maior apesar de ambas submeterem o mesmo número de pedidos durante igual período.

A dispersão elevada não é porém exclusiva da distribuição Zipfian, visto a workload 02 apresentar valor semelhante ao da 06, apesar de operar a um nível de desempenho muito superior, bem mais próximo do limite do dispositivo.

#figure(
  workload-lines("locality-series.csv", ylabel: [Milhares de @iops]),
  caption: [Evolução do débito ao longo da execução em cada padrão de acesso]
) <localidade-series>

A @localidade-series esclarece a origem desta dispersão, ao expor sete perturbações ao longo da execução da workload 06, separadas por intervalos regulares entre 121 e 131 segundos, que as workloads 04 e 05 não apresentam.

Cada perturbação segue o mesmo perfil, com o débito a descer até cerca de 17.4 mil operações por segundo, recuperando de seguida para valores próximos das 22 mil antes de regressar ao regime habitual, assinatura compatível com uma tarefa periódica de manutenção do dispositivo. Uma explicação plausível reside no garbage collection, uma vez que a concentração de escritas numa região restrita esgota mais depressa os blocos livres dessa zona e obriga o dispositivo a recuperá-los, ao passo que a distribuição uniforme reparte esse desgaste por toda a extensão.

Em suma, a substituição da distribuição uniforme pela Zipfian altera o débito medido em 14%, a cauda da latência em 30% e a estabilidade das medições por um fator próximo de quatro, valores próprios deste dispositivo e destas workloads, que noutras condições seriam legitimamente distintos.

Independentemente dos valores concretos, fica estabelecido que a escolha da distribuição altera o resultado da avaliação, pelo que um benchmark que apenas ofereça acessos sequenciais ou uniformes mede um regime distinto daquele em que o sistema opera. Estabelecido este último eixo, importa agora reunir as conclusões dispersas ao longo do capítulo.

=== Síntese e Discussão Geral <evaluation-synthesis>

O capítulo percorreu cinco eixos de avaliação, desde a validação da própria ferramenta até aos efeitos da localidade dos acessos, importando agora confrontar os resultados entre si e apurar o que deles decorre para a avaliação de sistemas de armazenamento.

==== Síntese dos Resultados

Numa análise geral, obtém-se uma hierarquia que nenhuma secção isolada poderia estabelecer. À cabeça surge a interface de @io, cuja escolha produz diferenças de até catorze vezes na @io-interfaces, seguida da ordem pela qual os blocos são percorridos, que separa o acesso sequencial do aleatório por um fator de 8.6 na @locality.

Com uma influência bastante menor surgem a concentração dos acessos e as propriedades do conteúdo. A primeira explica os 14% que, na mesma secção, separam a distribuição Zipfian da uniforme, enquanto a segunda corresponde aos 31% apurados na @data-properties. Esta hierarquia deve, porém, ser interpretada com alguma cautela, dado que apenas este último efeito foi medido sobre sistemas de ficheiros, enquanto os restantes correspondem ao dispositivo em acesso direto.

Quanto ao conteúdo, o resultado mais consequente não reside no ganho em si, mas na sua dependência da forma da distribuição, dado que na @data-properties o Prismo e o @fio submeteram cargas com idêntica compressibilidade média e obtiveram no @zfs débitos que diferem em 31%. O sistema responde assim à forma como a redutibilidade se reparte pelos blocos e não ao seu valor agregado, propriedade que uma taxa única é incapaz de exprimir.

Já a replicação de traces confirmou-se fiel enquanto o ficheiro dispõe de registos, revelando a @trace-eval que nenhuma estratégia de extensão prolonga a execução sem sacrificar alguma propriedade, a repetição a variabilidade, a amostragem a concentração temporal dos duplicados e a regressão o conteúdo repetido na sua totalidade.

Por fim, um aspeto atravessa todo o capítulo e condiciona aquilo que dele se pode concluir, ou seja, a dispersão das medições aumenta dos 0.50% - 2.71% registados sobre o dispositivo em acesso direto para os 10% - 18% observados sobre sistemas de ficheiros. Uma diferença observável no primeiro caso exige portanto, no segundo, uma amplitude quase dez vezes superior para o ser.

==== Resultados Contrários à Expectativa

Três dos resultados obtidos contrariam aquilo que a literatura ou o próprio desenho experimental faziam prever, importando a sua enumeração conjunta tanto quanto a das confirmações, dado ser dela que decorrem as direções de trabalho futuro.

===== Duplicados sem Efeito no Débito

Esperava-se que a introdução de duplicados elevasse o débito, dado ambos os sistemas de ficheiros disporem de deduplicação e a @conteudo confirmar que o conteúdo submetido continha as cópias configuradas. A @impacto-dedup regista porém diferenças inferiores a 2% face à workload anterior, valor muito abaixo da dispersão das medições.

No Btrfs, a janela de medição terminou antes de o serviço em segundo plano percorrer os dados escritos, ao passo que no @zfs a deduplicação foi seguramente exercida, sem que daí resultasse qualquer ganho, dado que o desempenho estava limitado pelo processamento no anfitrião e não pelo dispositivo, conforme a @impacto-recursos sugere.

===== Localidade a Penalizar o Desempenho

Esperava-se que a concentração dos acessos favorecesse o desempenho, por ativar mecanismos de cache e de antecipação. A @localidade-iops mostra porém a distribuição Zipfian a penalizar o débito em 14%, agravando-se a penalização para 30% na cauda da latência conforme a @localidade-cauda.

A causa não foi apurada, a expectativa baseava-se sobretudo em comportamentos característicos de suportes rotativos, ao passo que o dispositivo utilizado é de estado sólido, pelo que o esclarecimento do fenómeno exigiria instrumentação ao nível do controlador, indisponível no âmbito deste trabalho.

===== Regressão sem Capacidade Preditiva

Esperava-se que a extensão por regressão, apresentada na @chapter3 como a mais sofisticada das três, preservasse as dependências entre dimensões. A @traces-assinaturas revela porém que esta anula por completo os duplicados, sendo na prática a menos viável das três estratégias.

A causa reside na natureza do identificador de bloco, que resulta de uma função de hash sem relação linear com o offset, pelo que o ajuste por mínimos quadrados colapsa numa proporcionalidade e a sequência gerada, sendo estritamente monótona, jamais reincide num valor já submetido.

==== Limitações

Nenhuma campanha experimental esgota o espaço de configurações possíveis, pelo que a leitura dos resultados apresentados deve ter presente um conjunto de limitações, umas decorrentes das condições em que a campanha decorreu, outras do desenho das próprias workloads, e as restantes do material disponível para replicação.

===== Âmbito Experimental

A avaliação decorreu sobre uma única máquina e um único dispositivo, correspondendo além disso cada configuração a uma execução, pelo que a dispersão reportada ao longo do capítulo traduz a estabilidade da medição e não a variabilidade entre execuções independentes.

===== Controlos Imperfeitos

A linha de base da @data-properties recorre à workload 06, que partilha com as workloads 10 e 11 a distribuição de acessos mas não o mix de operações. Um controlo estrito exigiria uma variante da workload 10 com redução nula, que das restantes diferisse apenas no conteúdo.

Do mesmo modo, as workloads 10 e 11 diferem na presença de duplicados mas também na compressibilidade média, 30% contra 22%, o que impede o isolamento do contributo da deduplicação e cuja resolução passaria por igualar essa propriedade entre ambas.

===== Grandezas Não Medidas

O espaço efetivamente ocupado em disco não foi acompanhado ao longo das execuções, grandeza que teria permitido confirmar quando e em que medida as otimizações foram acionadas, e cuja ausência limita as conclusões alcançadas sobre a deduplicação.

Também a latência reportada não distingue o tempo decorrido no dispositivo daquele que é consumido dentro da própria ferramenta, ausência que deixou por confirmar a explicação avançada na @io-interfaces para a diferença observada entre o Prismo e o @fio nas interfaces assíncronas.

===== Material Disponível

Os traces disponíveis constituem a última limitação, quer pela idade quer pela dimensão, cobrindo o mais extenso deles apenas 11.5% do volume que uma workload da campanha movimenta, o que confere à extensão sintética um peso determinante naquilo que é medido.

==== Sumário

É certo que nem todos os eixos produziram o que se esperava, a deduplicação não alterou o débito, a localidade penalizou-o em vez de o favorecer e a extensão por regressão revelou-se a menos fiel das três, ao que acresce o facto de os controlos nem sempre isolarem uma única propriedade e de o espaço ocupado em disco não ter sido acompanhado.

Apesar destas reservas, ficou estabelecido que o Prismo iguala as ferramentas consagradas em workloads genéricas, revela no @zfs um débito cerca de um terço superior ao obtido com uma taxa única de compressibilidade e é a única das três a replicar um trace nas suas várias dimensões. Daqui decorre a conclusão que sustenta o trabalho, ou seja, a de ser a fidelidade do conteúdo e dos acessos condição para que os valores medidos correspondam ao regime em que o sistema opera.

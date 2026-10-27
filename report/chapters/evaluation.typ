#import "../utils/charts.typ" : tool-bars, tool-lines, cpu-stack, component-bars, trace-lines, panels
#import "../utils/functions.typ" : question_block, validation_point_block, doc_table, cell_yes, cell_no, cell_partial

= Avaliação Experimental <chapter4>

Após a descrição da arquitetura e dos mecanismos que sustentam a geração de cargas de trabalho realistas, importa agora avaliar experimentalmente o Prismo, por um lado validando a sua correção e comparando o desempenho com as ferramentas de referência, e por outro demonstrando que a incorporação de propriedades de conteúdo nas cargas revela comportamentos dos sistemas de armazenamento que, de outro modo, permaneceriam invisíveis.

Neste sentido, são definidas cinco perguntas de investigação e quatro pontos de validação que orientam as experiências realizadas:

#question_block[
/ Q1: As propriedades intrínsecas dos dados, nomeadamente a compressibilidade e a taxa de duplicados, influenciam o desempenho dos sistemas de armazenamento, e diferentes distribuições destas propriedades resultam em comportamentos distintos por parte dos sistemas avaliados?
]

#question_block[
/ Q2: A escolha do sistema de armazenamento condiciona o benefício obtido a partir das propriedades dos dados, e qual o custo computacional associado às otimizações sensíveis ao conteúdo?
]

#question_block[
/ Q3: A escolha da interface de @io influencia significativamente o desempenho medido pelo _benchmark_, e em que medida essa influência varia consoante o tipo de carga?
]

#question_block[
/ Q4: As cargas baseadas em _traces_ reproduzem fielmente as propriedades observadas nos dados originais, e as estratégias de extensão preservam essas características?
]

#question_block[
/ Q5: Em que medida a avaliação produzida pelo Prismo difere daquela obtida através dos _benchmarks_ existentes, e que conclusões sobre os sistemas de armazenamento avaliados se tornam possíveis a partir dessa diferença?
]

#validation_point_block[
/ V1: O Prismo é capaz de gerar cargas de @io reprodutíveis que incorporam propriedades realistas de conteúdo, nomeadamente distribuições de duplicados e compressibilidade.
]

#validation_point_block[
/ V2: As medições produzidas são estáveis ao longo da execução e comparáveis entre ferramentas, garantindo que as variações observadas decorrem das propriedades das cargas e não de efeitos alheios.
]

#validation_point_block[
/ V3: O Prismo fornece as informações relevantes para a análise e avaliação do sistema de armazenamento, de modo a fundamentar as configurações dos sistemas para cargas específicas.
]

#validation_point_block[
/ V4: As conclusões alcançadas através do Prismo sobre os sistemas de armazenamento avaliados não são passíveis de obtenção com os _benchmarks_ existentes, decorrendo essa diferença do realismo do conteúdo gerado e não da instrumentação da ferramenta.
]

O capítulo inicia-se pela descrição da metodologia experimental, avançando depois para a validação da ferramenta através da demonstração de equivalência com os _benchmarks_ de referência em cargas genéricas. De seguida, são analisados cenários onde as funcionalidades exclusivas do Prismo se revelam determinantes, nomeadamente a geração de conteúdo com propriedades de deduplicação e compressão, a comparação entre interfaces de @io, a replicação e extensão de _traces_ e, por fim, a combinação destes com geração sintética, antes de sintetizar as conclusões.

== Metodologia <methodology>

A avaliação experimental assenta na execução de um conjunto alargado de cargas sobre a mesma máquina e sob condições controladas, sendo esta secção responsável por descrever o ambiente utilizado, as ferramentas comparadas, o procedimento seguido e as métricas recolhidas, de modo a que os resultados apresentados nas secções seguintes possam ser corretamente interpretados e reproduzidos.

=== Ambiente Experimental

Todas as experiências foram conduzidas numa única máquina, evitando assim que diferenças de _hardware_ ou de configuração entre execuções se reflitam nas métricas recolhidas. As especificações do sistema encontram-se descritas na @hardware, sendo de realçar a capacidade de memória disponível, pois a condição de terminação de algumas cargas é calculada com base nesta.

#figure(
  doc_table(
    columns: (1fr, 1.6fr),
    header: ([Componente], [Especificação]),
    [Sistema operativo], [Ubuntu 20.04.6 LTS (Focal Fossa)],
    [_Kernel_], [Linux 5.4.0-216-generic],
    [Arquitetura], [x86_64],
    [Processador], [2 $times$ Intel Xeon Gold 6342],
    [Núcleos], [48 físicos (24 por processador), 96 _threads_],
    [Frequência], [800 MHz base, 2.80 GHz máxima],
    [Memória], [188.23 GiB, DDR4-3200],
    [Dispositivo de armazenamento], [Dell Enterprise @nvme P5600 MU U.2, 1.46 TiB],
  ),
  caption: [Especificações da máquina utilizada nas experiências]
) <hardware>

O sistema opera sobre Ubuntu 20.04.6 LTS com _kernel_ Linux 5.4.0-216-generic, versão que condiciona as funcionalidades disponíveis nas interfaces assíncronas, em particular no io_uring, cuja implementação tem vindo a ser progressivamente otimizada desde a sua introdução @uring_kernel.

Convém realçar que todos os acessos são efetuados com a _flag_ `O_DIRECT`, o que elimina a intervenção da _page cache_ e garante que os pedidos atingem efetivamente o dispositivo, sendo esta uma condição indispensável para que as métricas reflitam o comportamento do sistema de armazenamento e não o da memória @didona2022 @ren2023. Esta garantia é integral quando o dispositivo é acedido diretamente, sem sistema de ficheiros interposto, no entanto os sistemas de ficheiros avaliados impõem-lhe restrições que serão detalhadas adiante.

=== Ferramentas Comparadas

A avaliação confronta o Prismo, na versão 1.0.0, com o @fio e o Vdbench, duas das ferramentas mais utilizadas na avaliação de sistemas de armazenamento, nas versões mais recentes de cada uma, respetivamente a 3.42 e a 5.04.07 @fio_docs @vdbench.

Estas ferramentas não partilham, no entanto, o mesmo âmbito de aplicação, pois enquanto o @fio suporta as mesmas interfaces de @io que o Prismo, apesar de o acesso ao @spdk ser conseguido através de um _plugin_ externo, o Vdbench opera exclusivamente sobre POSIX síncrono, o que restringe a comparação entre as três ferramentas a esse cenário, conforme resume a @interfaces @fio_docs @vdbench.

#figure(
  doc_table(
    columns: (3fr, 1fr, 1fr, 1fr),
    header: ([Interface], [Prismo], [FIO], [Vdbench]),
    [POSIX], cell_yes, cell_yes, cell_yes,
    [libaio], cell_yes, cell_yes, cell_no,
    [io_uring], cell_yes, cell_yes, cell_no,
    [SPDK], cell_yes, cell_partial[_Plugin_], cell_no,
  ),
  caption: [Interfaces suportadas por cada ferramenta]
) <interfaces>

As interfaces comuns a mais do que uma ferramenta foram configuradas de forma equivalente, operando o io_uring e o libaio com 128 entradas na fila de submissão, sendo no primeiro caso ativado o _polling_ do _kernel_ através das _flags_ `IORING_SETUP_SQPOLL` e `IORING_SETUP_SQ_AFF`, enquanto o @spdk recorre a uma máscara de quatro _reactors_ e oito _threads_ lógicas.

#figure(
  doc_table(
    columns: (3fr, 1fr, 1fr, 1fr),
    header: ([Funcionalidade], [Prismo], [FIO], [Vdbench]),
    [Distribuição de duplicados], cell_yes, cell_partial[Taxa global], cell_partial[Rácio global],
    [Distribuição de compressibilidade], cell_yes, cell_partial[Taxa global], cell_partial[Rácio global],
    [Reprodução de _traces_], cell_yes, cell_partial[Limitado], cell_no,
    [Extensão sintética de _traces_], cell_yes, cell_no, cell_no,
  ),
  caption: [Funcionalidades suportadas por cada ferramenta]
) <ferramentas>

Já no que toca ao conteúdo e aos _traces_, a @ferramentas evidencia que esta equivalência nem sempre é alcançável, uma vez que o @fio e o Vdbench apenas admitem uma taxa global de duplicados e de compressibilidade, a que acresce o Vdbench não dispor de barreiras de sincronização nem de geração de conteúdo constante, sendo a distribuição Zipfian aproximada através do parâmetro `hotband`, aproximações que devem ser tidas em conta na leitura dos resultados @vdbench.

=== Campanha Experimental

A campanha experimental é constituída por quinze cargas de trabalho base, cada uma isolando exatamente uma dimensão relativamente à anterior, o que permite atribuir as diferenças observadas a um único fator. Estas cargas encontram-se descritas na @workloads-base, sendo cada uma identificada por um número e por um nome curto que se repete nos eixos das figuras, e posteriormente replicadas para as quatro interfaces de @io avaliadas, do que resulta um total de sessenta configurações.

#[
#show figure: set block(breakable: true)
#figure(
  doc_table(
    columns: (auto, auto, 1.2fr, 1.6fr),
    header: ([\#], [Nome], [Dimensão isolada], [Parâmetros principais]),
    fill: (x, y) => if x == 0 { gray.lighten(60%) },
    [*01*], [`seqwrite`], [Débito sequencial de escrita], [Escrita, sequencial, conteúdo constante],
    [*02*], [`seqread`], [Débito sequencial de leitura], [Leitura, sequencial, conteúdo constante],
    [*03*], [`seqwrite64`], [Tamanho do bloco], [Escrita, sequencial, blocos de 64 KiB],
    [*04*], [`randread`], [Acesso aleatório], [Leitura, aleatório],
    [*05*], [`randrw`], [Contenção entre leituras e escritas], [50/50 leitura e escrita, aleatório],
    [*06*], [`zipfrw`], [Localidade de acesso], [50/50 leitura e escrita, Zipf(0.9)],
    [*07*], [`seqwrite90`], [Rácio assimétrico], [90/10 escrita e leitura, sequencial],
    [*08*], [`fsync`], [Custo da durabilidade], [Sequência de operações, `fsync` a cada 1024 escritas],
    [*09*], [`randrw3j`], [Paralelismo], [50/50 leitura e escrita, aleatório, 3 _jobs_],
    [*10*], [`compress`], [Compressibilidade isolada], [Zipf(0.9), três níveis de compressão],
    [*11*], [`dedup`], [Duplicados e compressibilidade], [Zipf(0.9), três níveis de duplicados e compressão],
    [*12*], [`hybaccess`], [Localidade real e operações sintéticas], [Acessos do _trace_ homes, 70/30 leitura e escrita],
    [*13*], [`hybops`], [Operações reais e acessos sintéticos], [Operações do _trace_ cheetah, Zipf(0.9)],
    [*14*], [`homes`], [Reprodução integral de um servidor de ficheiros], [_Trace_ homes, extensão por repetição],
    [*15*], [`webmail`], [Reprodução integral de um servidor de webmail], [_Trace_ webmail, extensão por amostragem e regressão],
  ),
  caption: [Cargas base da campanha experimental]
) <workloads-base>
]

A dimensão das cargas foi fixada em 752.91 GiB, valor que corresponde a 4× a memória disponível, garantindo assim que o conjunto de dados manipulado não é passível de acomodação em memória. Esta precaução seria dispensável sobre o dispositivo em acesso direto, onde a _flag_ `O_DIRECT` afasta por completo a _page cache_, no entanto nos sistemas de ficheiros essa garantia deixa de ser absoluta, conforme se detalha na @systems, daí que só um volume muito superior à memória assegure que os pedidos atingem o dispositivo.

Nas cargas mais demoradas, em particular aquelas assentes em barreiras de sincronização, alcançar este volume implicaria execuções incomportáveis, daí que nestes casos a condição de paragem seja de quinze minutos de execução, duração suficiente para que o sistema atinja um regime estacionário @traeger2008 @tarasov2011.

Cada configuração corresponde a uma única execução, sendo a estabilidade das medições aferida a partir das séries temporais recolhidas ao longo dessa execução @traeger2008 @tarasov2011. Tal opção não protege contra fenómenos episódicos do dispositivo, como a atuação do _garbage collector_ numa execução e não noutra, optando-se nesses casos por manter as amostras afetadas, visto fazerem parte do comportamento do dispositivo, de modo a que o seu efeito surja na dispersão reportada.

*Estabilização do sistema entre execuções.* Antes de cada execução é aplicado um procedimento de limpeza que garante o isolamento entre medições, evitando que o estado deixado pela execução anterior contamine os resultados da seguinte. Este procedimento inicia-se com um `sync`, que força a escrita para o disco de todas as páginas ainda pendentes em memória, assegurando deste modo que nenhuma operação da execução anterior transita para a janela de medição seguinte.

De seguida, é escrito o valor 3 em `/proc/sys/vm/drop_caches`, invalidando não só a _page cache_ mas também as estruturas de _dentries_ e _inodes_ mantidas pelo _kernel_. Esta invalidação assume particular importância nos sistemas de ficheiros avaliados, uma vez que a _flag_ `O_DIRECT` não impede o recurso à _cache_ quando as otimizações de conteúdo se encontram ativas.

Por fim, o procedimento aguarda cinco minutos antes de iniciar a execução seguinte, período durante o qual o dispositivo permanece em repouso e conclui as tarefas internas que adia para os momentos de inatividade, como o esvaziamento dos _buffers_ e parte do trabalho do _garbage collector_. Sem esta pausa, uma carga intensiva em escritas deixaria essas tarefas pendentes, penalizando artificialmente a execução subsequente @traeger2008 @tarasov2011.

Importa realçar, no entanto, que a pausa apenas neutraliza a manutenção despoletada pela inatividade, uma vez que o _garbage collector_, quando acionado pela escassez de blocos livres, depende do volume escrito e não do tempo decorrido. Essa atuação não é evitada mas antes incorporada na medição, dado que a dimensão das cargas conduz o dispositivo ao regime estacionário em que o _garbage collector_ opera de forma contínua, sendo esse o regime que se pretende avaliar.

=== Sistemas de Armazenamento Avaliados <systems>

As cargas são executadas sobre três sistemas de armazenamento distintos, sendo o primeiro o próprio dispositivo @nvme acedido sem qualquer sistema de ficheiros interposto, cenário que serve a comparação entre ferramentas e entre interfaces de @io, enquanto o Btrfs e o @zfs são avaliados por implementarem otimizações sensíveis às propriedades dos dados, nomeadamente compressão e deduplicação, encontrando-se a configuração de cada um resumida na @sistemas.

#figure(
  doc_table(
    columns: (1.3fr, 1fr, 1fr, 1fr),
    header: ([Sistema], [Versão], [Compressão], [Deduplicação]),
    [@nvme `/dev/nvme0n1`], [_Kernel_ 5.4], [Não], [Não],
    [Btrfs], [btrfs-progs 5.4.1-2], [zstd, nível 3], [_Offline_, via bees 0.11],
    [@zfs], [2.4.0], [zstd, nível 3], [_Inline_],
  ),
  caption: [Sistemas de armazenamento avaliados e respetiva configuração]
) <sistemas>

Em ambos os sistemas de ficheiros a compressão recorre ao zstd no nível 3, valor que estabelece o compromisso entre a qualidade da compressão e a rapidez com que esta é alcançada, visto níveis superiores comprimirem mais, no entanto a um custo computacional que enviesaria a avaliação do sistema de armazenamento em detrimento da avaliação do próprio algoritmo @btrfs_docs.

No @zfs o `recordsize` foi ainda fixado em 4 KiB, de modo a coincidir com os blocos manipulados pela generalidade das cargas. Esta decisão revela-se indispensável, isto porque a deduplicação opera ao nível do _record_, daí que um valor superior implicasse que blocos duplicados de 4 KiB jamais originassem _records_ idênticos, tornando a otimização inoperante face ao conteúdo gerado @zfs_docs.

As estratégias de deduplicação diferem igualmente, correspondendo às duas alternativas apresentadas na @deduplication, visto o @zfs realizar deduplicação _inline_, no caminho crítico de @io, enquanto o Btrfs a realiza _offline_, através do bees, um serviço que percorre o sistema de ficheiros em segundo plano com um índice parcial limitado a 1 GiB @bees. Tal diferença condiciona a leitura dos resultados, dado que no Btrfs a redução de espaço apenas se manifesta após a passagem do serviço, ao contrário do @zfs onde é imediata, embora ao custo de latência acrescida nas escritas @koller2010 @meyer2012.

Importa realçar que a garantia oferecida pela _flag_ `O_DIRECT` deixa de ser absoluta quando estas otimizações se encontram ativas. No Btrfs, tanto as leituras de dados comprimidos como as escritas sobre _inodes_ com _checksums_ acabam por transitar pela _page cache_, enquanto no @zfs a deduplicação e as escritas diretas são mutuamente incompatíveis, o que obrigou a desativar a propriedade `direct` nos conjuntos de dados avaliados @btrfs_docs @zfs_docs.

Desta forma, os resultados obtidos sobre sistemas de ficheiros não são diretamente comparáveis com os do acesso direto ao dispositivo no que respeita ao efeito da _page cache_, limitação que decorre da natureza das otimizações avaliadas e não da metodologia adotada.

Em qualquer dos casos, o Prismo, tal como o @fio e o Vdbench, emite pedidos de leitura e escrita de tamanho fixo sobre um ficheiro previamente alocado, exercitando por isso o caminho de dados e não as operações de metadados. Assim sendo, não se trata de uma avaliação de sistemas de ficheiros, mas antes da forma como cada sistema reage às propriedades do conteúdo que lhe é submetido.

=== Métricas

As métricas recolhidas dividem-se entre aquelas reportadas pelas próprias ferramentas e as obtidas ao nível do sistema. Do primeiro grupo fazem parte o débito, os @iops e a latência, esta última caracterizada não apenas pelo valor médio mas também pelos percentis p50, p99 e p99.9, pois a média isoladamente esconde o comportamento da cauda da distribuição @traeger2008 @tarasov2011.

Já as métricas de sistema, nomeadamente a utilização de @cpu e de @ram, são recolhidas através do `pcp dstat` com uma frequência de amostragem de um segundo, que constitui a única fonte comum às três ferramentas e portanto a única que permite uma comparação justa do consumo de recursos.

Nas cargas que exercitam deduplicação e compressão, o espaço efetivamente ocupado em disco seria a grandeza capaz de confirmar que as otimizações do sistema de armazenamento foram de facto acionadas pelo conteúdo gerado, no entanto a sua recolha não chegou a ser incluída na campanha por limitações de tempo, ausência cujas consequências se discutem na @limitations.

*Agregação de métricas.* Uma vez recolhidas, as métricas são apresentadas através do valor reportado pela ferramenta, acompanhado do desvio padrão calculado sobre a respetiva série temporal. Deste modo, as barras de erro presentes nas figuras adiante traduzem a oscilação da medição ao longo da execução, sendo descartadas as primeiras amostras de modo a excluir o período de arranque.

No entanto, os percentis de latência constituem um caso particular, dado que os relatórios registam apenas o valor já calculado sobre a totalidade da execução, não sendo por isso possível acompanhar a sua evolução temporal nem associar-lhes uma medida de dispersão.

== Validação do Prismo <validation>

Previamente a utilizar o Prismo para avaliar sistemas de armazenamento, é necessário estabelecer confiança na ferramenta, daí que esta secção procure demonstrar que os resultados produzidos são fiáveis e comparáveis aos das ferramentas de referência em cargas genéricas, ao mesmo tempo que valida a correção dos mecanismos de geração de conteúdo.

=== Débito dos Componentes <components-section>

Antes de confrontar o Prismo com as ferramentas de referência, importa determinar o débito máximo que os seus componentes conseguem sustentar, pois qualquer limite imposto pela própria ferramenta comprometeria a atribuição dos resultados ao sistema de armazenamento. Para o efeito, cada gerador foi exercitado isoladamente, sem submissão de pedidos ao dispositivo, ao longo de 100 milhões de invocações.

#figure(
  grid(
    columns: 2, gutter: 6pt, row-gutter: 10pt,
    component-bars("components.csv", "Acesso", title: [Gerador de acessos]),
    component-bars("components.csv", "Conteúdo", title: [Gerador de conteúdo]),
    component-bars("components.csv", "Operação", title: [Gerador de operações]),
    component-bars("components.csv", "Extensão", title: [Extensão de _trace_]),
  ),
  caption: [Débito máximo de cada componente do Prismo]
) <componentes>

Os valores reunidos na @componentes revelam uma disparidade de duas ordens de grandeza entre variantes, sendo o gerador de operações constante o mais rápido, com 844.8 milhões de operações por segundo, enquanto o gerador de conteúdo com deduplicação se fica pelos 4.8 milhões, diferença que se explica pelo trabalho envolvido, dado que o primeiro devolve um valor fixo e o segundo constrói um bloco de 4096 bytes respeitando uma distribuição de duplicados e de compressibilidade.

Uma carga combina sempre um gerador de cada categoria, atuando estes em série na preparação de cada pedido, pelo que o débito da configuração resulta da soma dos respetivos tempos. Convém realçar que uma extensão de _trace_ pode assumir o papel de qualquer um destes geradores, admitindo-se por isso configurações que recorrem a três extensões em simultâneo.

Nestes termos, a configuração menos favorável corresponde a três extensões por regressão, que consomem 213.7 nanossegundos cada e limitam o Prismo a 1.6 milhões de operações por segundo. Já a pior combinação entre geradores convencionais, reunindo acesso Zipfian, operações por percentagem e conteúdo com deduplicação, totaliza 294.0 nanossegundos e permite 3.4 milhões de operações por segundo.

Assim sendo, mesmo a configuração mais exigente mantém-se cerca de 14× acima do débito máximo observado nas experiências, que foi de 113 015 @iops na carga 02 (demonstrado adiante), margem suficiente para acomodar dispositivos consideravelmente mais rápidos do que o utilizado. Deste modo, nenhuma combinação de geradores constitui o fator limitante da avaliação, e os resultados apresentados traduzem o comportamento do sistema de armazenamento.

=== Reprodutibilidade

A validação assenta nas cargas 01 a 09 executadas sobre o dispositivo @nvme através da interface POSIX, único cenário em que as três ferramentas, o Prismo, o @fio e o Vdbench, operam sobre configurações muito semelhantes e podem por isso ser confrontadas diretamente.

O primeiro requisito a verificar é a estabilidade das medições, pois uma ferramenta cujos valores oscilem acentuadamente não permite distinguir o efeito da carga do simples ruído experimental. Esta estabilidade é quantificada pelo coeficiente de variação das séries por segundo recolhidas ao longo de cada execução, apresentado na @reprodutibilidade.

#figure(
  tool-lines("validation-cv.csv", ylabel: [Coeficiente de variação (%)]),
  caption: [Coeficiente de variação do débito de operações por carga]
) <reprodutibilidade>

Os valores obtidos pelo Prismo situam-se entre 0.50% e 2.71%, gama que confirma tratar-se de medições estáveis, sendo de realçar que em sete das nove cargas a oscilação é inferior à do Vdbench e em quatro delas inferior também à do @fio.

A carga 03 destaca-se por apresentar a maior dispersão nas três ferramentas, comportamento que não é imputável aos _benchmarks_ mas ao dispositivo, pois trata-se da única carga com blocos de 64 KiB e o débito alcançado esgota periodicamente a _cache_ interna do @nvme. Por outro lado, o Vdbench exibe oscilações acima de 9% em várias cargas, o que é consistente com as pausas introduzidas pela máquina virtual do Java.

Estes valores fixam o critério de leitura adotado no restante capítulo, dado que uma diferença entre duas medições só é considerada efetiva quando excede a oscilação que a própria medição apresenta. Na prática, e tomando o valor mais elevado registado pelo Prismo, diferenças inferiores a 3% são tratadas como equivalência e não como vantagem de uma ferramenta sobre a outra @traeger2008 @tarasov2011.

Convém realçar que esta análise caracteriza a estabilidade da medição e não a variabilidade entre execuções independentes, a qual exigiria a repetição integral da campanha e não foi avaliada, conforme se assinala nas limitações.

=== Equivalência em Cargas Genéricas

Aferida a estabilidade das medições, importa agora verificar se o Prismo produz valores comparáveis aos das ferramentas de referência quando submetido às mesmas condições, ou seja, as mesmas cargas submetidas através da interface POSIX diretamente ao dispositivo @nvme, sem sistema de ficheiros interposto, confronto que incide sobre o débito de operações, a latência e o consumo de recursos.

#figure(
  tool-bars("validation-iops.csv", ylabel: [Milhares de @iops]),
  caption: [Débito de operações por carga em cada ferramenta]
) <validacao-iops>

O débito apresentado na @validacao-iops revela concordância entre as três ferramentas em praticamente todas as cargas, com desvios que se mantêm abaixo do limiar de dispersão nos cenários dominados pelo dispositivo, ou seja naqueles assentes em acessos aleatórios. Nestas condições o dispositivo satura muito antes de qualquer ferramenta se aproximar do seu limite, pelo que as três medem inevitavelmente a mesma realidade.

As cargas sequenciais afastam-se ligeiramente deste padrão, com uma vantagem para o Prismo na ordem dos cinco pontos percentuais, atribuível ao modelo produtor-consumidor descrito no @chapter3, uma vez que a preparação dos pedidos decorre numa _thread_ distinta daquela que os submete e permite manter o dispositivo ocupado enquanto o bloco seguinte é construído.

A carga 07 constitui a única exceção relevante, com o Prismo a ficar cerca de um quinto abaixo do @fio. Ambas as ferramentas executaram exatamente o mesmo trabalho, com idêntico número de operações, volume escrito e repartição entre leituras e escritas, diferindo apenas na duração, pelo que a explicação tem de residir no custo por pedido e não na carga submetida.

Descartam-se desde logo duas hipóteses, dado que a geração de conteúdo é equivalente nas duas ferramentas, visto o parâmetro `buffer_compress_percentage` do @fio ativar automaticamente o `refill_buffers` @fio_docs, e dado que a @componentes demonstra que os geradores sustentam um débito duas ordens de grandeza superior ao exigido por esta carga.

Esta leitura é corroborada pela carga 03, que recorre igualmente à regeneração de conteúdo mas com blocos 16× maiores, reduzindo na mesma proporção o número de pedidos, e onde o Prismo volta a apresentar vantagem. Deste modo, tudo indica tratar-se de um custo que se manifesta por pedido e não por byte transferido.

*Efeitos da localidade de acessos.* Ainda sobre a @validacao-iops, importa notar que o padrão de acessos produz por si só diferenças consideráveis, alcançando a carga 02, de leitura sequencial, 113 mil operações por segundo, contra as 13.2 mil da carga 04, que dela difere apenas por aceder ao dispositivo de forma aleatória, ou seja, 8.6× menos. Menos intuitivo é o confronto entre as cargas 05 e 06, que diferem unicamente na distribuição dos _offsets_, ficando a Zipfian 14.3% abaixo da uniforme no Prismo e 15.9% no @fio, contrariando a expectativa de a localidade favorecer o desempenho, a qual provém sobretudo dos suportes rotativos.

Uma vez que estas diferenças se repetem no Prismo e no @fio, caracterizam o dispositivo e não o _benchmark_, sendo elucidativa a série por segundo da carga 06, que expõe sete perturbações a intervalos de cerca de dois minutos, assinatura compatível com a atuação do _garbage collector_, dado que a concentração de escritas numa região restrita esgota mais depressa os blocos livres dessa zona. A consequência para o restante capítulo é sobretudo de leitura, visto só ser legítimo comparar configurações que partilhem o padrão de acessos.

#figure(
  panels(columns: 1,
    tool-bars("validation-latency.csv", ylabel: [Latência média (µs)],
              height: 3.8cm, ylim: (0, 100),
              subcaption: [(a) Latência média com o desvio padrão da série, truncado no limite do eixo nas cargas 08 e 09 do Vdbench]),
    tool-bars("validation-p99.csv", ylabel: [Latência p99 (µs)],
              height: 3.8cm, legend: false,
              subcaption: [(b) Percentil 99, calculado sobre a execução completa e por isso sem medida de dispersão]),
  ),
  caption: [Latência média e percentil 99 por carga em cada ferramenta]
) <validacao-latencia>

A latência média confirma a equivalência estabelecida pelo débito, sendo a @validacao-latencia (a) essencialmente uma imagem espelhada da figura anterior, o que demonstra medir a instrumentação do Prismo a mesma realidade que as ferramentas consagradas.

O percentil 99, na @validacao-latencia (b), revela porém um padrão que a média esconde, pois o Prismo apresenta uma cauda mais pesada nas cargas que combinam escritas com concorrência, chegando a duplicar o valor do @fio, enquanto nas sequenciais a situação se inverte a seu favor.

Este comportamento é atribuível ao mesmo modelo produtor-consumidor que explica a vantagem no débito, uma vez que a fila de pedidos bloqueia o produtor sempre que atinge a capacidade limite, penalizando os pedidos que nela aguardam sem afetar o débito agregado. Assim sendo, o Prismo privilegia a ocupação do dispositivo em detrimento da previsibilidade individual de cada pedido, compromisso que importa ter presente sempre que a cauda da distribuição seja o objeto de estudo.

#figure(
  panels(columns: 1,
    tool-bars("validation-cpu.csv", ylabel: [Utilização de @cpu (%)],
              height: 3.8cm,
              subcaption: [(a) Utilização de @cpu da máquina, amostrada a cada segundo pelo `pcp dstat`]),
    tool-bars("validation-ram.csv", ylabel: [Memória utilizada (GiB)],
              height: 3.8cm, legend: false,
              subcaption: [(b) Memória ocupada na máquina, incluindo a pré-alocada por cada ferramenta]),
  ),
  caption: [Consumo de recursos por carga em cada ferramenta]
) <validacao-recursos>

Por fim, o consumo de recursos apresentado na @validacao-recursos demonstra que as decisões arquiteturais do Prismo não acarretam um custo desproporcional, sendo a utilização de @cpu, na @validacao-recursos (a), indistinguível da do @fio, ao passo que o Vdbench se destaca por executar sobre a máquina virtual do Java @vdbench.

Ao nível da memória utilizada pela máquina, na @validacao-recursos (b), a distância é mais nítida, embora modesta em termos absolutos, pois o Prismo ocupa cerca de meio gigabyte acima do @fio, diferença que decorre do _pool_ de pacotes pré-alocado durante a inicialização do canal descrito no @chapter3, enquanto o Vdbench requer perto de três gigabytes adicionais. Tratando-se de uma máquina com 188 GiB, nenhum destes valores condiciona a avaliação.

=== Fator Limitante da Avaliação

O débito dos componentes, analisado na @components-section, demonstrou que nenhum gerador limita a avaliação, no entanto essa medição incidiu sobre cada peça isoladamente e não sobre a execução completa. A repartição do tempo de @cpu recolhida pelo `pcp dstat` permite confirmar a conclusão em condições reais.


#figure(
  cpu-stack("validation-cpu-types.csv"),
  caption: [Repartição do tempo de @cpu durante a execução do Prismo]
) <validacao-cpu-tipos>

A @validacao-cpu-tipos apresenta as componentes de utilizador, sistema e espera por @io, correspondendo o remanescente até 100% a tempo ocioso, que se situa acima de 95% em todas as cargas com um único _job_ e em 91.6% na carga 09. Estes valores decorrem de a máquina disponibilizar 96 _threads_ de execução enquanto o _benchmark_ ocupa apenas uma, ou três no caso da carga 09.

Mais relevante é a proporção entre as componentes ativas, visto a espera por @io representar entre 29% e 48% do tempo não ocioso nas cargas com um único _job_, valor que ascende a 70% na carga 09. Por outras palavras, o processador passa mais tempo à espera do dispositivo do que a executar código do _benchmark_, seja em espaço de utilizador ou dentro do _kernel_.

Convém realçar que a componente de utilizador, onde reside a geração de conteúdo e a preparação dos pedidos, não ultrapassa 0.77% em qualquer carga, mantendo-se sempre abaixo da componente de sistema. Assim sendo, o custo do Prismo é dominado pelas chamadas ao sistema inerentes à interface POSIX e não pela lógica própria da ferramenta.

Em suma, os resultados apresentados ao longo desta secção medem a capacidade do sistema de armazenamento e não o limite das ferramentas utilizadas, ficando assim fundamentado o V2, dado que as medições do Prismo se revelaram estáveis e comparáveis às das ferramentas de referência, conclusão que sustenta a interpretação de todas as comparações realizadas no restante capítulo @traeger2008 @didona2022.

=== Validação da Geração de Conteúdo

A equivalência demonstrada até aqui atesta a fiabilidade da instrumentação, no entanto nada diz sobre a propriedade que distingue o Prismo, ou seja, a capacidade de gerar conteúdo com distribuições de duplicados e compressibilidade controladas. Assim sendo, o #link("https://github.com/dsrhaslab/prismo/blob/main/tools/deltoide/README.md")[Deltoide], ferramenta auxiliar apresentada na @implementation, é aplicado sobre os dados efetivamente escritos, extraindo as distribuições presentes no dispositivo de armazenamento.

A carga 11 foi configurada com três grupos de duplicados, definidos pelo número de cópias adicionais de cada bloco, e cada um com a sua própria repartição de compressibilidade, apresentando a @conteudo-dup a percentagem de blocos atribuída a cada grupo, tal como foi configurada e tal como o Deltoide a mediu.

#figure(
  tool-bars("content-dedup.csv", ylabel: [Blocos escritos (%)],
            xlabel: [Cópias adicionais por bloco], width: 8.5cm, height: 4.4cm),
  caption: [Distribuição de duplicados configurada e medida na carga 11]
) <conteudo-dup>

Já a @conteudo detalha a compressibilidade dentro de cada grupo, onde cada entrada indica a percentagem de blocos do grupo e a redução de tamanho que a compressão alcança nesses blocos, ou seja, a fração do bloco eliminada pela zstd, correspondendo uma redução nula a conteúdo incompressível.

#figure(
  doc_table(
    columns: (0.6fr, 1.4fr, 1.4fr),
    header: ([Cópias], [Compressibilidade configurada], [Compressibilidade medida]),
    [0], [50% dos blocos sem redução \ 50% dos blocos com redução de 50%], [49.7% dos blocos sem redução \ 50.3% dos blocos com redução de 49.7%],
    [1], [70% dos blocos com redução de 30% \ 30% dos blocos com redução de 20%], [71.2% dos blocos com redução de 30.2% \ 28.8% dos blocos com redução de 19.8%],
    [3], [100% dos blocos sem redução], [100% dos blocos sem redução],
  ),
  caption: [Compressibilidade configurada e medida em cada grupo de duplicados da carga 11]
) <conteudo>

Os desvios observados não ultrapassam 1.1% na repartição de duplicados nem 1.2% na de compressibilidade, valores que confirmam uma reprodução fiel da distribuição solicitada. Além disso, observa-se um comportamento particular do algoritmo de geração de duplicados: à medida que os blocos repetidos avançam através da janela, a percentagem medida para o último nível de cópias nunca pode exceder a percentagem solicitada, uma vez que este corresponde ao último estágio.

Estes resultados fundamentam o V1, dado que a distribuição medida sobre os dados escritos corresponde à configurada, e não a uma aproximação global como a praticada pelas ferramentas de referência, cujas configurações apenas admitem uma taxa única de duplicados e de compressibilidade @fio_docs @vdbench.

== Impacto das Propriedades dos Dados no Desempenho <data-properties>

Estabelecida a credibilidade do Prismo enquanto instrumento de medição, esta secção explora o eixo que o distingue das ferramentas de referência, nomeadamente o impacto das propriedades intrínsecas dos dados no desempenho dos sistemas de armazenamento. Na prática, _benchmarks_ que ignoram a compressibilidade e a taxa de duplicados tendem a produzir avaliações que não refletem o comportamento real dos sistemas sensíveis ao conteúdo.

A análise decorre sobre o Btrfs e o @zfs, únicos sistemas avaliados que reagem ao conteúdo, começando pelo estabelecimento de uma linha de base com dados aleatórios, uma vez que só a comparação entre cargas que diferem exclusivamente nas propriedades do conteúdo, executadas sobre o mesmo sistema, permite isolar o contributo dessas propriedades.

=== Linha de Base por Sistema de Armazenamento

As cargas 04, 05 e 06 operam sobre conteúdo aleatório, logo incompressível e sem duplicados, pelo que o débito de operações obtido traduz aquilo que cada sistema de ficheiros consegue entregar quando as suas otimizações nada têm para explorar. Entre estas destaca-se a carga 06, que partilha com as duas seguintes (cargas 10 e 11) a distribuição Zipfian de acessos e constitui por isso a referência mais próxima.

#figure(
  tool-bars("impact-baseline.csv", ylabel: [Milhares de @iops],
            xlabel: [Carga]),
  caption: [Débito de operações do Prismo com conteúdo aleatório em cada sistema de ficheiros]
) <impacto-baseline>

A @impacto-baseline evidencia desde logo uma diferença estrutural entre os dois sistemas, com o Btrfs a entregar entre 3.2× e 4.1× o débito do @zfs em todas as cargas. Esta distância decorre do custo que o @zfs impõe a cada operação, resultante da combinação entre a semântica _copy-on-write_, a verificação de _checksums_ e o `recordsize` de 4 KiB adotado, que multiplica o número de registos a gerir face ao valor por omissão.

Merece destaque o facto de a carga 04, composta exclusivamente por leituras, apresentar o débito mais baixo em ambos os sistemas, enquanto a carga 05, com metade das operações a serem escritas, mais do que duplica esse valor no Btrfs. Uma explicação plausível reside no encaminhamento das escritas através da _cache_, conforme exposto na @systems, retornando estas sem aguardar o dispositivo.

Por outro lado, a carga 06 fica ligeiramente abaixo da carga 05 nos dois sistemas, apesar de a distribuição Zipfian concentrar os acessos numa fração reduzida do dispositivo, resultado que contraria a expectativa de a localidade favorecer o desempenho e que se observa igualmente sobre o dispositivo em acesso direto, conforme exposto na @validation, não sendo por isso imputável aos sistemas de ficheiros.

Convém realçar que a dispersão registada nestas cargas é bastante superior à observada sobre o dispositivo em acesso direto, situando-se entre 10% e 18% do valor médio, o que decorre de os sistemas de ficheiros introduzirem trabalho assíncrono que não acompanha o ritmo dos pedidos, oscilando por isso o débito instantâneo conforme essas tarefas são despachadas.

=== Compressão

A carga 10 escreve conteúdo com compressibilidade controlada segundo três níveis de redução, cenário que o @fio e o Vdbench apenas conseguem aproximar através de uma taxa global aplicada a todos os blocos, sendo o débito de operações obtido por cada ferramenta em cada sistema de ficheiros apresentado na @impacto-compressao.

#figure(
  tool-bars("impact-compression.csv", ylabel: [Milhares de @iops],
            xlabel: [Sistema de ficheiros]),
  caption: [Débito de operações na carga 10 em cada sistema de ficheiros]
) <impacto-compressao>

Confrontando a @impacto-compressao com a linha de base, verifica-se que o Prismo alcança mais 26% de débito no Btrfs e mais 32% no @zfs do que na carga 06, que partilha com esta a distribuição Zipfian de acessos. O mecanismo que sustenta este ganho parece claro, o conteúdo compressível permite ao sistema de ficheiros armazenar fisicamente menos dados do que aqueles que lhe são entregues, reduzindo na mesma medida o trabalho pedido ao dispositivo e libertando-o para aceitar mais operações no mesmo intervalo.

Convém realçar, no entanto, que esta comparação não isola o efeito do conteúdo, visto a carga 10 apresentar também uma proporção superior de escritas, as quais, conforme observado na própria linha de base, tendem a elevar o débito por retornarem sem aguardar o dispositivo. Assim sendo, ambas as diferenças atuam no mesmo sentido e o ganho não é integralmente imputável à compressibilidade.

É o confronto entre ferramentas que procura eliminar esta ambiguidade, dado que o Prismo e o @fio executam exatamente a mesma carga, diferindo unicamente no conteúdo submetido. No @zfs o débito das duas ferramentas diverge em cerca de 31%, aproximadamente o dobro da dispersão das medições, sendo por isso a única divergência de débito desta secção que excede a dispersão e que, segundo o critério definido na @validation, pode ser considerada efetiva.

No entanto, merece particular destaque o facto de as duas configurações terem sido deliberadamente igualadas na compressibilidade média, pois a distribuição do Prismo, com metade dos blocos incompressíveis, 30% a reduzir metade e 20% a reduzir três quartos, produz exatamente os mesmos 30% que o @fio aplica de forma uniforme a todos os blocos.

Deste modo, a divergência observada não é imputável a uma carga globalmente mais compressível, mas ao modo como essa compressibilidade se distribui pelos blocos. Por outras palavras, o sistema de armazenamento responde à forma da distribuição e não apenas ao seu valor médio, propriedade que uma taxa única, como a utilizada no @fio, é por construção incapaz de exprimir.

No Btrfs as duas ferramentas divergem em sentido oposto, em cerca de 16%, divergência que não deve porém ser interpretada como efetiva, dado que a dispersão das medições ronda os 13% e os intervalos das duas ferramentas se sobrepõem numa extensão considerável, obrigando assim o critério estabelecido na secção anterior a tratá-las como equivalentes.

Convém realçar que a elevada dispersão do Btrfs decorre da sua própria arquitetura, dado que a compressão opera sobre _extents_ de dimensão superior ao bloco de 4 KiB submetido, agrupando num mesmo _extent_ blocos de compressibilidade distinta. Deste modo, a redução alcançada depende de quais os blocos que ficam agrupados, variando ao longo da execução de uma forma que o @zfs, ao comprimir cada _record_ isoladamente, não apresenta.

Determinar se existe de facto uma divergência no Btrfs exigiria a medição do espaço ocupado em disco, única grandeza capaz de revelar quanto foi efetivamente reduzido em cada caso, medição que não chegou a ser incluída na campanha por limitações de tempo e cuja ausência constitui a principal limitação desta subsecção @btrfs_docs.

=== Deduplicação <dedup-section>

A carga 11 acrescenta à compressibilidade uma distribuição de duplicados repartida por três grupos, exercitando deste modo as duas otimizações em conjunto. Esta análise incide unicamente sobre o @zfs, isto porque no Btrfs a deduplicação é _offline_ e nada garante que o bees percorra os dados dentro da janela de medição, pelo que avaliá-lo exigiria execuções consideravelmente mais longas, aspeto que não constituiu foco desta avaliação.

#figure(
  tool-bars("impact-dedup-zfs.csv", ylabel: [Milhares de @iops],
            width: 8.5cm, height: 4.6cm),
  caption: [Débito de operações no @zfs nas cargas 10 e 11]
) <impacto-dedup>

A @impacto-dedup mostra a carga 11 a reproduzir de forma quase exata o comportamento da carga anterior, mantendo-se as diferenças entre ambas abaixo de 2% em todas as ferramentas, valor muito inferior à dispersão registada, pelo que a introdução de duplicados não produziu qualquer efeito mensurável no débito.

Uma vez que no @zfs a deduplicação atua no caminho crítico e a propriedade `direct` foi desativada precisamente para a manter operacional, a ausência de efeito não decorre de a otimização ter ficado por acionar, admitindo antes duas explicações. A primeira decorre da configuração das cargas, visto a carga 11 apresentar uma compressibilidade média de 22% contra os 30% da carga 10, pelo que o ganho trazido pelos duplicados pode estar a ser anulado por uma redução por compressão inferior em oito pontos percentuais.

A segunda explicação aponta para o recurso que limita a execução, visto o @zfs consumir cerca de 5× mais processador que o Btrfs e ocupar perto de sessenta gigabytes de memória, conforme se apresenta na @impacto-recursos. Neste caso, como o custo dominante reside no anfitrião e não no disco, evitar escritas físicas não aumenta o débito, que permanece indiferente à presença de duplicados.

=== Custo Computacional das Otimizações

A redução do volume escrito não é gratuita, dado que a compressão e a deduplicação consomem processador e memória em troca das operações de @io poupadas, custo que a @impacto-recursos apresenta para a carga 11, onde no @zfs ambas as otimizações se encontram ativas e no Btrfs apenas a compressão atua dentro da janela de medição.

#figure(
  panels(
    tool-bars("impact-cpu.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Sistema de ficheiros], width: 6.0cm, height: 4.4cm, legend: false,
              subcaption: [(a) Utilização de @cpu, incluindo o trabalho do sistema de ficheiros]),
    tool-bars("impact-ram.csv", ylabel: [Memória utilizada (GiB)],
              xlabel: [Sistema de ficheiros], width: 6.0cm, height: 4.4cm,
              subcaption: [(b) Memória ocupada na máquina, incluindo o ARC no @zfs]),
  ),
  caption: [Consumo de recursos na carga 11 em cada sistema de ficheiros]
) <impacto-recursos>

O contraste apresentado na @impacto-recursos é acentuado, dado que o @zfs consome cerca de 5× mais processador do que o Btrfs, na @impacto-recursos (a), e ocupa perto de sessenta gigabytes de memória contra pouco mais de dez, na @impacto-recursos (b), custo que reflete a natureza _inline_ das suas otimizações e o dimensionamento do ARC.

A comparação da memória entre ferramentas no @zfs exige, por sua vez, alguma cautela, pois embora o Prismo ocupe cerca de oito gigabytes menos do que o @fio, a memória de cada ferramenta oscila mais de vinte gigabytes ao longo da execução, à medida que o ARC cresce, ficando a diferença muito aquém da dispersão e obrigando o critério adotado a tratá-las como equivalentes.

Duas origens poderiam explicar uma eventual diferença, a retenção no ARC dos blocos já comprimidos e a tabela de deduplicação, cuja dimensão depende do número de blocos únicos. Os dados recolhidos não permitem separá-las, sendo apenas de notar que o @fio, configurado com 50% de blocos duplicados contra os 28.75% do Prismo, escreve menos blocos únicos, pelo que a tabela de deduplicação o levaria a ocupar menos memória e não mais.

No Btrfs a leitura mais informativa reside no processador, onde o @fio consome praticamente o dobro do Prismo, diferença que excede a dispersão de ambas as séries, para um débito que, conforme estabelecido, não é distinguível do ruído da medição. Esta assimetria é coerente com a forma das duas distribuições, visto metade dos blocos do Prismo serem incompressíveis e portanto descartados precocemente pelo algoritmo, enquanto os do @fio, uniformemente compressíveis a 30%, obrigam ao trabalho completo em cada bloco @btrfs_docs.

Deste modo, o custo de comprimir depende não apenas da quantidade de dados redutíveis mas do modo como essa redutibilidade se distribui, o que reforça a conclusão avançada na subsecção da compressão sobre a insuficiência de uma taxa única para caracterizar o conteúdo.

Em suma, um _benchmark_ que reduza as propriedades do conteúdo a uma taxa única obtém no @zfs um débito que diverge em cerca de um terço do medido perante a distribuição correspondente, resultado que demonstra não ser a fidelidade do conteúdo um requisito acessório, mas antes condição para que a avaliação seja representativa @koller2010 @meyer2012.

Assim sendo, a resposta à Q1 é afirmativa quanto à compressibilidade e à forma como esta se distribui pelos blocos, ficando a taxa de duplicados sem efeito mensurável no débito pelas razões expostas na @dedup-section, enquanto a Q2 encontra resposta no custo das otimizações, que o @zfs suporta em processador e memória por as aplicar no caminho crítico. Estabelecido o efeito das propriedades dos dados, importa agora averiguar em que medida a interface de @io condiciona os valores medidos.

== Comparação de Interfaces de E/S <io-interfaces>

O suporte a múltiplas interfaces de @io constitui uma das funcionalidades distintivas do Prismo, daí que faça todo o sentido avaliar o impacto da escolha da interface no desempenho observado. Embora o @fio suporte as mesmas interfaces, o acesso ao @spdk é conseguido através de um _plugin_ cuja utilização é deveras complexa, não sendo por isso suportado nativamente. Por outro lado, o Vdbench opera exclusivamente sobre POSIX síncrono. Deste modo, a comparação entre as três ferramentas é possível para POSIX, enquanto para io_uring, libaio e @spdk a comparação é restrita ao Prismo e ao @fio.

Todas as execuções recorrem ao dispositivo acedido diretamente e partilham a parametrização descrita adiante, o que permite separar dois efeitos distintos. As diferenças entre interfaces medidas com a mesma ferramenta traduzem o custo do próprio mecanismo de submissão, ao passo que as diferenças entre ferramentas dentro da mesma interface só podem ser imputadas ao modo como cada uma a utiliza.

=== Configuração das Interfaces

A interface POSIX opera de forma síncrona através das chamadas `pread` e `pwrite`, mantendo por isso um único pedido em curso de cada vez, condição que a torna a referência natural contra a qual as restantes são confrontadas, afinal qualquer ganho observado traduz o benefício de sobrepor operações.

O libaio e o io_uring recebem em ambas as ferramentas uma profundidade de fila de 128 pedidos, sendo este o valor que fixa quantas operações podem aguardar conclusão ao mesmo tempo e portanto o parâmetro determinante deste confronto. No io_uring é adicionalmente ativado o _polling_ do _kernel_, ficando a _thread_ responsável fixada no primeiro núcleo do processador @uring_kernel.

Já o @spdk dispensa por completo a intervenção do _kernel_, acedendo ao dispositivo a partir do espaço de utilizador através da abstração de @bdev. Além disso, o Prismo é configurado com uma máscara de quatro _reactors_ e oito _threads_ lógicas, enquanto o @fio recorre ao _plugin_ `spdk_bdev` respeitando a profundidade de fila das restantes interfaces assíncronas @spdk_docs.

Convém realçar que apenas o libaio e o io_uring admitem uma comparação rigorosa entre ferramentas, dado que o modelo de _reactors_ do Prismo não encontra correspondência direta nos parâmetros do _plugin_, pelo que os valores do @spdk devem ser lidos com a devida reserva.

=== Cargas Sequenciais

As cargas 01 e 02 percorrem o dispositivo de forma sequencial com blocos de 4 KiB, a primeira em escrita e a segunda em leitura, constituindo por isso o cenário mais favorável à submissão assíncrona, uma vez que o padrão de acessos é previsível e permite ao dispositivo antecipar os pedidos seguintes.

#figure(
  panels(
    tool-bars("interfaces-wl01.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false,
              subcaption: [(a) Carga 01, escrita sequencial com blocos de 4 KiB]),
    tool-bars("interfaces-wl02.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm,
              subcaption: [(b) Carga 02, leitura sequencial com blocos de 4 KiB]),
  ),
  caption: [Débito de operações nas cargas 01 e 02 em cada interface de @io]
) <interfaces-seq>

A @interfaces-seq revela um ganho considerável das interfaces assíncronas sobre o POSIX, que no Prismo ascende a cerca de 4.8× na escrita, na @interfaces-seq (a), e 4× na leitura, na @interfaces-seq (b), resultado esperado visto o POSIX síncrono bloquear a _thread_ em cada operação e permitir por isso um único pedido em curso, enquanto as restantes mantêm dezenas em execução ao mesmo tempo.

Convém realçar que o Prismo iguala ou supera o @fio em todas as interfaces nestas duas cargas, com vantagem particularmente nítida no libaio, onde alcança perto de 20% acima. Assim sendo, a arquitetura produtor-consumidor mostra-se adequada a padrões previsíveis, nos quais o produtor consegue antecipar a preparação dos pedidos enquanto o consumidor aguarda as conclusões.

O @spdk apresenta, no entanto, um comportamento que contraria a expectativa, dado situar-se entre 10% e 14% abaixo do io_uring e do libaio no Prismo, quando seria de esperar que a eliminação do _kernel_ do caminho crítico produzisse o débito mais elevado de todos.

Convém realçar que o mesmo padrão se observa no @fio, cujo @spdk fica igualmente abaixo das interfaces do _kernel_, afastando-se assim a hipótese de a causa residir na implementação de qualquer das ferramentas e apontando antes para o modo como esta interface lida com as características da carga.

Porém, no caso do Prismo, a explicação mais provável reside na configuração de _reactors_ adotada, que reserva quatro núcleos e oito _threads_ lógicas independentemente do perfil da carga, repartição que não é necessariamente a mais favorável a um padrão sequencial servido por um único produtor. Assim sendo, importa admitir que este resultado não fica cabalmente explicado pelos dados recolhidos.

=== Saturação da Largura de Banda

As cargas anteriores mantiveram o bloco em 4 KiB, dimensão que obriga a submeter um elevado número de pedidos para movimentar um volume modesto de dados e que coloca por isso o esforço do lado da submissão. A carga 03 altera exclusivamente este parâmetro, elevando-o para 64 KiB, reduzindo em 16× o número de operações necessárias para transferir a mesma quantidade de dados.

Deste modo, o dispositivo deixa de ser solicitado pela cadência dos pedidos e passa a sê-lo pelo volume que deles resulta, permitindo assim averiguar se a vantagem das interfaces assíncronas se mantém quando o estrangulamento muda de natureza.

#figure(
  tool-bars("interfaces-wl03.csv", ylabel: [Milhares de @iops],
            xlabel: [Interface], width: 8.5cm, height: 4.6cm),
  caption: [Débito de operações na carga 03 em cada interface de @io]
) <interfaces-bloco>

Conforme se observa na @interfaces-bloco, as quatro interfaces produzem resultados indistinguíveis entre si e entre ferramentas, situando-se todas próximo das 28 mil operações por segundo. Uma vez que este valor corresponde a cerca de 1.8 GiB por segundo, conclui-se que o fator limitante deixou de ser a submissão de pedidos e passou a ser a largura de banda do próprio dispositivo.

Merece destaque o facto de esta convergência abranger igualmente o @spdk, cujo acesso em espaço de utilizador não lhe confere qualquer vantagem neste cenário, resultado que reforça a ideia de que a limitação se encontra no próprio dispositivo, e não no caminho de acesso utilizado.

Por fim, importa reter que a escolha da interface apenas é determinante enquanto o estrangulamento reside no número de operações submetidas, pois numa carga que submete pedidos sem pausas, como esta, qualquer interface atinge o mesmo limite de débito assim que o volume de dados satura o dispositivo. Tal não torna as interfaces equivalentes, visto as diferenças poderem manifestar-se na latência ou sob cargas abaixo da saturação, cenários que ficam por explorar e que se apontam na @limitations.

=== Cargas Aleatórias e Mistas

As cargas 04 e 05 substituem o acesso sequencial por acessos aleatórios distribuídos por toda a extensão do dispositivo, o que impede qualquer antecipação por parte deste e obriga cada pedido a suportar integralmente a latência do acesso. Nestas condições, o débito deixa de depender predominantemente da rapidez com que os dados são transferidos e passa a ser limitado pela capacidade de manter pedidos em curso, pelo que a profundidade da fila assume um papel determinante.

#figure(
  panels(
    tool-bars("interfaces-wl04.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false,
              subcaption: [(a) Carga 04, leituras aleatórias sobre todo o dispositivo]),
    tool-bars("interfaces-wl05.csv", ylabel: [Milhares de @iops],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm,
              subcaption: [(b) Carga 05, leituras e escritas aleatórias em partes iguais]),
  ),
  caption: [Débito de operações nas cargas 04 e 05 em cada interface de @io]
) <interfaces-rand>

O ganho das interfaces assíncronas é aqui muito superior ao observado nas cargas sequenciais, atingindo no Prismo cerca de 14× o débito do POSIX na leitura aleatória com o io_uring e o libaio, e 19× com o @spdk, conforme a @interfaces-rand (a), amplificação que se explica pela latência de cada acesso, integralmente exposta à aplicação numa interface síncrona e sobreposta entre pedidos concorrentes nas restantes.

O confronto entre ferramentas revela, porém, uma diferença assinalável, com o @fio a alcançar aproximadamente o dobro do Prismo na carga 04 e cerca de 60% acima na carga 05, discrepância que constitui a maior registada em todo o capítulo e que não decorre da configuração, idêntica em ambas as ferramentas.

#figure(
  panels(
    tool-bars("interfaces-lat-wl04.csv", ylabel: [Latência média (µs)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false,
              subcaption: [(a) Carga 04, composta apenas por leituras]),
    tool-bars("interfaces-lat-wl05.csv", ylabel: [Latência média (µs)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm,
              subcaption: [(b) Carga 05, com metade das operações em escrita]),
  ),
  caption: [Latência média nas cargas 04 e 05 em cada interface de @io]
) <interfaces-lat>

A @interfaces-lat esclarece a origem desta diferença, dado que a latência reportada pelo Prismo nas interfaces assíncronas duplica a do @fio, ao passo que em POSIX ambas coincidem ao décimo de microssegundo. Uma vez que o débito resulta do quociente entre os pedidos em curso e a latência de cada um, e sendo a profundidade configurada idêntica, o dobro da latência traduz-se necessariamente em metade do débito.

Convém realçar que a coincidência em POSIX é significativa, visto as duas ferramentas produzirem resultados equivalentes enquanto não existem pedidos pendentes, divergindo apenas quando estes surgem. Esta diferença é, portanto, atribuível à gestão dos pedidos pendentes, e não à instrumentação.

Merece particular destaque o facto de o Prismo obter praticamente o mesmo valor no io_uring e no libaio, duas interfaces que partilham apenas o carácter assíncrono e diferem por completo na implementação, o que localiza o estrangulamento num ponto anterior à interface e comum a ambas.

Três candidatos podem desde logo ser excluídos, dado que a @componentes demonstra sustentarem os geradores um débito duas ordens de grandeza superior ao exigido por esta carga, sendo além disso a profundidade configurada respeitada em ambas as ferramentas.

Também o canal entre produtor e consumidor fica afastado, visto medições realizadas sobre este isoladamente atingirem 10.2 de milhões operações por segundo na variante não bloqueante e 9.99 milhões na bloqueante, valores que excedem em mais de 50× o débito aqui observado e que tornam a escolha entre as duas variantes irrelevante para o resultado.

Resta assim o ciclo do consumidor, que alterna entre submeter pedidos e recolher conclusões numa única _thread_, e onde o tempo despendido a recolher atrasa a reposição da fila. Convém realçar, no entanto, que esta explicação permanece por confirmar, pois a latência reportada não permite distinguir o tempo passado no dispositivo daquele que decorre dentro do próprio Prismo, distinção cuja instrumentação constitui uma das experiências apontadas na @limitations.

=== Concorrência

A carga 09 replica o padrão aleatório misto da carga 05, distribuindo-o por três _jobs_ independentes, cada um com a sua fila e respetiva _thread_ submissora, o que permite averiguar se cada interface acompanha o aumento do número de produtores ou se algum recurso partilhado impede essa escalabilidade.

#figure(
  tool-bars("interfaces-wl09.csv", ylabel: [Milhares de @iops],
            xlabel: [Interface], width: 8.5cm, height: 4.6cm),
  caption: [Débito de operações na carga 09 em cada interface de @io]
) <interfaces-conc>

A @interfaces-conc mostra que o libaio do Prismo escala com o número de _jobs_, passando de cerca de 215 mil operações por segundo com um único _job_ para 326 mil com três, valor que iguala o do @fio e constitui o único cenário assíncrono em que as duas ferramentas convergem.

O io_uring não acompanha esta evolução em qualquer das ferramentas, mantendo-se ambas próximas do valor obtido com um único _job_, com a diferença de o @fio partir já das 344 mil operações por segundo enquanto o Prismo estagna nas 215 mil.

#figure(
  panels(
    tool-bars("interfaces-cpu-1job.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm, legend: false,
              subcaption: [(a) Carga 05, executada por um único _job_]),
    tool-bars("interfaces-cpu-3jobs.csv", ylabel: [Utilização de @cpu (%)],
              xlabel: [Interface], width: 6.0cm, height: 4.4cm,
              subcaption: [(b) Carga 09, repartida por três _jobs_ com fila e _thread_ próprias]),
  ),
  caption: [Utilização de @cpu com um _job_ e com três _jobs_ em cada interface de @io]
) <interfaces-recursos>

A @interfaces-recursos, que confronta a carga 05, na @interfaces-recursos (a), com a carga 09, na @interfaces-recursos (b), oferece a explicação mais provável, dado que o io_uring do Prismo eleva o consumo de processador em mais de metade ao passar de um para três _jobs_ sem qualquer ganho de débito, enquanto o libaio o aumenta apenas 12% e entrega em contrapartida mais 52%.

Esta penalização do desempenho decorre das _threads_ de _polling_ do _kernel_, que giram em espera ativa e que a configuração adotada fixa todas no mesmo núcleo do processador, em ambas as ferramentas, competindo portanto três instâncias por um único núcleo sem que o tempo assim despendido se traduza em pedidos submetidos.

O @spdk exibe neste cenário a degradação mais acentuada de todo o capítulo, caindo de 238 mil operações por segundo com um único _job_ para 87 mil com três, ou seja pouco mais de um terço, enquanto o @fio mantém nesta interface o mesmo débito das restantes. A origem é a mesma que penaliza o io_uring, pois no Prismo a máscara de _reactors_ é definida ao nível da interface e não do _job_, pelo que as três instâncias disputam os mesmos quatro núcleos, o que explica a subida do consumo de processador sem retorno em débito.

O @fio escapa a esta disputa porque o _plugin_ `spdk_bdev` dispensa a máscara de _reactors_ e sonda o dispositivo dentro da própria _thread_ de cada _job_, pelo que o número de _threads_ em _polling_ acompanha o número de _jobs_, conforme sugere a subida do seu consumo de processador de 4.3% para 9.1% sem perda de débito @spdk_docs.

Assim sendo, as interfaces que fixam afinidade ao processador degradam-se sempre que essa afinidade é partilhada, enquanto o libaio, por não fixar nenhuma, escala sem dificuldade, residindo a limitação não nas interfaces mas no modelo de configuração adotado, que exprime a afinidade uma única vez e não a reparte pelos _jobs_ existentes.

Em suma, a interface de @io condiciona fortemente o débito medido, com ganhos que vão de nulos, quando o dispositivo satura, até 19× nos acessos aleatórios, disparidade que fundamenta a necessidade de um _benchmark_ capaz de as exercitar a todas e que responde afirmativamente à Q3. Convém realçar, contudo, que nenhuma interface se revela superior em todos os cenários, pois o @spdk vence nos acessos aleatórios com um único _job_ mas fica atrás nas cargas sequenciais e degrada-se perante concorrência, sendo por isso desaconselhadas recomendações absolutas.

Estes resultados demonstram igualmente que o desempenho de uma interface depende da forma como é configurada face ao _hardware_ disponível e ao paralelismo da carga, como o atesta a afinidade partilhada entre _jobs_, algo que só se torna visível quando o _benchmark_ expõe estas configurações e as respetivas métricas, o que fundamenta o V3. Estabelecido este efeito, importa agora verificar se as cargas derivadas de _traces_ reproduzem fielmente as propriedades dos dados originais.

== Cargas Baseadas em _Traces_ <trace-eval>

De todas as funcionalidades do Prismo, a replicação de _traces_ é aquela que mais o distingue das ferramentas de referência, uma vez que nenhuma delas consegue reproduzir em conjunto os padrões de acesso, a repartição das operações e as propriedades do conteúdo registados numa execução real.

Replicar o _trace_ não é, porém, suficiente, dado que os registos disponíveis, em _traces_ como os do @fiu, cobrem uma fração ínfima do tempo necessário para um dispositivo moderno atingir o regime estacionário. Esta secção averigua se a reprodução é fiel e em que medida as estratégias de extensão preservam as características originais.

=== _Traces_ Utilizados

Os _traces_ utilizados provêm do repositório do @fiu e resultam da instrumentação de três servidores em produção, apresentando a estrutura já descrita no @chapter2. Cada registo inclui uma assinatura do conteúdo, componente indispensável ao presente trabalho, pois é através dela que se reconstitui a distribuição de duplicados sem aceder aos dados originais @koller2010.

#figure(
  doc_table(
    columns: (1fr, 0.7fr, 0.6fr, 0.6fr, 0.7fr, 0.7fr),
    align: (x, y) => if x == 0 or y == 0 { horizon + left } else { horizon + right },
    header: ([_Trace_], [Registos], [Volume], [Escritas], [Duplicados], [Cargas]),
    [homes], [2.0 M], [7.7 GiB], [92%], [36.5%], [12 e 14],
    [webmail], [0.7 M], [2.6 GiB], [96%], [37.7%], [15],
    [cheetah], [22.7 M], [86.6 GiB], [52%], [22.3%], [13],
  ),
  caption: [_Traces_ utilizados, com as proporções medidas nos primeiros 100 mil registos]
) <traces-perfil>

O primeiro aspeto a reter da @traces-perfil é a dimensão destes ficheiros, dado que mesmo o cheetah, de longe o mais extenso, cobre apenas 11.5% dos 752.91 GiB que uma carga da campanha movimenta, ficando os restantes dois abaixo de 1.1%. Sem extensão, nenhum deles conduziria o dispositivo a um regime estacionário.

Merece destaque a distância entre servidores, com a proporção de escritas a variar dos 96% do webmail aos 52% do cheetah, único dedicado a servir páginas _web_ e por isso o único onde as leituras pesam quase tanto quanto as escritas.

Convém realçar que qualquer destas percentagens é configurável no @fio e no Vdbench, dado tratar-se de rácios globais. A limitação não reside portanto no valor em si, mas no facto de cada percentagem resumir a execução inteira a um único número, ocultando a forma como a grandeza evolui entre o primeiro e o último pedido @fio_docs @vdbench.

=== Fidelidade da Reprodução

Uma carga baseada em _traces_ atravessa dois momentos distintos, pois enquanto o ficheiro de _trace_ dispõe de registos por consumir cada pedido corresponde ao que foi observado no servidor original, ao passo que, esgotado o ficheiro, é a extensão que assume a geração. A fidelidade exigida a cada um difere por conseguinte, tratando-se no primeiro de reprodução literal e no segundo de semelhança estatística.

A @traces-offsets, a @traces-operacoes e a @traces-assinaturas acompanham a execução do _trace_ homes com as três estratégias, assinalando uma linha vertical tracejada a transição ao fim dos primeiros 100 mil registos, aos quais a experiência foi limitada apesar de o ficheiro disponibilizar mais de dois milhões. Até essa linha as três estratégias coincidem ponto a ponto, pelo que essa fase surge representada por uma única série a cinzento.

O eixo horizontal conta os pedidos submetidos, em milhares, sendo recolhida uma medição a cada mil. O _offset_ constitui uma propriedade do pedido individual e apresenta-se por isso tal como foi submetido, ao passo que as duas restantes grandezas são proporções, as quais apenas se definem sobre um conjunto de pedidos.

Daí que estas últimas sejam calculadas sobre os dois mil pedidos centrados em cada ponto, janela suficientemente estreita para revelar as oscilações e suficientemente larga para que a proporção não varie entre extremos por efeito de meia dúzia de pedidos.

Convém realçar que as três estratégias partilham a primeira metade por construção, pelo que a leitura destas figuras deve concentrar-se no que sucede depois da linha vertical tracejada, onde cada estratégia passa a responder pela totalidade dos registos submetidos.

*Padrões de acesso.* A primeira dimensão a examinar é o _offset_ de cada pedido, do qual depende a localidade dos acessos e, por consequência, o partido que o dispositivo consegue tirar de leituras antecipadas e de escritas contíguas.

#figure(
  trace-lines("traces-offsets.csv", ylabel: [_Offset_ acedido (GiB)]),
  caption: [Evolução dos acessos ao longo da execução do _trace_ homes]
) <traces-offsets>

A @traces-offsets revela um percurso irregular, com quase metade dos pontos a recair na vizinhança dos 328 GiB enquanto os restantes se espalham entre o primeiro gigabyte e os 431 GiB, alternância entre concentração e dispersão que as distribuições convencionais dificilmente produzem.

Embora as extensões por repetição e por amostragem devolvam nuvens semelhantes à original, tal semelhança não deve ser tomada por equivalência. A repetição submete os _offsets_ pela ordem observada, nada acrescentando ao segundo ciclo, enquanto a amostragem os extrai do reservatório e os sorteia de novo, conservando o conjunto de endereços mas não a ordem por que foram visitados.

A consequência é relevante, dado que blocos acedidos pelo servidor em instantes próximos passam a surgir dispersos por toda a execução, sendo precisamente essa proximidade que as _caches_ exploram intensamente @paulo2014.

Já a extensão por regressão rompe com ambas, desenhando uma única reta que parte dos 357 GiB e recua 775.8 KiB a cada pedido, visto o _offset_ ser extrapolado a partir do último valor do _trace_ e do passo médio entre registos. Sendo esse passo negativo, a extensão percorre o dispositivo em sentido inverso, substituindo o padrão irregular do servidor por um varrimento sequencial.

Assim sendo, das três estratégias apenas a repetição preserva a localidade original, sendo de admitir que as restantes produzam, na segunda metade da execução, um padrão de acessos cujo efeito no dispositivo pouco tem em comum com o do servidor instrumentado.

*Repartição das operações.* A segunda dimensão respeita ao tipo de cada pedido, cuja proporção determina o caminho percorrido dentro do sistema de armazenamento. Uma leitura obriga a localizar o bloco e a trazê-lo do dispositivo sempre que este não se encontre em _cache_, ao passo que uma escrita atravessa a compressão e a deduplicação antes de ser confirmada, sendo o dado efetivamente gravado mais tarde.

#figure(
  trace-lines("traces-operations.csv", ylabel: [Escritas na janela (%)]),
  caption: [Evolução da repartição das operações ao longo da execução do _trace_ homes]
) <traces-operacoes>

A repartição das operações é a dimensão que melhor sobrevive à transição, oscilando na @traces-operacoes entre os 76% e os 100% de escritas durante a reprodução, oscilação que a extensão por repetição devolve intacta enquanto a amostragem a achata numa linha constante nos 91.5%. Este valor coincide com a média do _trace_, do que se conclui reter a _alias table_ apenas a frequência com que cada tipo de operação ocorre, tomada isoladamente e sem memória da ordem por que os pedidos se sucediam.

O comportamento da extensão por regressão exige atenção ao modo como a operação é representada, dado que o _trace_ a codifica através do valor numérico do respetivo tipo, correspondendo o zero à leitura e o um à escrita.

Ora o modelo linear devolve um número real que é depois arredondado e limitado a esse domínio, e sendo o _trace_ homes dominado por escritas o valor previsto parte de 1.20 e desce até 0.95 ao longo dos 100 mil registos sintéticos, intervalo em que o arredondamento conduz invariavelmente ao valor um.

A série fixa-se portanto nos 100% e a carga deixa de emitir um único pedido de leitura, ficando por exercitar metade do efeito que o conteúdo duplicado produz, dado que a deduplicação tanto evita escritas de blocos já presentes como permite satisfazer acessos a partir de conteúdo que a _cache_ retém @koller2010.

*Duplicados de conteúdo.* Resta a dimensão que motiva o recurso a estes _traces_, ou seja, a repetição de conteúdo. Ao contrário das duas anteriores, esta não se lê no pedido em si mas na assinatura que o acompanha, sendo a distribuição dessas repetições ao longo do tempo, e não apenas a sua quantidade total, que determina aquilo que a deduplicação consegue eliminar.

#figure(
  trace-lines("traces-signatures.csv", ylabel: [Duplicados na janela (%)]),
  caption: [Evolução das assinaturas de conteúdo ao longo da execução do _trace_ homes]
) <traces-assinaturas>

A @traces-assinaturas apresenta a percentagem de blocos repetidos a variar entre os 21% e os 46% ao longo da reprodução, do que se depreende distribuírem-se os duplicados de forma desigual no tempo, alternando períodos em que o mesmo conteúdo é reescrito sucessivas vezes com outros em que quase todos os blocos são distintos.

Uma taxa global de 36.5%, como a que o @fio e o Vdbench admitem, descreve a média destes períodos mas não a alternância entre eles, sendo esta que determina se um índice parcial de deduplicação ainda retém o duplicado no momento em que a cópia é submetida @paulo2014.

A extensão por repetição volta a submeter os identificadores de bloco pela mesma ordem, pelo que a curva da segunda metade reproduz exatamente a da primeira. Importa realçar, no entanto, que a medição incide sobre a janela e não sobre a execução completa, dado que a totalidade do conteúdo do segundo ciclo já se encontra em disco e é por isso integralmente duplicado.

Por outro lado, a extensão por amostragem produz um resultado aparentemente contraditório, visto a proporção medida na janela descer para 9.9%, contra os 31% da reprodução, enquanto a proporção calculada sobre a totalidade dos registos sintéticos sobe para 54.7%, acima dos 36.5% do próprio _trace_.

A explicação reside na dimensão do reservatório, que retém cerca de 63 mil identificadores distintos dos quais a extensão sorteia 100 mil de forma independente, pelo que os mais frequentes voltam a sair repetidamente ao longo da execução e elevam a contagem global, ao passo que duas ocorrências do mesmo identificador ficam em média muito afastadas entre si e raramente caem na mesma janela.

Deste modo, a amostragem preserva a quantidade de duplicados mas destrói a sua concentração temporal, e é esta última que condiciona o proveito retirado pelos mecanismos de deduplicação.

Por fim, a extensão por regressão anula os duplicados por completo, dado que o identificador de bloco é previsto por um modelo linear no _offset_, o qual progride de forma estritamente monótona, do que resulta uma sequência de identificadores igualmente monótona onde valor algum se repete.

Um sistema de armazenamento avaliado nestas condições suporta o custo de consultar e manter a tabela de deduplicação sem jamais registar uma eliminação, sendo por isso medido no seu pior caso.

*Comparação entre estratégias.* Confrontando com o previsto no @chapter3, as extensões por repetição e por amostragem comportam-se conforme antecipado, conservando a repetição todas as correlações à custa de uma periodicidade estrita, enquanto a amostragem retém apenas as distribuições marginais de cada dimensão.

Já a extensão por regressão não confirma a expectativa de capturar as dependências entre dimensões, isto porque o identificador de bloco resulta de uma função de _hash_ sem relação linear com o _offset_, acabando a estratégia mais sofisticada por ser a menos variável das três.

Daí que a escolha da estratégia deva depender da propriedade que se pretende exercitar, sendo a repetição preferível quando importa preservar a localidade e o conteúdo, e a amostragem quando se procura variabilidade sem compromisso com a ordem original.

Em suma, a reprodução é fiel enquanto o ficheiro de _trace_ dura, no entanto nenhuma das estratégias de extensão consegue prolongá-la sem sacrificar alguma das propriedades originais, o que responde à Q4 de forma afirmativa quanto à reprodução e apenas parcial quanto à extensão. Até aqui o _trace_ foi tratado como uma carga a reproduzir e a prolongar no tempo, restando averiguar o que sucede quando dele se aproveita apenas parte.

== Combinação de _Traces_ com Geração Sintética <trace-hybrid>

A secção anterior tratou o _trace_ como uma carga indivisível, cuja reprodução se procura prolongar no tempo, no entanto o Prismo admite ainda um uso distinto, assente no princípio enunciado no @chapter3 de que um _trace_ pode servir de fonte a cada dimensão do pedido tomada isoladamente @tracegen2024 @gracia-tinedo2015.

Neste paradigma, já não se trata de estender a duração do _trace_ mas a sua utilidade, extraindo dele, por exemplo, apenas os acessos e gerando sinteticamente as operações e o conteúdo, o que permite combinar a dimensão real que interessa estudar com dimensões controladas. Esta secção averigua se tal combinação altera o comportamento do sistema de armazenamento face à reprodução integral do _trace_, e de que modo esta capacidade distingue o Prismo das ferramentas de referência.

=== Desempenho das Cargas Híbridas

O confronto incide sobre as cargas que extraem do _trace_ as três dimensões e aquelas que dele retiram apenas uma, designadas por isso de híbridas. As cargas 14 e 15 assentam por inteiro no _trace_, ao passo que a 12 e a 13 conservam somente uma dimensão real e geram sinteticamente as restantes, extraindo a primeira os acessos do homes sobre operações sintéticas e a segunda a repartição das operações do cheetah sobre uma distribuição Zipfian.

Convém realçar que a extensão temporal não fica de fora deste confronto, visto as cargas 14 e 15 prolongarem o homes e o webmail através das estratégias da @trace-eval e a carga 12 estender por amostragem os acessos do homes. Sendo estes _traces_ inferiores a 1.1% do volume movimentado, parte substancial de cada execução decorre sob extensão, embora o débito não tenha sido separado por fase, o que impede isolar o contributo desta face ao da reprodução.

Os valores da @traces-iops resultam de execuções sobre o @zfs através da interface POSIX, pelo que devem ser confrontados com os da @data-properties e nunca com os da @io-interfaces. Além disso, apresentam-se unicamente os valores do Prismo, dado que nenhuma das ferramentas de referência replica _traces_ desta natureza @fio_docs @vdbench.

#figure(
  tool-bars("traces-iops.csv", ylabel: [Milhares de @iops],
            width: 8.5cm, height: 4.6cm, legend: false),
  caption: [Débito de operações do Prismo nas cargas baseadas em _traces_]
) <traces-iops>

As quatro cargas distribuem-se entre as 3485 e as 4169 operações por segundo, sendo a maior diferença entre duas delas inferior ao desvio padrão da carga 12, pelo que o critério estabelecido na @validation obriga a tratá-las como equivalentes.

As cargas híbridas ladeiam as restantes, ficando a 12 abaixo de ambas e a 13 acima, distribuição que afasta qualquer efeito sistemático decorrente da substituição de dimensões reais por sintéticas.

Além disso, a carga 12 é a mais dispersa e a única dominada por leituras, aproximando-se por aí da carga 04, a mais lenta de toda a linha de base do @zfs, o que sugere ser a proporção de leituras, e não a proveniência dos acessos, a condicionar o débito.

Esta leitura é corroborada pelo confronto com a linha de base do @zfs apresentada na @impacto-baseline, dado que o débito da carga 05 se situa dentro do intervalo de dispersão de cada uma das quatro, ficando estas por seu turno 85% acima da carga 04, composta exclusivamente por leituras.

As cargas 14 e 15 submetem conteúdo genuinamente duplicado, ao passo que as híbridas escrevem blocos aleatórios, sem que daí resulte vantagem para as primeiras. O resultado é consistente com o observado na @dedup-section, onde a introdução de duplicados também não alterou o débito do @zfs, reforçando a leitura aí avançada de não ser o dispositivo o recurso que limita a execução nesta configuração.

Deste modo, o débito não constitui a grandeza através da qual uma carga baseada em _traces_ se distingue de uma sintética, visto qualquer delas se situar na banda já coberta pelas secções anteriores. O que verdadeiramente as separa é a estrutura temporal do conteúdo e dos acessos, cuja influência a instrumentação adotada não permitiu isolar.

Determinar esse efeito exigiria acompanhar o espaço ocupado em disco e a taxa de acerto da tabela de deduplicação ao longo da execução, grandezas cuja recolha ficou fora desta campanha, constituindo a sua ausência a principal limitação desta subsecção.

=== Comparação de Capacidades

Independentemente dos valores medidos, importa situar o Prismo face às ferramentas de referência quanto àquilo que cada uma consegue reproduzir a partir de um _trace_, comparação que a subsecção anterior tornou impossível ao nível do débito precisamente por nenhuma das outras duas oferecer mecanismo equivalente.

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
  caption: [Capacidades de replicação de _traces_ suportadas por cada ferramenta]
) <traces-capacidades>

Conforme evidencia a @traces-capacidades, o Prismo é a única das três ferramentas a reproduzir em conjunto os acessos, as operações e o conteúdo de um _trace_, visto o @fio admitir apenas a repetição de um padrão de acessos previamente descrito e o Vdbench não oferecer mecanismo equivalente @fio_docs @vdbench.

Merece destaque a combinação com geração sintética, que permite isolar o contributo de cada dimensão ao substituir as restantes por valores controlados, sem a qual não seria possível determinar se um comportamento observado decorre do padrão de acessos ou das propriedades do conteúdo.

Em suma, a combinação de dimensões reais com dimensões sintéticas não alterou o débito do @zfs face à reprodução integral dos _traces_, residindo o seu valor não no débito mas na possibilidade de isolar o contributo de cada dimensão, capacidade que nenhuma das ferramentas de referência oferece. Estabelecido este último eixo, importa agora reunir as conclusões dispersas ao longo do capítulo.

== Síntese e Discussão Geral <evaluation-synthesis>

O capítulo percorreu cinco eixos de avaliação, desde a validação da própria ferramenta até à combinação de _traces_ com geração sintética, importando agora confrontar os resultados entre si e apurar o que deles decorre para a avaliação de sistemas de armazenamento.

=== Síntese dos Resultados

Numa análise geral, obtém-se uma hierarquia que nenhuma secção isolada poderia estabelecer. À cabeça surge a interface de @io, cuja escolha altera o débito da leitura aleatória da carga 04 em até 19× no Prismo, e 30× no @fio, entre o POSIX e as interfaces assíncronas, conforme a @io-interfaces, seguida da ordem pela qual os blocos são percorridos, que separa a leitura sequencial da aleatória por 8.6× na @validation.

Com uma influência bastante menor surgem a concentração dos acessos e as propriedades do conteúdo. A primeira explica os 14% que, na mesma secção, separam a distribuição Zipfian da uniforme, enquanto a segunda corresponde aos 31% apurados na @data-properties. Esta hierarquia deve, porém, ser interpretada com alguma cautela, dado que apenas este último efeito foi medido sobre sistemas de ficheiros, enquanto os restantes correspondem ao dispositivo em acesso direto.

Quanto ao conteúdo, o resultado mais consequente não reside no ganho em si, mas na sua dependência da forma da distribuição, dado que na @data-properties o Prismo e o @fio submeteram cargas com idêntica compressibilidade média e obtiveram no @zfs débitos que divergem em 31%. O sistema responde assim à forma como a redutibilidade se reparte pelos blocos e não ao seu valor agregado, propriedade que uma taxa única é incapaz de exprimir.

Fica assim respondida a Q5, visto a avaliação produzida pelo Prismo coincidir com a dos _benchmarks_ existentes nas cargas genéricas e afastar-se dela precisamente onde o conteúdo e os _traces_ intervêm, o que fundamenta o V4, dado a divergência de 31% no @zfs decorrer da forma da distribuição e não da instrumentação, cuja equivalência a @validation demonstrou. A esta divergência junta-se a capacidade de reproduzir, estender e decompor um _trace_ nas suas dimensões, que nenhuma ferramenta de referência oferece.

Já a reprodução de _traces_ confirmou-se fiel enquanto o ficheiro de _trace_ dispõe de registos, revelando a @trace-eval que nenhuma estratégia de extensão prolonga a execução sem sacrificar alguma propriedade, a repetição a variabilidade, a amostragem a concentração temporal dos duplicados e a regressão o conteúdo repetido na sua totalidade.

Por fim, um aspeto atravessa todo o capítulo e condiciona aquilo que dele se pode concluir, ou seja, a dispersão das medições, que se situa entre 0.50% e 2.71% sobre o dispositivo em acesso direto e entre 10% e 18% sobre os sistemas de ficheiros.

Uma vez que só é considerada efetiva a diferença que excede a dispersão, sobre o dispositivo basta que duas medições difiram mais de 3%, enquanto sobre os sistemas de ficheiros é necessária uma diferença próxima dos 18%, o que explica que a divergência de 31% no @zfs seja a única de débito da @data-properties a superar esse limiar.

=== Resultados Contrários à Expectativa

Dois dos resultados obtidos contrariam aquilo que a literatura ou o próprio desenho experimental faziam prever, importando a sua enumeração conjunta tanto quanto a das confirmações, dado ser dela que decorrem as direções de trabalho futuro.

*Duplicados sem efeito no débito.* Esperava-se que a introdução de duplicados elevasse o débito do @zfs, dado este dispor de deduplicação _inline_ e a @conteudo-dup confirmar que o conteúdo submetido continha as cópias configuradas. A @impacto-dedup regista porém diferenças inferiores a 2% face à carga anterior, explicáveis quer pela compressibilidade inferior da carga 11, quer por o desempenho estar limitado pelo processamento no anfitrião, conforme a @impacto-recursos sugere.

*Regressão sem capacidade preditiva.* Esperava-se que a extensão por regressão, apresentada no @chapter3 como a mais sofisticada das três, preservasse as dependências entre dimensões. A @traces-assinaturas revela porém que esta anula por completo os duplicados, sendo na prática a menos viável das três estratégias.

A causa reside na natureza do identificador de bloco, que resulta de uma função de _hash_ sem relação linear com o _offset_, pelo que o ajuste por mínimos quadrados colapsa numa proporcionalidade e a sequência gerada, sendo estritamente monótona, jamais reincide num valor já submetido.

=== Limitações <limitations>

Nenhuma campanha experimental esgota o espaço de configurações possíveis, pelo que a leitura dos resultados apresentados deve ter presente um conjunto de limitações, umas decorrentes das condições em que a campanha decorreu, outras do desenho das próprias cargas, e as restantes do material disponível para replicação, a que se juntam algumas experiências que complementariam os resultados obtidos.

*Âmbito experimental.* A avaliação decorreu sobre uma única máquina e um único dispositivo, correspondendo além disso cada configuração a uma execução, pelo que a dispersão reportada ao longo do capítulo traduz a estabilidade da medição e não a variabilidade entre execuções independentes.

*Controlos imperfeitos.* A linha de base da @data-properties recorre à carga 06, que partilha com as cargas 10 e 11 a distribuição de acessos mas não a repartição das operações. Um controlo estrito exigiria uma variante da carga 10 com redução nula, que das restantes diferisse apenas no conteúdo.

Do mesmo modo, as cargas 10 e 11 diferem na presença de duplicados mas também na compressibilidade média, 30% contra 22%, o que impede o isolamento do contributo da deduplicação e cuja resolução passaria por igualar essa propriedade entre ambas.

*Grandezas não medidas.* O espaço efetivamente ocupado em disco não foi acompanhado ao longo das execuções, por limitações de tempo da campanha, grandeza que teria permitido confirmar quando e em que medida as otimizações foram acionadas, e cuja ausência limita as conclusões alcançadas sobre a deduplicação.

Também a latência reportada não distingue o tempo decorrido no dispositivo daquele que é consumido dentro da própria ferramenta, ausência que deixou por confirmar a explicação avançada na @io-interfaces para a diferença observada entre o Prismo e o @fio nas interfaces assíncronas.

*Material disponível.* Os _traces_ disponíveis constituem outra limitação, quer pela idade quer pela dimensão, cobrindo o mais extenso deles apenas 11.5% do volume que uma carga da campanha movimenta, o que confere à extensão sintética um peso determinante naquilo que é medido.

*Experiências adicionais.* Ficam por realizar algumas experiências que complementariam os resultados obtidos, desde pares de cargas que difiram numa única propriedade do conteúdo, capazes de isolar o contributo da deduplicação, à comparação entre interfaces sob cargas abaixo da saturação, onde as diferenças tenderão a manifestar-se na latência e não no débito.

Igualmente interessantes seriam a instrumentação do ciclo do consumidor, que separaria o tempo passado no dispositivo do tempo consumido no Prismo, e execuções sobre o Btrfs suficientemente longas para que o bees processe os dados escritos, permitindo avaliar a deduplicação _offline_ que esta campanha deixou de fora.

=== Sumário

Ao longo do capítulo ficou estabelecido que o Prismo iguala as ferramentas consagradas em cargas genéricas, com medições estáveis e sem que os seus componentes limitem a avaliação, reproduzindo além disso com desvios inferiores a 1.2% as distribuições de duplicados e compressibilidade configuradas.

Sobre esta base, a descrição do conteúdo por distribuições revelou no @zfs um débito que diverge em cerca de um terço do obtido com uma taxa única de compressibilidade, o suporte a múltiplas interfaces expôs diferenças de até 19× e a importância de as configurar de acordo com o _hardware_ e o paralelismo da carga, e a replicação de _traces_ permitiu reproduzir, estender e decompor uma carga real nas suas várias dimensões, algo que nenhuma das ferramentas de referência oferece.

Daqui decorre a conclusão que sustenta o trabalho, ou seja, a de ser a fidelidade do conteúdo e dos acessos condição para que os valores medidos correspondam ao regime em que o sistema opera.

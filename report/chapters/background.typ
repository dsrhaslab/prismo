#import "../utils/functions.typ" : raw_code_block

== Background e Trabalho Relacionado <chapter2>

Este capítulo tem por objetivo apresentar os conceitos e trabalho relacionado que sejam relevantes para a compreensão do projeto, neste sentido, inicialmente é apresentada uma breve descrição das técnicas de benchmarking atuais, referindo as métricas relevantes para a avaliação do sistema de armazenamento, bem como as caracteristicas singulares entres workloads sintéticas e baseadas em traces.

Posteriormente, estudam-se as técnicas de deduplicação e compressão, permitindo compreender como é possível gerar conteúdo que respeite estas propriedades, além de estender traces mantendo as características originais dos dados.

Serão também analisadas as últimas técnicas para geração de conteúdo realista e as soluções de benchmark amplamente utilizadas pela comunidade, procurando perceber se os resultados por estas apresentados permitem uma avaliação realista dos sistemas de armazenamento.

Desta forma, procura-se evidenciar a complexidade da geração de datasets e a sua importância para uma avaliação rigorosa do sistema de armazenamento. Finalmente, o capítulo termina com uma síntese da informação recolhida, procurando desvendar os impactos que isso terá na arquitetura da proposta de solução.

=== Background

Nesta secção são apresentados os conceitos essenciais relacionados com benchmarking, interfaces de @io e geração de conteúdo, tendo por objetivo fornecer o contexto necessário para compreender as técnicas e decisões que influenciam a avaliação e o desempenho dos sistemas de armazenamento.

Convém mencionar que a proposta de solução funciona ao nível do bloco, portanto, e por motivos de simplicidade, os conceitos serão apresentados tendo isso em conta, embora a granularidade não lhes seja diretamente incutida.

==== Benchmarking

O benchmarking de sistemas de armazenamento passa por aplicar cargas de trabalho controladas e reprodutíveis, consentindo assim a avaliação do desempenho, eficiência e escalabilidade das soluções de @io. Mais tarde os dados recolhidos são utilizados para decidir entre arquiteturas, interfaces de acesso e configurações de hardware/software que melhor respondem às necessidades do ambiente de produção.

Entre as métricas recolhidas, destacam-se a latência (intervalo entre submissão e conclusão), débito (quantidade de dados transferidos por unidade de tempo) e @iops (operações de @io realizadas por unidade de tempo), sendo claro que, para além dos componentes técnicos, as características da workload influenciam o valor das métricas.

Por fim, a representatividade das workloads corresponde a um desafio central do benchmarking, pois testes sintéticos tendem a não refletir fielmente comportamentos e padrões observados em ambientes reais. Além disso, certas soluções de @io foram desenhadas para favorecer determinadas características, por exemplo deduplicação e compressão, como tal uma workload genérica é incapaz de extrair o máximo das capacidades do sistema.

===== Traces

A melhor forma de simular workloads realistas é saber exatamente em que consistem essas workloads, por conseguinte um trace oferece uma visão detalhada de todas as operações que ocorrem no sistema, permitindo conhecer os momentos em que as aplicações e processos interagiram com o sistema de armazenamento.

Idealmente os traces são obtidos em ambiente de produção, dado que somente aí observamos o sistema sob condições reais de uso, portanto faz todo o sentido que o benchmark consiga replicar esse ambiente para termos uma noção do desempenho esperado.

Infelizmente existem pouquíssimos traces disponíveis, e os do @fiu já contam com imensos anos, não sendo a sua replicação viável em máquinas modernas, isto por terem sido obtidos em dispositivos obsoletos aos dias de hoje.

#figure(
  raw_code_block[
  ```
  <timestamp> <file_id> <process> <offset> <size> <op> <version> <0> <hash>
  89967404265337 4253 nfsd 508516672 8 W 6 0 88b93b628d84082186026d9da044f173
  89967404311353 4253 nfsd 508516680 8 W 6 0 b5e9f4e5ab62a4fff5313a606b0ad4e3
  89967404359328 4253 nfsd 508516688 8 W 6 0 e6434714a2358bc5f55005d6c5502d80
  89968195447404 20782 gzip 283193112 8 R 6 0 ef58ea75660587908a49b83a338bff34
  89968195487477 20782 gzip 283193120 8 R 6 0 980f03b2810fd0267bea07bc4f0c78fa
  89968195487477 20782 gzip 283193120 8 R 6 0 980f03b2810fd0267bea07bc4f0c78fa
  ```
  ],
  caption: [Estrutura do trace]
)

A estrutura do trace é descritiva das operações efetuadas, sendo para cada uma identificado o timestamp, processo responsável e dados da operação de @io, como offset, tamanho e tipo de operação. Por fim, cada registo conta com uma assinatura, pois sendo este um trace de deduplicação, é necessário conhecer o bloco alvo da operação, o que permite posteriormente identificar duplicados.

Em conclusão, os traces permitem compreender detalhadamente como os dados são lidos, escritos e manipulados ao longo do tempo. No entanto, para interpretar corretamente estes registos e avaliar o seu impacto no desempenho do sistema, é essencial entender o funcionamento da stack de @io, uma vez que é através desta que as operações são processadas e geridas.

==== Stack de I/O

Sempre que uma aplicação solicita operações de @io, as mesmas são obrigadas a fluir através de várias camadas a fim de garantir segurança e eficiência, contribuindo para ligar a aplicação ao hardware de modo totalmente abstrato.

Posto isto, ao ser invocada uma system call, por exemplo `READ` ou `WRITE`, o kernel é notificado da existência de uma operação de @io, havendo assim uma transição de user para kernel space. Já dentro do kernel, o pedido é recebido pelo @vfs, que fornece uma interface independente do sistema de ficheiros, sendo este último responsável por traduzir a operação em acessos a blocos lógicos e verificar se os dados encontram-se em cache, em caso afirmativo o pedido é satisfeito imediatamente e sem aceder ao disco.

Perante a necessidade de aceder ao disco, o pedido é encaminhado para a camada de blocos, de modo a agrupar e escalonar os pedidos de @io o mais eficientemente possível. Por fim, o pedido é transmitido ao driver do dispositivo, que conhece os detalhes específicos do hardware e por isso converte o pedido em instruções claras ao controlador de disco.

#figure(
  image("../images/stack.png", width: 60%),
  caption: [Visão alto nível da stack de I/O em linux @ren2023]
) <iostack>

Em suma, este fluxo permite que as aplicações realizem operações de @io de modo transparente, enquanto o sistema operativo gere a complexidade, desempenho e segurança dos acessos ao dispositivo de armazenamento.

==== Interfaces de I/O

Devido aos imensos passos realizados no interior de stack de @io, a execução dos pedidos tende a ser bastante demorada, o que contribui para uma penalização da performance das aplicações. Tendo isto em mente, surgiram diversas @api:pl que trazem otimizações para cenários específicos, e como tal estabelecem compromissos entre simplicidade, desempenho e controlo.

===== Posix

De todas a mais simplista, esta interface funciona através das system calls `open`, `read`, `write` e `close`, o que a torna bastante portável e amplamente utilizada entre os sistemas UNIX. Por outro lado, acarreta a desvantagem das chamadas serem síncronas e realizar cópias entre user e kernel space, consequentemente penaliza aplicações com workloads intensivas.

===== Uring

Recentemente as interfaces assíncronas têm ganho popularidade por conseguirem submeter novos pedidos enquanto os anteriores ainda não foram concluídos, além disso possibilitam a execução de pedidos em batch como meio para diminuir as chamadas ao sistema, afinal o custo da mudança de contexto entre user para kernel space é deveras elevado.

#figure(
  image("../images/uring.png", width: 70%),
  caption: [Visão alto nível das queues circulares do uring @rust_iouring_async]
) <uring>

Inicialmente  a @sq encontra-se vazia e por isso disponível para receber @sqe, quando a aplicação julgar conveniente ou a @sq ficar cheia é necessário realizar uma syscall de `submit`, informando o kernel sobre a existência de @sqe disponíveis para submissão, neste momento ocorre uma mudança de contexto, no entanto a aplicação pode continuar a submeter novos pedidos caso encontre espaço disponível na @sq.

Assim que o kernel termina o pedido resultante de uma @sqe, o mesmo origina uma @cqe com os dados resultantes da operação de @io, sendo este inserido na @cq de modo a informar a aplicação sobre a conclusão do pedido. Convém realçar que a aplicação é responsável por recolher as @cqe, caso contrário a @cq ficará cheia e o kernel bloqueará por não conseguir transmitir os resultados à aplicação.

Por fim, a interface suporta @dma através de buffers registados, ou seja, em vez dos dados serem constantemente copiados entre user e kernel space, a aplicação compromete-se a gerir uma zona de memória que o kernel confiará como sendo segura, daí que não possam haver modificações da memória entre a submissão e conclusão dos pedidos.

===== Libaio

De forma semelhante à interface anterior, esta também funcionar de modo assíncrono e permite a submissão de pedidos em batch, no entanto apenas atua com @io direto, conseguido através da flag `O_DIRECT`, e portanto torna-se muito limitada para os sistemas de ficheiros atuais.

Além disso, uma vez que são utilizadas syscalls AIO do kernel, os pedidos continuam a passar através da stack tradicional de @io, o que origina as penalizações de performance mencionadas anteriormente e das quais todas as interfaces referidas até ao momento sofrem.

===== SPDK

Com o objetivo de dar bypass ao kernel, esta interface possibilita acesso direto ao hardware a partir do user space, deste modo evita por completo as penalizações das system calls e interrupções que normalmente lhes estão associadas.

Ao utilizar um mecanismo de polling ativo, a latência entre pedidos é diminuída ao máximo em detrimento da utilização dos cores da @cpu. Deste modo, um runtime assíncrono é estabelecido às custas de um reactor, sendo depois submetidas operações de @io que o escalonador atribuiu aos cores corretos. Quando a operação é dada por terminada, o escalonador volta a atribuir um callback para execução, sendo que este contém o resultado da operação de @io.

Por fim, esta interface disponibiliza uma @bdev @api que abstrai as operações orientadas ao bloco, tornando-se por isso bastante conveniente para a implementação do protótipo, no entanto o modelo de concorrência entre threads acarreta algumas dificuldades de gestão comparativamente ao modelo tradicional em stack. Por estas razões, apenas sistemas onde a performance seja um fator crítico devem utilizar @spdk, caso contrário estaremos a tornar a aplicação menos portável sem necessidade.

===== Generalização

As interfaces de @io mencionadas apresentam modelos de funcionamento distintos, desde a forma como lidam com system calls e polling até à gestão de concorrência e callbacks. Estas diferenças tornam particularmente difícil a criação de um benchmark que suporte todas as interfaces de forma genérica, sem perder fidelidade ou desempenho.

Na prática, os benchmarks existentes são frequentemente desenvolvidos com foco numa interface específica, explorando otimizações próprias desse modelo. Por exemplo, as técnicas de polling ativo em @spdk ou submissão assíncrona em @uring são utilizadas para reduzir a latência e aumentar o débito, no entanto não se traduzem diretamente em interfaces tradicionais (POSIX). Como resultado, generalizar um benchmark implica sacrificar estas otimizações, podendo levar a resultados menos representativos do desempenho real de cada interface.

Esta realidade justifica por que motivo benchmarks que pretendem ser altamente precisos costumam ser otimizados para uma interface em particular, em vez de adotarem uma abordagem única e universal para todos os sistemas de @io.

==== Manipulação de Conteúdo

Embora as interfaces de @io desempenhem um papel fundamental na avaliação dos sistemas de armazenamento, o seu impacto é limitado quando as propriedades destes sistemas não são plenamente exercitadas. Diferentes interfaces podem medir latência e débito, porém não capturaram o efeito de otimizações como deduplicação e compressão se o conteúdo utilizado não refletir essas características.

Os sistemas modernos combinam deduplicação e compressão para otimizar espaço e desempenho. Por este motivo, gerar conteúdo que reproduza estas propriedades é extremamente relevante para benchmarks realistas. Antes de explorar a forma como este conteúdo é gerado, é necessário compreender em que consistem estas técnicas e como influenciam o comportamento do sistema de armazenamento.

===== Deduplicação

A deduplicação caracteriza-se por poupar espaço ao não escrever conteúdos redundantes, sendo aplicada numa grande variedade de contextos, que vão desde backup, archival e primary storage até à @ram. Uma visão geral do funcionamento deste processo está apresentada na @dedup.

#figure(
  image("../images/view.png", width: 80%),
  caption: [Visão geral do funcionamento da deduplicação]
) <dedup>

Sempre que um pedido de @io é submetido ao sistema, a stack de @io calcula a assinatura do bloco e consulta um índice responsável por estabelecer um mapeamento entre endereços físicos e lógicos, verificando assim a existência de duplicados. Caso a entrada já se encontre no índice, o bloco em questão é duplicado, como tal simplesmente será criado um apontador para a sua posição no disco, evitando uma escrita de conteúdo repetido. Consequentemente, nenhuma cópia será escrita, diminuindo os requisitos de armazenamento da aplicação.

Uma vez que este processo decorre na stack de @io, a execução do processo de deduplicação é completamente transparente à aplicação, afinal a visão lógica apresenta os dados solicitados pela camada superior, e portanto contém duplicados, enquanto a visão física - onde os dados são realmente armazenados - não permite tal.

Embora existam diversas granularidades de deduplicação, esta dissertação apenas aborda a orientada ao bloco, deste modo os dados são divididos em blocos de tamanho fixo, sendo realizado um padding em caso de necessidade e armazenados somente os blocos únicos. Por norma, quanto menor for o tamanho do bloco, melhor será a utilização do espaço de armazenamento, pois à partida serão detetadas mais cópias, no entanto isso acarreta custos ao nível computacional, visto ser necessário lidar com mais blocos, neste sentido é preciso encontrar um tamanho razoável, sendo 4096 bytes um padrão aplicado em diversos sistemas de armazenamento.

Fora isso, a técnica em questão pode ser aplicada em diferentes alturas e com índices variados, das quais se destacam os seguintes:

====== Deduplicação Inline

Nesta alternativa, os blocos duplicados são identificados no caminho crítico de @io, sempre que um pedido é realizado. Assim sendo, é calculada a assinatura do bloco e verificada na estrutura do índice a fim de determinar o endereço físico caso o bloco em questão já tenha sido registado. Não esquecer que o mapeamento e contador de referências devem ser atualizados antes do pedido ser dado como concluído.

Embora esta técnica consiga reduzir as operações de @io no disco subjacente e consequentemente aumentar o débito do sistema, a latência dos pedidos tende a aumentar devido às múltiplas repetições do processo anteriormente descrito. Daí que manter a performance e salvaguardar a latência seja um dos desafios na deduplicação inline.

====== Deduplicação Offline

Ao contrário da estratégia anterior, a deduplicação offline não interfere no caminho crítico de @io, os dados são escritos diretamente no disco, salvaguardando assim baixa latência entre pedidos. Na verdade, a deduplicação é realizada mais tarde e em segundo plano, por exemplo, em alturas de menor demanda do sistema de armazenamento.

Após a operação de escrita, os blocos são colocados numa fila de espera, onde um processo em background irá calcular as assinaturas e consultar o índice, em caso de duplicados, os mapeamentos lógicos são atualizados juntamente com os contadores de referências, e o espaço duplicado é libertado.

Apesar desta estratégia diminuir a latência dos pedidos, o consumo de armazenamento aumenta temporariamente, e como não reduz os pedidos ao disco, os ganhos no débito são marginais. Por outro lado, o processo em background pode trazer implicações de desempenho e consistência se não for agendado para o momento certo.

====== Índice Completo

Este índice caracteriza-se por conter as assinaturas de todos os blocos únicos submetidos ao sistema, sendo impossível perder oportunidades para encontrar duplicados, no entanto a estrutura subjacente tende a crescer imenso e torna-se difícil de manter em @ram, geralmente é transferida para o disco. Deste modo, workloads de backup e archival, que não exigem baixa latência, costumam adotar este índice.

====== Índice Parcial

Com o objetivo de tirar partido da localidade espacial e temporal, este índice armazena somente as informações relativas aos blocos mais recentes e populares, por conseguinte a estrutura de dados pode ser armazenada em @ram, o que permite diminuir a latência dos pedidos. Por outro lado, uma vez que o índice não contém todos os blocos, é possível que blocos antigos ou pouco populares possam não ser identificados como duplicados e portanto existirão cópias no sistema de armazenamento.

===== Compreensão

Os sistemas de armazenamento modernos aplicam compressão aos blocos únicos identificados pelo processo de deduplicação, assim a informação é codificada de modo mais eficiente, reduzindo a quantidade de bits necessários para representar os mesmos dados. Daqui obtém-se mais aproveitamento do espaço de armazenamento, o que diminui custos e aumenta a rapidez da transferência entre sistemas.

====== Entropia

A fim de conhecer o limite de compressão, a entropia consiste numa medida que reflete a incerteza ou aleatoriedade associada à informação, como tal baixa entropia implica a existência de padrões e uma oportunidade para comprimir, enquanto entropia elevada resulta da aleatoriedade dos dados, havendo por isso pouca margem de compressão.

$
  H = - sum_(i=0)^k p_i log_2(p_i)
$

A partir da fórmula da entropia, ficamos a conhecer o número médio de bits necessários para representar cada símbolo de forma ideal, onde $p_i$ estabelece a probabilidade do símbolo $i$, enquanto $log_2(p_i)$ a informação associada a esse mesmo.

Com o objetivo de esclarecer a fórmula, apresentam-se de seguida os cálculos relativos à string `banana`. Uma vez que o símbolo `a` repete-se três vezes, a sua probabilidade ($p_i$) equivale a $3/6 = 1/2$, raciocínio que aplicamos aos restantes símbolos.

$
  H = - (frac(log_2(1/6), 6) + frac(log_2(1/2), 2) + frac(log_2(1/3), 3)) = 1.46 #text("bits/símbolo")
$

Tendo em conta que a string é constituída por seis caracteres, $6 dot 1.46 = 8.76 #text("bits")$ corresponde ao limite teórico mínimo para codificar `banana` de forma ideal através de codificação ótima como Huffman ou Shannon-Fano.

====== Huffman Coding

A fórmula da entropia nada diz sobre a codificação dos símbolos, para isso é necessário recorrer a um algoritmo de codificação, neste caso abordamos o Huffman Coding, que permitem gerar códigos binários de tamanho variável para uma compressão sem perdas, nela os símbolos mais frequentes recebem códigos mais curtos enquanto os símbolos menos frequentes códigos mais longos.

#figure(
  image("../images/huffman.png", width: 60%),
  caption: [Árvore de Huffman @huffman_wiki]
) <huffman>

O funcionamento do algoritmo é bastante simples, inicialmente os símbolos são ordenados conforme a sua frequência, de seguida os dois primeiros da lista são agrupados numa árvore cuja raiz tem valor de frequência igual ao somatório, sendo esta colocada de novo na lista conforme o seu valor de frequência.

Ao repetir este processo, obtemos uma árvore com as frequências dos símbolos, deste modo os mais populares estão posicionados perto da raiz e portanto necessitam de menos bits para serem representados. Tendo em consideração a @huffman, a codificação de cada símbolo obtém-se ao atravessar a árvore, onde um salto para a esquerda corresponde a `0`, e para a direita `1`. Por conseguinte, o símbolo `a` possui o código `010`, enquanto `x` corresponde a `10010`.

====== LZ77

Huffman provou que o seu código é a forma mais eficiente de associar uns e zeros a caracteres individuais, é matematicamente impossível superar isso. Porém os algoritmos de compressão procuram identificar padrões que aumentem o tamanho dos símbolos e assim alcançar melhores taxas de compressão.

#figure(
  image("../images/lz77_sliding_window.png", width: 60%),
  caption: [Sliding window no algoritmo LZ77 @maxg_lz77]
) <lz77>

Na grande maioria dos algoritmos, incluído o LZ77, a identificação de padrões ocorre dentro de uma sliding window, assim sempre que um padrão é quebrado, a codificação dos símbolos anteriores é dada por um tuplo com o deslocamento, comprimento, e novo símbolo.

Deste modo o índice $(3,3,a)$ indica que é necessário deslocar três posições para trás e repetir os três símbolos seguintes, sendo no final adicionado um $a$ que originou a quebra do padrão dentro da sliding window.

Quanto maior for a sliding window, maior será a probabilidade de encontrar padrões, no entanto isso acarreta custos computacionais, daí que 65536 bytes seja um standard adotado em vários algoritmos. Por outro lado, reparamos que a codificação dos próprios índices através de Huffman Coding pode trazer melhorias de desempenho ao LZ77, de facto os algoritmos mais recentes, como o `DEFLATE` utilizado no `gzip`, aplicam este princípio.

Tendo por base estes conceitos, a geração de conteúdo que comprime X% torna-se deveras simples, bastando para isso fixar X% dos símbolos da string, enquanto os restantes devem ser completamente aleatórios e sem qualquer padrão possível de exploração. No fundo, procuramos o mínimo de entropia em X% da string, e o máximo de aleatoriedade entre os demais símbolos.

===== Ambientes Reais

Após a análise das técnicas de deduplicação e compressão, torna-se evidente que a geração de conteúdo que respeite estas propriedades pode ser definida a partir de distribuições estatísticas observadas em ambientes reais, sendo estas fundamentais para refletirem os padrões encontrados em sistemas de produção.

Em suma, uma replicação fiel destas características garante que os benchmarks exercitam os sistemas de armazenamento sob condições realistas, permitindo identificar com precisão o impacto das otimizações implementadas.
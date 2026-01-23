== Introdução <chapter1>

Com o crescimento de aplicações intensivas em @io, como inteligência artificial e análise de dados, a necessidade de processar e armazenar grandes quantidades de dados tornou-se cada vez mais relevante, consequentemente os sistemas de armazenamento evoluíram no sentido de oferecer uma maior eficiência de acessos e densidade dos dados.

Sistemas de armazenamento modernos, como o @zfs, disponibilizam uma série de recursos que procuram melhorar a performance das aplicações. Em particular, destaca-se a deduplicação - geralmente abreviada para dedup - que procura reduzir o espaço de armazenamento utilizado ao não reescrever dados que já existam. Por outro lado, a compressão também exerce um papel relevante neste sistema, permitindo aumentar a entropia dos dados ao eliminar aqueles que de algum modo podem ser obtidos através de uma amostra menor.

Neste caso em particular, estamos interessados num sistema orientado ao bloco, portanto a técnica de deduplicação tem como unidade básica um bloco de bytes, geralmente 4096 bytes, mas este valor pode variar conforme o sistema em questão. Da mesma forma, as técnicas de compressão são aplicadas ao nível do bloco (intrabloco), no entanto é possível que alguns sistemas realizem outra análise de entropia entre blocos (interbloco) para obter mais densidade.

Por outro lado, e com o objetivo de ultrapassar as limitações impostas pela stack de @io do kernel, nomeadamente as recorrentes mudanças de contexto, interrupções e cópias entre user e kernel space que tornam evidentes o gargalo de desempenho, surgiram várias @api que visam resolver esses mesmos problemas e geralmente funcionam sobre runtimes assíncronos.

Tendo em consideração a diversidade de técnicas que podemos encontrar num sistema de armazenamento e interfaces de @io existentes para interagir com o disco, torna-se difícil avaliar um qualquer sistema nos seus pontos específicos de funcionamento, isto porque nem todos os sistemas foram desenvolvidos para servir o mesmo fim, devendo assim procurar ajustar o benchmark e workload àquilo que o sistema oferece, pois somente assim será alcançada uma análise justa e correta do seu funcionamento.

=== Definição do Problema e Desafios

Devido ao baixo nível de manipulação em termos de deduplicação e compressão, os benchmarks atuais não proporcionam uma avaliação correta dos sistemas de armazenamento orientados a estas técnicas, contribuindo para análises incorretas dos mesmos. Entre os fatores que justificam esta deficiência convém destacar os seguintes:

+ A geração de conteúdo duplicado deve seguir uma determinada distribuição, o que por sua vez acarreta custos ao nível da seleção dos índices e transferência de dados entre buffers, consequentemente obtemos um menor débito, e no pior dos casos não somos capazes de saturar o disco.

+ Os sistemas de armazenamento comportam-se de modo diferente conforme a distribuição de duplicados e taxas de compressão, no entanto os padrões oferecidos pelo @fio são bastante simplistas por realizarem deduplicação sobre o mesmo bloco, o que aumenta a localidade temporal e espacial, beneficiando indevidamente o sistema de armazenamento.

+ Embora o @fio suporte a várias interfaces de @io síncronas e assíncronas, os restantes benchmarks oferecem uma gama muito limitada de @api, tornando-se a utilização do @fio praticamente obrigatória, no entanto este não disponibiliza de forma direta suporte para @spdk e portanto dificulta a avaliação de sistemas que funcionem diretamente sobre um @nvme, ou seja, com bypass da stack de @io.

+ Os sistemas de armazenamento evoluíram imenso nos últimos anos, consequentemente a replicação de traces antigos tornou-se praticamente instantânea e como tal não permite uma avaliação correta do sistema, além disso não existe um método conhecido para estender o trace à medida que o benchmark é executado, sendo que a extensão deverá salvaguardar as propriedades de deduplicação e compressão do trace original. No fundo isto resume-se a seguir dados reais enquanto for possível, e depois gerar sinteticamente para manter a avaliação durante o tempo que for necessário.

+ Perante a impossibilidade de acesso a dados reais, o benchmark é obrigado a seguir uma distribuição que defina padrões de acessos e operações a realizar, no entanto a maior parte das soluções é demasiado simplista e não permite testar padrões do género: `READ`, `WRITE`, `NOP`, `READ`, `FSYNC`.

Posto isto, nenhum benchmark é versátil o suficiente para permitir ao utilizador definir as suas distribuições de acesso ou taxas de duplicados, e assim avaliar corretamente as características alvo do sistema de armazenamento.

=== Objetivos e Contribuições

Perante os problemas mencionados anteriormente, esta dissertação tem como principal objetivo melhorar a eficiência e dotar duma maior flexibilidade os algoritmos para geração de conteúdo, em particular o respeito pelas taxas de deduplicação e compressão num sistema orientado ao bloco.

No entanto, tal condição é insuficiente para alcançar workloads realistas que efetuem uma avaliação correta do sistema, para isto é necessário replicar as propriedades de traces extraídos a partir de ambientes em produção, pois somente estes oferecem informações acerca das cargas reais.

Assim sendo, o protótipo do benchmark reúne todas as contribuições da dissertação numa arquitetura que torna as @api de @io completamente independentes da geração de conteúdo, deste modo o utilizador final usufrui das seguintes vantagens:

#underline(stroke: 1.5pt + red)[
+ Suporte a várias interfaces de @io síncronas e assíncronas, com possível configuração de parâmetros para alteração do comportamento do backend, consequentemente o benchmark torna-se mais portável entre sistemas de armazenamento e proporciona uma comparação justa do desempenho.

+ Geração de conteúdo realista a partir de distribuições de duplicados e compressibilidade, além disso os restantes parâmetros dos pedidos de @io são igualmente obtidos por distribuições ou padrões configuráveis pelo utilizador.

+ Replicação completa de traces do @fiu para avaliação do sistema de armazenamento sobre cargas de trabalho reais, permitindo a identificação de gargalos em ambientes de produção e reprodutibilidade dos resultados.

+ Replicação parcial de traces com geração de dados sintéticos para os parâmetros em falta, desta forma a replicação de operações de @io pode ser efetuada sobre diferentes padrões de acesso, adição de barreiras e outros critérios à escolha do utilizador.

+ Extensão de traces com dados sintéticos, após o conteúdo original do trace ser totalmente replicado, o mesmo é continuamente estendido pelo tempo necessário, salvaguardando as características e padrões encontrados originalmente nos dados.
]

// + O funcionamento do benchmark não depende de implementações concretas das interfaces de @io, o sistema apenas define uma interface para operações de @io, consequentemente qualquer programador pode estender o benchmark para usufruir de uma @api totalmente customizada.

// + A geração de conteúdo é dividida em vários módulos, cada um respeitante aos parâmetros da operação de @io (offset, tipo de operação e conteúdo), assim diferentes estratégias e distribuições dos parâmetros são combinadas para extrair mais versatilidade das workloads.

// + Cada um dos módulos definidos anteriormente define uma interface, portanto é permitido misturar dados sintéticos com traces, ou seja, uma workload pode replicar os bytes de um traces enquanto os restantes parâmetros da operação de @io são gerados sinteticamente enquanto o benchmark decorre.

Tendo um protótipo com estas características, contribuímos para que a avaliação dos sistemas de armazenamento seja efetuada como mais critério, afinal o utilizador tem a possibilidade de testar várias interfaces de @io e para cada uma selecionar workloads que avaliem determinadas características do sistema, tudo com o maior realismo possível, e não através de métodos simplistas como praticam as demais soluções.

=== Estrutura do Documento

Este documento encontra-se dividido em três capítulos, o #link(<chapter1>)[Capitulo 1] serve de introdução ao problema abordado na dissertação, procurando desvendar os desafios inerentes ao mesmo, sendo ainda apontadas as contribuições que se pretendem alcançar.

Já o #link(<chapter2>)[Capítulo 2] apresenta o background relativo à deduplicação e compressão, em particular as técnicas aplicadas para gerar conteúdo com estas propriedades, além disso a stack de @io é explorada para justificar as diferenças entre @api e perceber os pontos de melhoria em soluções de benchmark já estabelecidas (DEDISbench e DEDISbench++).

Por fim, o #link(<chapter3>)[Capitulo 3] corresponde a uma visão geral da arquitetura da solução, especificando os fluxos entre componentes e configurações necessárias à descrição da workload por parte do utilizador, concluindo-se com a descrição do plano para o restante da dissertação.
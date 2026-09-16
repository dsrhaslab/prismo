= Conclusões e Trabalho Futuro <chapter5>

A avaliação de sistemas de armazenamento depende da capacidade dos benchmarks em reproduzir as condições em que estes efetivamente operam, no entanto as ferramentas mais utilizadas pela comunidade descrevem o conteúdo através de taxas únicas e oferecem um suporte limitado à replicação de cargas reais. Deste modo, os valores medidos tendem a refletir um regime que pouco tem em comum com o de produção.

Foi com o objetivo de colmatar estas lacunas que se desenvolveu o Prismo, um benchmark que gera conteúdo com propriedades de deduplicação e compressão semelhantes às encontradas em ambientes reais, que exercita diferentes interfaces de @io sobre a mesma descrição de workload, e que permite replicar traces de sistemas em produção, prolongando-os para lá da sua duração original.

A avaliação experimental permitiu estabelecer, por um lado, que o Prismo mede com a mesma fiabilidade das ferramentas de referência quando as workloads são equivalentes, e por outro, que a forma como o conteúdo se distribui pelos blocos altera aquilo que se mede num sistema de armazenamento, efeito que uma descrição baseada em taxas globais é incapaz de revelar.

Nem todos os resultados corresponderam ao que se antecipava, tendo algumas otimizações produzido um efeito inferior ao esperado e outras um efeito contrário, a que acrescem limitações da própria campanha, como o facto de algumas workloads não diferirem num único parâmetro, o que impede atribuir as variações observadas a uma propriedade concreta. Nenhuma destas reservas põe, porém, em causa as duas constatações anteriores, dado assentarem em comparações onde apenas a ferramenta, e com ela o conteúdo submetido, variava.

Em suma, avaliar com rigor um sistema de armazenamento exige workloads fiéis tanto ao conteúdo como às cargas que este serve em produção, pois só assim os valores obtidos traduzem o comportamento que as aplicações efetivamente observarão, sendo precisamente esse o contributo que o Prismo procura oferecer à comunidade.

== Trabalho Futuro

O trabalho desenvolvido deixa em aberto um conjunto de questões que constituem a sua continuação natural, organizadas em duas frentes, a evolução do próprio protótipo e o aprofundamento da avaliação que o sustenta.

=== Evolução do Protótipo

As estratégias de extensão de traces podem ser aperfeiçoadas, de modo a que prolongar uma execução preserve melhor as propriedades do trace original, dado nenhuma das abordagens atuais o conseguir sem sacrificar alguma delas. Tal reduziria a distância entre as propriedades registadas no trace e aquelas que a workload continua a exercitar depois de o ficheiro se esgotar.

Além disso, a geração de conteúdo pode ir além dos duplicados exatos e da compressibilidade de cada bloco, passando a modelar a semelhança parcial entre blocos distintos, situação frequente em backups sucessivos ou em imagens de máquinas virtuais, onde blocos quase idênticos diferem apenas em pequenas porções. Atualmente, tais blocos são tratados como únicos, pelo que os sistemas que armazenam somente as diferenças entre eles não retiram vantagem alguma das workloads geradas, ficando essa capacidade por avaliar.

=== Aprofundamento da Avaliação

Grande parte desta frente decorre diretamente das limitações identificadas na @limitations, importando desde logo alargar a avaliação a outras máquinas, dispositivos e sistemas de armazenamento, com cada configuração repetida em execuções independentes. Tal permitiria distinguir a variabilidade entre execuções da estabilidade observada em cada uma, bem como apurar a causa dos resultados que ficaram por explicar.

Do mesmo modo, o desenho experimental beneficiaria de comparações que diferissem numa única propriedade de cada vez, acompanhadas de métricas adicionais, nomeadamente o espaço efetivamente ocupado em disco e a repartição da latência entre o dispositivo e a própria ferramenta, grandezas cuja ausência deixou algumas hipóteses por confirmar.

Por fim, os traces disponíveis são antigos e demasiado curtos face aos dispositivos atuais, pelo que o recurso a registos recentes, ou a caracterização direta de cargas em produção, reduziria a dependência da extensão sintética naquilo que é medido.

Encerra-se deste modo o capítulo, ficando o Prismo como ponto de partida para avaliações de sistemas de armazenamento que tratem o conteúdo e as cargas com o mesmo rigor com que medem o desempenho.
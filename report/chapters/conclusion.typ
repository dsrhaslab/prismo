= Conclusões e Trabalho Futuro <chapter5>

A avaliação de sistemas de armazenamento depende da capacidade dos benchmarks em reproduzir as condições em que estes efetivamente operam, no entanto as ferramentas mais utilizadas pela comunidade descrevem o conteúdo através de taxas únicas e oferecem um suporte limitado à replicação de cargas reais. Deste modo, os valores medidos tendem a refletir um regime que pouco tem em comum com o de produção.

Foi com o objetivo de colmatar estas lacunas que se desenvolveu o Prismo, um benchmark que gera conteúdo com propriedades de deduplicação e compressão semelhantes às encontradas em ambientes reais, que exercita diferentes interfaces de @io sobre a mesma descrição de carga, e que permite replicar traces de sistemas em produção, prolongando-os para lá da sua duração original.

A avaliação experimental começou por estabelecer que o Prismo mede com a mesma fiabilidade das ferramentas de referência, produzindo medições estáveis e equivalentes às destas em cargas genéricas. Tal resultado decorre da separação entre a geração e a submissão dos pedidos, visto o modelo produtor-consumidor construir o pedido seguinte enquanto o anterior aguarda o dispositivo, sustentando mesmo a combinação de geradores mais exigente cerca de 14× o débito máximo observado.

Sobre esta base, a descrição do conteúdo por distribuições, em que cada grupo de cópias dispõe da sua própria repartição de compressibilidade, revelou-se decisiva, pois o Deltoide confirmou desvios inferiores a 1.2% face ao configurado e, com idêntica compressibilidade média, o débito do @zfs divergiu em cerca de 31% do obtido com a taxa única do @fio, efeito que uma descrição baseada em taxas globais é incapaz de revelar.

Já a independência entre a descrição da carga e a interface que a submete permitiu exercitar o POSIX, o libaio, o io_uring e o @spdk sobre as mesmas cargas, expondo diferenças de até 19× no débito da leitura aleatória e demonstrando que o desempenho de cada interface depende tanto do mecanismo de submissão como da forma como é configurada face ao hardware e ao paralelismo da carga.

Por fim, ao tratar o trace como fonte possível de cada dimensão do pedido, o Prismo reproduz fielmente os acessos, as operações e o conteúdo registados num servidor real, prolonga-os através de três estratégias de extensão com compromissos distintos entre si e combina-os com geração sintética, o que permite isolar o contributo de cada dimensão, capacidade que nenhuma das ferramentas de referência oferece.

Em suma, avaliar com rigor um sistema de armazenamento exige cargas de trabalho fiéis tanto ao conteúdo como aos pedidos que este serve em produção, pois só assim os valores obtidos traduzem o comportamento que as aplicações efetivamente observarão, sendo precisamente esse o contributo que o Prismo procura oferecer à comunidade.

== Trabalho Futuro

O trabalho desenvolvido deixa em aberto um conjunto de questões que constituem a sua continuação natural, organizadas em duas frentes, a evolução do próprio protótipo e o aprofundamento da avaliação que o sustenta.

=== Evolução do Protótipo

As estratégias de extensão de traces podem ser aperfeiçoadas, de modo a que prolongar uma execução preserve melhor as propriedades do trace original, dado nenhuma das abordagens atuais o conseguir sem sacrificar alguma delas. Tal reduziria a distância entre as propriedades registadas no trace e aquelas que a carga continua a exercitar depois de o ficheiro se esgotar.

Além disso, a geração de conteúdo pode ir além dos duplicados exatos e da compressibilidade de cada bloco, passando a modelar a semelhança parcial entre blocos distintos, situação frequente em backups sucessivos ou em imagens de máquinas virtuais, onde blocos quase idênticos diferem apenas em pequenas porções. Atualmente, tais blocos são tratados como únicos, pelo que os sistemas que armazenam somente as diferenças entre eles não retiram vantagem alguma das cargas geradas, ficando essa capacidade por avaliar.

=== Aprofundamento da Avaliação

Grande parte desta frente decorre diretamente das limitações identificadas na @limitations, importando desde logo alargar a avaliação a outras máquinas, dispositivos e sistemas de armazenamento, com cada configuração repetida em execuções independentes. Tal permitiria distinguir a variabilidade entre execuções da estabilidade observada em cada uma, bem como apurar a causa dos resultados que ficaram por explicar.

Do mesmo modo, o desenho experimental beneficiaria de comparações que diferissem numa única propriedade de cada vez, acompanhadas de métricas adicionais, nomeadamente o espaço efetivamente ocupado em disco e a repartição da latência entre o dispositivo e a própria ferramenta, grandezas cuja ausência deixou algumas hipóteses por confirmar.

Ficam igualmente por explorar cenários que a campanha deixou de fora, como a comparação entre interfaces sob cargas abaixo da saturação, onde as diferenças tenderão a manifestar-se na latência e não no débito, e execuções sobre o Btrfs suficientemente longas para que a deduplicação offline chegue a atuar dentro da janela de medição.

Por fim, os traces disponíveis são antigos e demasiado curtos face aos dispositivos atuais, pelo que o recurso a registos recentes, ou a caracterização direta de cargas em produção, reduziria a dependência da extensão sintética naquilo que é medido.

Encerra-se deste modo o capítulo, ficando o Prismo como ponto de partida para avaliações de sistemas de armazenamento que tratem o conteúdo e as cargas com o mesmo rigor com que medem o desempenho.
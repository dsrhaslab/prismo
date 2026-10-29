= Introdução <chapter1>

Com o crescimento das aplicações intensivas em @io, em particular nas áreas da inteligência artificial e análise de dados, os sistemas de armazenamento assumem um papel cada vez mais determinante no desempenho das aplicações. A capacidade de processar e armazenar grandes volumes de dados de forma eficiente tornou-se um fator crítico, tornando igualmente relevante a existência de mecanismos de avaliação, como os _benchmarks_, que permitam analisar e comparar o comportamento destes sistemas de forma rigorosa @traeger2008 @tarasov2011.

Os sistemas de armazenamento modernos evoluíram no sentido de oferecer uma maior eficiência de acesso e densidade dos dados. Sistemas como o @zfs disponibilizam um conjunto alargado de funcionalidades que procuram melhorar o desempenho das aplicações, recorrendo a diferentes técnicas de otimização. Entre estas, destacam-se a deduplicação, que reduz o espaço de armazenamento ao evitar a reescrita de dados já existentes, e a compressão, que permite aumentar a densidade dos dados ao eliminar a redundância, ou seja, a informação que pode ser reconstruída a partir de uma amostra menor @koller2010 @constantinescu2011 @zhu2008.

Porém a avaliação do impacto destas técnicas não é trivial, pois o número crescente de otimizações implementadas nos sistemas de armazenamento atuais dificulta a obtenção de métricas representativas do seu funcionamento real @tarasov2011. Os _benchmarks_ desempenham aqui um papel crucial, permitindo caracterizar com rigor os sistemas e compreender de que forma determinadas decisões de implementação influenciam o comportamento observado pelas aplicações.

== Definição do Problema e Desafios <problem>

Os sistemas de armazenamento atuais combinam múltiplas técnicas de otimização, cujo impacto no desempenho depende fortemente das propriedades dos dados processados. A qualidade de uma avaliação não depende por isso apenas da ferramenta utilizada, dado que o realismo das cargas de trabalho é igualmente essencial no levantamento de ilações corretas acerca do sistema de armazenamento @gracia-tinedo2015 @pang2026 @tarasov2011. Ora a criação de cargas que respeitem estas propriedades e reflitam ambientes de produção continua a ser um desafio significativo, fazendo com que as condições observadas em ambientes reais raramente sejam reproduzidas em contexto de testes, o que contribui para avaliações indevidas do sistema @gracia-tinedo2018 @talasila2019 @tarasov2011.

Além do conteúdo, também o caminho percorrido pelos pedidos se diversificou, dado que, procurando ultrapassar as limitações da pilha de @io tradicional do _kernel_, nomeadamente mudanças de contexto, interrupções e cópias entre _user_ e _kernel space_, surgiram diversas @api:pl assentes em _runtimes_ assíncronos @didona2022 @ren2023. A crescente diversidade de interfaces assim expostas pelos sistemas de armazenamento dificulta, no entanto, a conceção de _benchmarks_ genéricos que consigam exercitar de forma consistente e comparável os diferentes caminhos de execução, comprometendo a uniformidade da avaliação entre sistemas heterogéneos @didona2022 @ren2023.

Posto isto, a seleção dos _benchmarks_ amplamente utilizados pela comunidade revela limitações significativas e uma escassez de funcionalidades que dificultam uma avaliação rigorosa dos sistemas de armazenamento atuais @fio_docs @dedisbench @dedisbenchpp. Entre essas limitações, destacam-se as seguintes:

+ As distribuições de duplicados e compressibilidade são obtidas através de padrões simplistas que repetem constantemente o mesmo conjunto de blocos, aumentando assim a localidade temporal e espacial, o que beneficia indevidamente o sistema de armazenamento @paulo2013.

+ Não existe suporte direto para as interfaces mais recentes, como o io_uring ou o @spdk, ausência particularmente limitativa no segundo caso, dado esta _framework_ ser fundamental para avaliar sistemas que operam com acesso direto ao controlador de @nvme, contornando assim a pilha de @io do _kernel_ e explorando o desempenho real @didona2022 @ren2023.

+ As cargas descritas tendem a ser estáticas e pouco configuráveis, não permitindo ajustar propriedades essenciais dos dados, como a evolução da localidade espacial e temporal dos pedidos de @io, restringindo a capacidade de simular cenários realistas @gracia-tinedo2018 @talasila2019.

+ A alternativa de recorrer a _traces_ recolhidos em produção, que trariam consigo estas propriedades, esbarra no facto de os disponíveis à comunidade datarem de vários anos e terem sido obtidos em contextos tecnológicos substancialmente distintos dos atuais, sendo por isso executados tão rapidamente que nem chegam a conduzir o dispositivo a um estado estável @gracia-tinedo2015 @pang2026.

Em suma, os _benchmarks_ atuais não permitem definir cargas de trabalho realistas nem suportam múltiplas interfaces que proporcionam a exercitação das otimizações implementadas, tornando impossível avaliar de forma precisa as características essenciais dos sistemas de armazenamento @tarasov2011.

== Objetivos e Contribuições

Perante os problemas identificados, o grande objetivo desta dissertação passa por tornar as ferramentas de avaliação mais realistas quanto aos padrões de acesso e às distribuições de conteúdo que geram, suportando ainda as diversas interfaces de @io emergentes. Para tal, apresenta-se o Prismo, um _benchmark_ para sistemas de armazenamento orientado ao bloco, cujo desenho procura dotar de maior flexibilidade e eficiência os algoritmos de geração de conteúdo, em particular o respeito pelas taxas de deduplicação e compressão, tornando-os independentes da interface através da qual os pedidos são submetidos @koller2010 @zhu2008.

Tal independência revela-se insuficiente, no entanto, para alcançar cargas realistas que efetuem uma avaliação correta do sistema, sendo para isso necessário replicar as propriedades de _traces_ extraídos a partir de ambientes em produção, pois somente estes oferecem informações acerca das cargas reais @gracia-tinedo2015 @pang2026 @ameri2016.

Assim sendo, o desenho proposto reúne as contribuições da dissertação numa arquitetura que torna as várias @api:pl de @io completamente independentes da geração de conteúdo, disponibilizando as seguintes características:

+ Suporte a várias interfaces de @io síncronas e assíncronas, nomeadamente POSIX, libaio, io_uring e @spdk, com possível configuração de parâmetros para alteração do comportamento do _backend_, consequentemente o _benchmark_ torna-se mais portável entre sistemas de armazenamento e proporciona uma comparação justa do desempenho @didona2022 @ren2023.

+ Geração de conteúdo realista a partir de distribuições de duplicados e compressibilidade, além disso os restantes parâmetros dos pedidos de @io são igualmente obtidos por distribuições ou padrões configuráveis pelo utilizador @gracia-tinedo2015 @talasila2019.

+ Replicação completa de _traces_ de @io para avaliação do sistema de armazenamento sobre cargas de trabalho reais, permitindo a identificação de gargalos em ambientes de produção e reprodutibilidade dos resultados @talwadker2014 @tracegen2024.

+ Replicação parcial de _traces_ com geração de dados sintéticos para os parâmetros em falta, desta forma a replicação das operações de @io pode ser efetuada sobre diferentes padrões de acesso, adição de barreiras e outros critérios à escolha do utilizador @pang2026 @tracegen2024.

+ Extensão de _traces_ com dados sintéticos, assim após o conteúdo original ser totalmente replicado, o mesmo é continuamente estendido pelo tempo necessário, para o que se propõem três estratégias distintas, nomeadamente a repetição cíclica do registo, a amostragem das distribuições observadas e um modelo de regressão que procura captar as correlações entre dimensões, salvaguardando cada uma delas um subconjunto diferente das características encontradas originalmente nos dados @pang2026 @tracegen2024.

Este desenho é concretizado num protótipo do Prismo, que permite avaliar os sistemas de armazenamento com mais critério, afinal o utilizador tem a possibilidade de testar várias interfaces de @io e para cada uma selecionar cargas que avaliem determinadas características do sistema, tudo com o maior realismo possível, e não através de métodos simplistas como praticam as demais soluções @fio_docs @dedisbench @dedisbenchpp @tarasov2011.

== Estrutura do Documento

Este documento encontra-se dividido em cinco capítulos, apresentando o @chapter2 os conceitos base relativos à avaliação de sistemas de armazenamento, onde se exploram ainda a deduplicação e a compressão, em particular as técnicas aplicadas para gerar conteúdo com estas propriedades. Além disso, a pilha de @io é analisada para justificar as diferenças entre @api:pl e perceber os pontos de melhoria em soluções já estabelecidas @fio_docs @dedisbench @dedisbenchpp.

Posteriormente, o @chapter3 apresenta a arquitetura da solução, começando pelo modelo de execução que separa a preparação dos pedidos da sua submissão e torna a geração de conteúdo independente da interface utilizada. Estabelecida essa separação, descreve-se o modo como cada pedido é construído e como um _trace_ pode tomar o lugar dos geradores sintéticos, prolongando-se para lá da sua duração, e encerra-se com as métricas recolhidas ao longo da execução.

Já o @chapter4 procede à avaliação experimental do Prismo, partindo das perguntas de investigação e pontos de validação que orientam as experiências realizadas. Demonstrada a equivalência com os _benchmarks_ de referência em cargas genéricas, exploram-se os cenários onde o conteúdo, a interface de @io e a replicação de _traces_ se revelam determinantes, terminando o capítulo com uma síntese dos resultados obtidos.

Por fim, o @chapter5 reúne as principais conclusões do trabalho e aponta as direções que a sua continuação poderá seguir.

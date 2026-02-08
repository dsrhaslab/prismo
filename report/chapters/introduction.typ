== Introdução <chapter1>

Com o crescimento das aplicações intensivas em @io, em particular nas áreas da inteligência artificial e análise de dados, os sistemas de armazenamento assumem um papel cada vez mais determinante no desempenho das aplicações. A capacidade de processar e armazenar grandes volumes de dados de forma eficiente tornou-se um fator crítico, tornando igualmente relevante a existência de mecanismos de avaliação, como benchmarks, que permitam analisar e comparar o comportamento destes sistemas de forma rigorosa @traeger2008 @tarasov2011.

Os sistemas de armazenamento modernos evoluíram no sentido de oferecer uma maior eficiência de acesso e densidade dos dados. Sistemas como o @zfs disponibilizam um conjunto alargado de funcionalidades que procuram melhorar a performance das aplicações, recorrendo a diferentes técnicas de otimização. Entre estas, destacam-se a deduplicação, que reduz o espaço de armazenamento ao evitar a reescrita de dados já existentes, e a compressão, que permite aumentar a densidade dos dados ao eliminar redundâncias e informação que pode ser reconstruída a partir de uma amostra menor @koller2010 @constantinescu2011 @zhu2008.

Porém a avaliação do impacto destas técnicas não é trivial, pois o número crescente de otimizações implementadas nos sistemas de armazenamento atuais dificulta a obtenção de métricas representativas do seu funcionamento real @tarasov2011 @fio_docs @dedisbenchpp. Os benchmarks desempenham aqui um papel crucial, permitindo caracterizar com rigor os sistemas e compreender de que forma determinadas decisões de implementação influenciam o comportamento observado pelas aplicações.

Entretanto, e com o objetivo de ultrapassar limitações impostas pela stack de @io tradicional do kernel, nomeadamente mudanças de contexto, interrupções e cópias entre user e kernel space (que evidenciam gargalos de desempenho), surgiram diversas @api:pl que procuram mitigar estes problemas, operando geralmente sobre runtimes assíncronos @didona2022 @ren2023.

Por fim, a qualidade das avaliações não depende única e exclusivamente da ferramenta de benchmark, o realismo das workloads é outra propriedade essencial no levantamento de ilações corretas acerca do sistema @gracia-tinedo2015 @pang2026 @tarasov2011.

=== Definição do Problema e Desafios

Os sistemas de armazenamento atuais combinam múltiplas técnicas de otimização, cujo impacto no desempenho depende fortemente das propriedades dos dados processados. A criação de workloads realistas que respeitem estas propriedades e reflitam ambientes de produção continua a ser um desafio significativo, fazendo com que as condições observadas em ambientes reais raramente sejam reproduzidas em contexto de benchmarking, o que contribui para avaliações indevidas do sistema @gracia-tinedo2018 @talasila2019 @tarasov2011.

Adicionalmente, a crescente diversidade de interfaces de @io expostas pelos sistemas de armazenamento dificulta a conceção de benchmarks genéricos que consigam exercitar de forma consistente e comparável os diferentes caminhos de execução, comprometendo a uniformidade da avaliação entre sistemas heterogéneos @didona2022 @ren2023.

Para piorar a situação, muitos dos traces atualmente disponíveis à comunidade datam de vários anos e foram recolhidos em contextos tecnológicos substancialmente distintos dos atuais @borrill2007 @talwadker2014 @gracia-tinedo2015. Quando aplicados a sistemas modernos, estes traces são executados rapidamente, não permitindo sequer atingir um estado estável do dispositivo de armazenamento. Torna-se, por isso, relevante a extensão sintética dos mesmos, de forma a preservar as propriedades observadas nos dados originais, permitindo uma avaliação mais fiel e sustentada do desempenho dos sistemas de armazenamento @gracia-tinedo2015 @pang2026.

Posto isto, a seleção dos benchmarks amplamente utilizados pela comunidade revela limitações significativas e uma escassez de funcionalidades que dificultam uma avaliação rigorosa dos sistemas de armazenamento atuais @fio_docs @dedisbench @dedisbenchpp @tarasov2011. Entre essas limitações, destacam-se as seguintes:

As distribuições de duplicados e compressibilidade são obtidas através de padrões simplistas que repetem constantemente o mesmo conjunto de blocos, aumentando assim a localidade temporal e espacial, o que beneficia indevidamente o sistema de armazenamento @paulo2013 @tarasov2011.

Não existe suporte direto para a interface @spdk, o que é particularmente limitativo dado esta framework ser fundamental para avaliar sistemas que operam com acesso direto ao controlador de @nvme, contornando assim a stack de @io do kernel e explorando o desempenho real @didona2022 @ren2023.

As workloads descritas tendem a ser estáticas e pouco configuráveis, não permitindo ajustar propriedades essenciais dos dados, como a evolução da localidade espacial e temporal dos pedidos de @io, restringindo a capacidade de simular cenários realistas @gracia-tinedo2018 @talasila2019.

Em suma, os benchmarks atuais não permitem definir workloads realistas nem suportam múltiplas interfaces que proporcionam a exercitação das otimizações implementadas, tornando impossível avaliar de forma precisa as características essenciais dos sistemas de armazenamento @tarasov2011.

=== Objetivos e Contribuições

Perante os problemas mencionados anteriormente, esta dissertação procura melhorar a eficiência e dotar duma maior flexibilidade os algoritmos para geração de conteúdo, em particular o respeito pelas taxas de deduplicação e compressão num sistema orientado ao bloco, podendo estes ser aplicados sobre múltiplas interfaces de @io @koller2010 @constantinescu2011 @zhu2008.

No entanto, tal condição é insuficiente para alcançar workloads realistas que efetuem uma avaliação correta do sistema, para isto é necessário replicar as propriedades de traces extraídos a partir de ambientes em produção, pois somente estes oferecem informações acerca das cargas reais @gracia-tinedo2015 @pang2026 @ameri2016.

Assim sendo, o protótipo do benchmark reúne todas as contribuições da dissertação numa arquitetura que torna as @api:pl de @io completamente independentes da geração de conteúdo, deste modo o utilizador final usufrui das seguintes vantagens:

Suporte a várias interfaces de @io síncronas e assíncronas, com possível configuração de parâmetros para alteração do comportamento do backend, consequentemente o benchmark torna-se mais portável entre sistemas de armazenamento e proporciona uma comparação justa do desempenho @didona2022 @ren2023.

Geração de conteúdo realista a partir de distribuições de duplicados e compressibilidade, além disso os restantes parâmetros dos pedidos de @io são igualmente obtidos por distribuições ou padrões configuráveis pelo utilizador @gracia-tinedo2015 @talasila2019.

Replicação completa de traces do @fiu para avaliação do sistema de armazenamento sobre cargas de trabalho reais, permitindo a identificação de gargalos em ambientes de produção e reprodutibilidade dos resultados @gracia-tinedo2018.

Replicação parcial de traces com geração de dados sintéticos para os parâmetros em falta, desta forma a replicação de operações de @io pode ser efetuada sobre diferentes padrões de acesso, adição de barreiras e outros critérios à escolha do utilizador @pang2026 @tracegen2024.

Extensão de traces com dados sintéticos, assim após o conteúdo original do trace ser totalmente replicado, o mesmo é continuamente estendido pelo tempo necessário, salvaguardando as características e padrões encontrados originalmente nos dados @pang2026 @tracegen2024.

Tendo um protótipo com estas características, contribuímos para que a avaliação dos sistemas de armazenamento seja efetuada como mais critério, afinal o utilizador tem a possibilidade de testar várias interfaces de @io e para cada uma selecionar workloads que avaliem determinadas características do sistema, tudo com o maior realismo possível, e não através de métodos simplistas como praticam as demais soluções @fio_docs @dedisbench @dedisbenchpp @tarasov2011.

=== Estrutura do Documento

Este documento encontra-se dividido em três capítulos, o #link(<chapter1>)[Capitulo 1] serve de introdução ao problema abordado na dissertação, procurando desvendar os desafios inerentes ao mesmo, sendo ainda apontadas as contribuições que se pretendem alcançar.

Já o #link(<chapter2>)[Capítulo 2] apresenta o background relativo ao benchmarking, explorando ainda os conceitos de deduplicação e compressão, em particular as técnicas aplicadas para gerar conteúdo com estas propriedades, além disso a stack de @io é explorada para justificar as diferenças entre @api:pl e perceber os pontos de melhoria em soluções de benchmark já estabelecidas @fio_docs @dedisbench @dedisbenchpp @tarasov2011.

Por fim, o #link(<chapter3>)[Capitulo 3] corresponde a uma visão geral da arquitetura da solução, especificando os fluxos entre componentes e configurações necessárias à descrição da workload por parte do utilizador, concluindo-se com a apresentação do plano para o restante da dissertação.
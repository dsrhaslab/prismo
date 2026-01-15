= Abstract

Data deduplication is a technique for identifying and removing duplicate content in storage systems, thereby contributing to better use of available space and consequent cost reduction. In fact, modern systems combine compression techniques to extract greater data density and store only what is strictly necessary.

By supporting various data manipulation techniques, the evaluation of these systems becomes increasingly complex, given that workloads need to meet a series of criteria that validate deduplication and compression simultaneously, without forgetting that the common characteristics between systems must remain the focus of the evaluation, in particular the spatial and temporal locality of accesses.

However, the benchmarks available by the community (@fio, vdbench) only allow partial manipulation of entropy and deduplication levels. Furthermore, trace simulation is too simplistic and becomes impractical in modern systems because they are too fast to complete the trace and there is no trivial way to extend it and preserve its characteristics.

Furthermore, in order to extract maximum performance, some systems only provide low-level @api, such as @spdk, which makes it even more complicated to execute workloads, as the aforementioned benchmarks do not directly support such protocols for communication with the disk.

That said, this dissertation aims to develop a benchmark for storage systems, capable of supporting various @io interfaces, as well as generating realistic workloads that allow the collection of relevant metrics for system evaluation, thus enabling the identification of performance bottlenecks and impacts associated with the characteristics of the system itself.

*Keywords* #h(10pt) storage system, I/O interface, deduplication, compression, realistic workload.

#pagebreak()

= Resumo

A deduplicação de dados corresponde a uma técnica para identificar e remover conteúdos duplicados em sistemas de armazenamento, contribuindo assim para uma melhor utilização do espaço disponível e consequente redução de custos. De facto, os sistemas modernos combinam técnicas de compressão para extrair maior densidade dos dados e armazenar o estritamente necessário.

Ao suportarem várias técnicas de manipulação de dados, a avaliação destes sistemas torna-se cada vez mais complexa, dado que as workloads necessitam de responder a uma série de critérios que validem a deduplicação e compressão em simultâneo, sem esquecer que as características comuns entres sistemas devem permanecer no alvo da avaliação, em particular a localidade espacial e temporal dos acessos.

No entanto, os benchmarks disponíveis pela comunidade (@fio, vdbench) apenas permitem uma manipulação parcial dos níveis de entropia e deduplicação. Ademais, a simulação de traces é demasiado simplista e torna-se impraticável em sistemas modernos por estes serem demasiado rápidos a concluir o trace e não existir uma forma trivial de o estender e preservar as suas características.

Além disso, no sentido de extrair o máximo de performance, alguns sistemas disponibilizam unicamente @api de baixo nível, tal como @spdk, o que torna ainda mais complicada a execução de workloads, pois os benchmarks anteriormente referidos não suportam diretamente tais protocolos para comunicação com o disco.

Posto isto, esta dissertação tem por objetivo desenvolver um benchmark para sistemas de armazenamento, sendo este capaz de suportar diversas interfaces de @io, bem como a geração de workloads realistas que permitam a recolha de métricas relevantes para a avaliação do sistema, permitindo assim a identificação de gargalos de desempenho e impactos associados às característica do sistema em si.

*Palavras-chave* #h(10pt) sistema de armazenamento, interface de I/O, deduplicação, compressão, workload realista.

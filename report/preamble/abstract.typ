= Abstract

Storage systems play an increasingly important role in modern applications, where the need to process and store large volumes of information is critical. In addition, rigorous evaluation of these systems is essential for identifying performance bottlenecks, optimizing space, and ensuring operational efficiency.

Today, these systems combine deduplication and compression techniques to extract greater data density and store only what is strictly necessary. However, these optimizations make evaluation more complex, since workloads need to meet criteria that validate deduplication and compression simultaneously, without disregarding common characteristics between systems, such as spatial and temporal locality properties of accesses.

On the other hand, the diversity of @api and @io supported between systems makes it difficult to create benchmarks, as a tool can hardly support all existing interfaces, making it challenging to execute consistent and comparable workloads between systems.

Currently, there is no solution capable of combining all these characteristics, which is precisely the focus of this work: to develop a benchmark for storage systems capable of supporting various I/O interfaces, generating realistic workloads, and collecting relevant metrics, allowing the evaluation of system performance, the identification of bottlenecks, and the analysis of the impact of their optimizations.

*Keywords* #h(10pt) storage system, I/O interface, deduplication, compression, realistic workload.

#pagebreak()

= Resumo

/*
A deduplicação de dados corresponde a uma técnica para identificar e remover conteúdos duplicados em sistemas de armazenamento, contribuindo assim para uma melhor utilização do espaço disponível e consequente redução de custos. De facto, os sistemas modernos combinam técnicas de compressão para extrair maior densidade dos dados e armazenar o estritamente necessário.

Ao suportarem várias técnicas de manipulação de dados, a avaliação destes sistemas torna-se cada vez mais complexa, dado que as workloads necessitam de responder a uma série de critérios que validem a deduplicação e compressão em simultâneo, sem esquecer que as características comuns entres sistemas devem permanecer no alvo da avaliação, em particular a localidade espacial e temporal dos acessos.

No entanto, os benchmarks disponíveis pela comunidade (@fio, vdbench) apenas permitem uma manipulação parcial dos níveis de entropia e deduplicação. Ademais, a simulação de traces é demasiado simplista e torna-se impraticável em sistemas modernos por estes serem demasiado rápidos a concluir o trace e não existir uma forma trivial de o estender e preservar as suas características.

Além disso, no sentido de extrair o máximo de performance, alguns sistemas disponibilizam unicamente @api de baixo nível, tal como @spdk, o que torna ainda mais complicada a execução de workloads, pois os benchmarks anteriormente referidos não suportam diretamente tais protocolos para comunicação com o disco.

Posto isto, esta dissertação tem por objetivo desenvolver um benchmark para sistemas de armazenamento, sendo este capaz de suportar diversas interfaces de @io, bem como a geração de workloads realistas que permitam a recolha de métricas relevantes para a avaliação do sistema, permitindo assim a identificação de gargalos de desempenho e impactos associados às característica do sistema em si.
*/

Os sistemas de armazenamento desempenham um papel cada vez mais relevante no contexto de aplicações modernas, onde a necessidade de processar e armazenar grandes volumes de informação é crítica. Além disso, a avaliação rigorosa destes sistemas é fundamental para a identificação de gargalos de desempenho, otimização do espaço e garantia da eficiência operacional.

Nos dias de hoje, os sistemas em questão combinam técnicas de deduplicação e compressão para extrair maior densidade dos dados e armazenar apenas o estritamente necessário. No entanto, estas otimizações tornam a avaliação mais complexa, uma vez que as workloads precisam de responder a critérios que validem deduplicação e compressão em simultâneo, sem desconsiderar características comuns entre sistemas, como propriedades de localidade espacial e temporal dos acessos.

Por outro lado, a diversidade de @api de @io suportadas entre sistemas dificulta a criação de benchmarks, pois uma ferramenta dificilmente suporta todas as interfaces existentes, tornando desafiadora a execução de workloads consistentes e comparáveis entre sistemas.

Atualmente, não existe uma solução capaz de combinar todas estas características, sendo precisamente neste ponto que se foca este trabalho: desenvolver um benchmark para sistemas de armazenamento capaz de suportar diversas interfaces de I/O, gerar workloads realistas e recolher métricas relevantes, permitindo assim avaliar o desempenho do sistema, identificar gargalos e analisar o impacto das suas otimizações.

*Palavras-chave* #h(10pt) sistema de armazenamento, interface de I/O, deduplicação, compressão, workload realista.

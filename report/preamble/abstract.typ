= Abstract

Storage systems play an increasingly important role in modern applications, where the need to process and store large volumes of information is critical. In addition, rigorous evaluation of these systems is essential for identifying performance bottlenecks, optimizing space, and ensuring operational efficiency @ruwart2001 @traeger2008.

Today, these systems combine deduplication and compression techniques to extract greater data density and store only what is strictly necessary @zhu2008 @meyer2012. However, these optimizations make evaluation more complex, since workloads need to meet criteria that validate deduplication and compression simultaneously, without disregarding common characteristics between systems, such as spatial and temporal locality properties of accesses @policroniades2004 @koller2010.

On the other hand, the diversity of I/O interfaces supported between systems makes it difficult to create generic benchmarks, as a tool can hardly support all existing interfaces, making it challenging to execute consistent and comparable workloads between systems @didona2022 @ren2023.

Currently, there is no solution capable of combining all these characteristics, gap which this work addresses through the development of Prismo, a storage system benchmark able to support various I/O interfaces, to generate realistic workloads from distributions of duplicates and compressibility, and to replay traces from production environments, extending them beyond their original duration @tarasov2011 @gracia-tinedo2015.

Finally, the experimental evaluation shows that Prismo matches established tools on generic workloads, while revealing that the way reducibility is spread across blocks, and not merely its average value, conditions the throughput delivered by the storage system, a property that no single global ratio is able to express @pang2026 @tarasov2011.

Keywords #h(10pt) storage system, I/O interface, deduplication, compression, realistic workload.

#pagebreak()

= Resumo

Os sistemas de armazenamento desempenham um papel cada vez mais relevante no contexto de aplicações modernas, onde a necessidade de processar e armazenar grandes volumes de informação é crítica. Além disso, a avaliação rigorosa destes sistemas é fundamental para a identificação de gargalos de desempenho, otimização do espaço e garantia da eficiência operacional @ruwart2001 @traeger2008.

Nos dias de hoje, os sistemas em questão combinam técnicas de deduplicação e compressão para extrair maior densidade dos dados e armazenar apenas o estritamente necessário @zhu2008 @meyer2012. No entanto, estas otimizações tornam a avaliação mais complexa, uma vez que as cargas de trabalho precisam de responder a critérios que validem deduplicação e compressão em simultâneo, sem desconsiderar características comuns entre sistemas, como propriedades de localidade espacial e temporal dos acessos @policroniades2004 @koller2010.

Por outro lado, a diversidade de @api:pl de @io suportadas entre sistemas dificulta a criação de _benchmarks_ genéricos, pois uma ferramenta dificilmente suporta todas as interfaces existentes, tornando desafiadora a execução de cargas de trabalho consistentes e comparáveis entre sistemas @didona2022 @ren2023.

Atualmente, não existe uma solução capaz de combinar todas estas características, lacuna que este trabalho procura colmatar com o desenvolvimento do Prismo, um _benchmark_ para sistemas de armazenamento capaz de suportar diversas interfaces de @io, gerar cargas de trabalho realistas a partir de distribuições de duplicados e compressibilidade, e replicar _traces_ de ambientes de produção, estendendo-os para lá da sua duração original @tarasov2011 @gracia-tinedo2015.

Por fim, a avaliação experimental demonstra que o Prismo iguala as ferramentas consagradas em cargas genéricas, revelando porém que a forma como a redutibilidade se reparte pelos blocos, e não apenas o seu valor médio, condiciona o débito entregue pelo sistema de armazenamento, propriedade que nenhuma taxa global é capaz de exprimir @pang2026 @tarasov2011.

Palavras-chave #h(10pt) sistema de armazenamento, interface de @io, deduplicação, compressão, carga de trabalho realista.

= Abstract

Storage systems play an increasingly important role in modern applications, where the need to process and store large volumes of information is critical. In addition, rigorous evaluation of these systems is essential for identifying performance bottlenecks, optimizing space, and ensuring operational efficiency @traeger2008 @lee2012.

Today, these systems combine deduplication and compression techniques to extract greater data density and store only what is strictly necessary @koller2010 @constantinescu2011 @paulo2014. However, these optimizations make evaluation more complex, since workloads need to meet criteria that validate deduplication and compression simultaneously, without disregarding common characteristics between systems, such as spatial and temporal locality properties of accesses @paulo2013 @gracia-tinedo2015.

On the other hand, the diversity of @api:pl and @io supported between systems makes it difficult to create generic benchmarks, as a tool can hardly support all existing interfaces, making it challenging to execute consistent and comparable workloads between systems @didona2022 @ren2023.

Currently, there is no solution capable of combining all these characteristics, which is precisely the focus of this work: to develop a benchmark for storage systems capable of supporting various @io interfaces, generating realistic workloads, and collecting relevant metrics, allowing the evaluation of system performance, the identification of bottlenecks, and the analysis of the impact of their optimizations @fio_docs @dedisbench @dedisbenchpp @gracia-tinedo2018.

Keywords #h(10pt) storage system, I/O interface, deduplication, compression, realistic workload.

#pagebreak()

= Resumo

Os sistemas de armazenamento desempenham um papel cada vez mais relevante no contexto de aplicações modernas, onde a necessidade de processar e armazenar grandes volumes de informação é crítica. Além disso, a avaliação rigorosa destes sistemas é fundamental para a identificação de gargalos de desempenho, otimização do espaço e garantia da eficiência operacional @traeger2008 @lee2012.

Nos dias de hoje, os sistemas em questão combinam técnicas de deduplicação e compressão para extrair maior densidade dos dados e armazenar apenas o estritamente necessário @koller2010 @constantinescu2011 @paulo2014. No entanto, estas otimizações tornam a avaliação mais complexa, uma vez que as workloads precisam de responder a critérios que validem deduplicação e compressão em simultâneo, sem desconsiderar características comuns entre sistemas, como propriedades de localidade espacial e temporal dos acessos @paulo2013 @gracia-tinedo2015.

Por outro lado, a diversidade de @api:pl de @io suportadas entre sistemas dificulta a criação de benchmarks genéricos, pois uma ferramenta dificilmente suporta todas as interfaces existentes, tornando desafiadora a execução de workloads consistentes e comparáveis entre sistemas @didona2022 @ren2023.

Atualmente, não existe uma solução capaz de combinar todas estas características, sendo precisamente neste ponto que se foca este trabalho: desenvolver um benchmark para sistemas de armazenamento capaz de suportar diversas interfaces de @io, gerar workloads realistas e recolher métricas relevantes, permitindo assim avaliar o desempenho do sistema, identificar gargalos e analisar o impacto das suas otimizações @fio_docs @dedisbench @dedisbenchpp @gracia-tinedo2018.

Palavras-chave #h(10pt) sistema de armazenamento, interface de I/O, deduplicação, compressão, workload realista.
= Abstract

Modern storage systems rely on deduplication and compression to store only what is strictly necessary, so their performance depends on the properties of the data they receive @zhu2008 @meyer2012. Evaluating them rigorously therefore requires workloads whose content reproduces the real distribution of duplicates and compressibility, something the most widely used benchmarks reduce to global ratios @koller2010 @tarasov2011.

On the other hand, the diversity of I/O interfaces, from synchronous POSIX to io_uring and SPDK, makes it difficult to run the same workload comparably over all of them @didona2022 @ren2023. This is compounded by the scarcity of real workloads, as the available traces are old and too short to drive a modern device into steady state @gracia-tinedo2015 @pang2026.

To address these gaps, this dissertation presents Prismo, a block-oriented benchmark whose architecture separates request generation from submission, allowing the same workload description to run over POSIX, libaio, io_uring and SPDK without generation cost limiting the evaluation.

The main contribution lies in describing content through distributions, in which each group of copies has its own compressibility, bringing the generated data closer to what storage systems encounter in production. It is complemented by treating traces as a source for each dimension of a request, which allows combining them with synthetic generation and extending them beyond their original duration through repetition, sampling or regression.

Finally, the experimental evaluation shows that Prismo matches FIO and Vdbench on generic workloads and reproduces the configured distributions with deviations below 1.2%, further revealing that, for the same average compressibility, ZFS throughput diverges by about 31% depending on how it is spread across blocks, that the interface changes random read throughput by up to 19×, and that trace replay is faithful.

Keywords #h(10pt) storage system, I/O interface, deduplication, compression, realistic workload.

#pagebreak()

= Resumo

Os sistemas de armazenamento modernos recorrem à deduplicação e à compressão para armazenar apenas o estritamente necessário, sendo o seu desempenho condicionado pelas propriedades dos dados submetidos @zhu2008 @meyer2012. Avaliá-los com rigor exige por isso cargas cujo conteúdo reproduza a distribuição real de duplicados e compressibilidade, algo que os _benchmarks_ mais utilizados reduzem a taxas globais @koller2010 @tarasov2011.

Por outro lado, a diversidade de @api:pl de @io, do POSIX síncrono ao io_uring e ao SPDK, dificulta a execução comparável da mesma carga sobre todas elas @didona2022 @ren2023. A isto junta-se a escassez de cargas reais, dado os _traces_ disponíveis serem antigos e demasiado curtos para conduzir um dispositivo moderno a um regime estacionário @gracia-tinedo2015 @pang2026.

Neste sentido, apresenta-se o Prismo, um _benchmark_ orientado ao bloco cuja arquitetura separa a geração dos pedidos da sua submissão, permitindo executar a mesma descrição de carga sobre POSIX, libaio, io_uring e SPDK sem que o custo da geração limite a avaliação.

A principal contribuição reside na descrição do conteúdo por distribuições, em que cada grupo de cópias dispõe da sua própria compressibilidade, aproximando os dados gerados daqueles que os sistemas de armazenamento encontram em produção. A esta junta-se o tratamento dos _traces_ como fonte de cada dimensão do pedido, o que permite combiná-los com geração sintética e prolongá-los para lá da sua duração original através de repetição, amostragem ou regressão.

Por fim, a avaliação experimental demonstra que o Prismo iguala o FIO e o Vdbench em cargas genéricas e reproduz as distribuições configuradas com desvios inferiores a 1.2%, revelando igualmente que, com a mesma compressibilidade média, o débito do ZFS diverge cerca de 31% consoante esta se reparta pelos blocos, que a interface altera o débito da leitura aleatória em até 19× e que a reprodução de _traces_ é fiel.

Palavras-chave #h(10pt) sistema de armazenamento, interface de @io, deduplicação, compressão, carga de trabalho realista.

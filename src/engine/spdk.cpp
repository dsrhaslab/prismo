#include <prismo/engine/spdk.hpp>

namespace Engine {

    SpdkEngine::SpdkEngine(
        std::unique_ptr<Logger::Base> _logger,
        const SpdkConfig& config
    ) : Base(std::move(_logger)) {
        spdk_main_thread = std::thread([this, config]() {
            start_spdk_app(this, config, &(this->trigger_atomic));
        });
    }

    SpdkEngine::~SpdkEngine() {
        spdk_main_thread.join();
    }

    int SpdkEngine::start_spdk_app(
        void* spdk_engine,
        const SpdkConfig config,
        std::atomic<TriggerData>* trigger_atomic
    ) {
        spdk_app_opts opts = {};
        SpdkAppContext app_context = {
            .bdev = nullptr,
            .bdev_desc = nullptr,
            .config = config,
            .spdk_engine = spdk_engine,
            .trigger_atomic = trigger_atomic
        };

        spdk_app_opts_init(&opts, sizeof(opts));
        opts.name = "spdk_engine_bdev";
        opts.rpc_addr = nullptr;
        opts.reactor_mask = config.reactor_mask.c_str();
        opts.json_config_file = config.json_config_file.c_str();

        SPDK_NOTICELOG("[APP] Starting SPDK application: %s\n", opts.name);

        int rc = spdk_app_start(&opts, thread_main_fn, &app_context);
        if (rc) {
            SPDK_ERRLOG("[ERROR] Failed to start SPDK application\n");
        }

        SPDK_NOTICELOG("[APP] Performing final shutdown operations\n");
        spdk_app_fini();

        return rc;
    }

    void SpdkEngine::thread_main_fn(void* app_ctx) {
        SpdkAppContext* app_context = static_cast<SpdkAppContext*>(app_ctx);

        SPDK_NOTICELOG("[APP] Successfully started the application\n");
        SPDK_NOTICELOG("[APP] Opening bdev: %s\n", app_context->config.bdev_name.c_str());

        int rc = spdk_bdev_open_ext(
            app_context->config.bdev_name.c_str(),
            true,
            bdev_event_cb,
            nullptr,
            &app_context->bdev_desc
        );

        if (rc) {
            SPDK_ERRLOG(
                "[ERROR] Could not open bdev: %s\n",
                app_context->config.bdev_name.c_str()
            );
            spdk_app_stop(-1);
            return;
        }

        SPDK_NOTICELOG("[APP] Successfully opened bdev: %s\n", app_context->config.bdev_name.c_str());
        app_context->bdev = spdk_bdev_desc_get_bdev(app_context->bdev_desc);

        std::atomic<int> out_standing{0};
        std::atomic<bool> submitted{false};

        int total_workers = app_context->config.spdk_threads;
        // size_t total_indexes = spdk_bdev_get_num_blocks(app_context->bdev);
        size_t total_indexes = AVAILABLE_INDEXES;

        std::vector<spdk_thread*> workers(total_workers);
        std::vector<SpdkThreadContext*> thread_contexts(total_workers);
        std::vector<SpdkThreadCallBackContext*> thread_cb_contexts(total_indexes);
        moodycamel::ConcurrentQueue<int> available_indexes(total_indexes);

        SPDK_NOTICELOG("[INIT] Initializing SPDK worker threads\n");
        init_threads(app_context->config.pinned_cores, workers);

        SPDK_NOTICELOG("[INIT] Initializing SPDK thread contexts\n");
        init_thread_contexts(app_context, &submitted, workers, thread_contexts);

        SPDK_NOTICELOG("[INIT] Initializing available indexes queue\n");
        init_available_indexes(total_indexes, available_indexes);

        SPDK_NOTICELOG("[INIT] Initializing SPDK thread callback contexts\n");
        init_thread_cb_contexts(app_context, thread_cb_contexts, available_indexes, &out_standing);

        SPDK_NOTICELOG("[ALLOC] Allocating DMA buffer for I/O operations\n");
        size_t block_size =
            spdk_bdev_get_block_size(app_context->bdev) *
            spdk_bdev_get_write_unit_size(app_context->bdev);

        uint8_t* dma_buf = (uint8_t*) allocate_dma_buffer(app_context, total_indexes, block_size);

        SPDK_NOTICELOG("[DISPATCH] Starting main dispatch loop on SPDK threads\n");
        thread_main_dispatch(
            app_context,
            workers,
            thread_contexts,
            thread_cb_contexts,
            available_indexes,
            dma_buf,
            block_size
        );

        SPDK_NOTICELOG("[WAIT] Waiting for all callbacks to complete\n");
        while (out_standing != 0) {
            SPDK_NOTICELOG(
                "[WAIT] Out-standing callbacks: %d\n",
                out_standing.load(std::memory_order_acquire)
            );
            // Optional: sleep or small delay to avoid busy spinning
            // spdk_delay_us(500);
        }

        SPDK_NOTICELOG("[CLEANUP] Cleaning up SPDK threads and contexts\n");
        threads_cleanup(workers, thread_contexts);

        SPDK_NOTICELOG("[CLEANUP] Cleaning up SPDK thread callback contexts\n");
        thread_cb_contexts_cleanup(thread_cb_contexts);

        SPDK_NOTICELOG(
            "[CLEANUP] Closing block device on current thread: %s\n",
            spdk_thread_get_name(spdk_get_thread())
        );
        spdk_bdev_close(app_context->bdev_desc);

        SPDK_NOTICELOG("[CLEANUP] Freeing DMA buffer\n");
        spdk_dma_free(dma_buf);

        print_queue(available_indexes);

        SPDK_NOTICELOG("[APP] Stopping SPDK framework\n");
        spdk_app_stop(0);
    }

    void SpdkEngine::init_threads(
        std::vector<uint32_t> pinned_cores,
        std::vector<spdk_thread*>& workers
    ) {
        for (size_t i = 0; i < workers.size(); i++) {
            spdk_cpuset mask{};
            uint32_t core = pinned_cores[i % (pinned_cores.size() - 1) + 1];

            spdk_cpuset_zero(&mask);
            spdk_cpuset_set_cpu(&mask, core, true);

            std::string name = "worker" + std::to_string(i);
            spdk_thread* worker = spdk_thread_create(name.c_str(), &mask);
            SPDK_NOTICELOG("[CREATE] Creating SPDK thread '%s' on core %u\n", name.c_str(), core);

            if (!worker) {
                SPDK_ERRLOG("[ERROR] Failed to create SPDK thread '%s'\n", name.c_str());
                spdk_app_stop(-1);
                return;
            }

            workers[i] = worker;
            SPDK_NOTICELOG("[READY] Worker thread '%s' successfully created\n", name.c_str());
        }
    }

    void SpdkEngine::init_thread_contexts(
        SpdkAppContext* app_context,
        std::atomic<bool>* submitted,
        std::vector<spdk_thread*>& workers,
        std::vector<SpdkThreadContext*>& thread_contexts
    ) {
        for (size_t i = 0; i < thread_contexts.size(); i++) {
            const char* thread_name = spdk_thread_get_name(workers[i]);
            SPDK_NOTICELOG("[INIT] Creating SPDK thread context for thread '%s'\n", thread_name);

            SpdkThreadContext* thread_context = new SpdkThreadContext();
            thread_context->bdev = app_context->bdev;
            thread_context->bdev_desc = app_context->bdev_desc;
            thread_context->submitted = submitted;
            thread_context->bdev_io_channel = nullptr;
            thread_contexts[i] = thread_context;

            SPDK_NOTICELOG("[SEND] Dispatching thread_setup_io_channel_cb to thread '%s'\n",thread_name);
            spdk_thread_send_msg(workers[i], thread_setup_io_channel_cb, thread_contexts[i]);

            SPDK_NOTICELOG("[WAIT] Waiting for I/O channel on thread '%s'...\n", thread_name);
            while (thread_context->bdev_io_channel == nullptr) {
                // optional: small pause to reduce CPU spinning
                // spdk_delay_us(50);
            }

            SPDK_NOTICELOG("[READY] Thread '%s' finished I/O channel setup\n",thread_name);
        }
    }

    void SpdkEngine::thread_setup_io_channel_cb(void* thread_ctx) {
        const char* thread_name = spdk_thread_get_name(spdk_get_thread());
        SpdkThreadContext* thread_context = static_cast<SpdkThreadContext*>(thread_ctx);

        SPDK_NOTICELOG(
            "[SETUP] Opening I/O channel on thread '%s' (core %u)\n",
            thread_name,
            spdk_env_get_current_core()
        );
        thread_context->bdev_io_channel = spdk_bdev_get_io_channel(thread_context->bdev_desc);

        if (!thread_context->bdev_io_channel) {
            SPDK_ERRLOG("[ERROR] Failed to get I/O channel on thread '%s'\n", thread_name);
            spdk_app_stop(-1);
            return;
        }

        SPDK_NOTICELOG("[READY] I/O channel ready on thread '%s'\n", thread_name);
    }

    void SpdkEngine::init_thread_cb_contexts(
        SpdkAppContext* app_context,
        std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts,
        moodycamel::ConcurrentQueue<int>& available_indexes,
        std::atomic<int>* out_standing
    ) {
        SPDK_NOTICELOG("[INIT] Initializing %zu callback contexts\n", thread_cb_contexts.size());
        for (size_t i = 0; i < thread_cb_contexts.size(); i++) {
            SpdkThreadCallBackContext* thread_cb_context = new SpdkThreadCallBackContext();
            thread_cb_context->spdk_engine = app_context->spdk_engine;
            thread_cb_context->available_indexes = &available_indexes;
            thread_cb_context->out_standing = out_standing;
            thread_cb_contexts[i] = thread_cb_context;
        }
        SPDK_NOTICELOG("[READY] Callback contexts initialized\n");
    }

    void SpdkEngine::init_available_indexes(
        int total_indexes,
        moodycamel::ConcurrentQueue<int>& available_indexes
    ) {
        SPDK_NOTICELOG("[INIT] Initializing %d available indexes\n", total_indexes);
        for (int i = 0; i < total_indexes; i++) {
            available_indexes.enqueue(i);
        }
        SPDK_NOTICELOG("[READY] Available indexes initialized\n");
    }

    void* SpdkEngine::allocate_dma_buffer(
        SpdkAppContext* app_context,
        size_t total_blocks,
        size_t block_size
    ) {
        size_t buf_align = spdk_bdev_get_buf_align(app_context->bdev);
        size_t buf_size = block_size * total_blocks;

        SPDK_NOTICELOG("[ALLOC] Allocating pinned memory buffer of size %lu, alignment %lu\n", buf_size, buf_align);
        uint8_t* dma_buf = (uint8_t*) spdk_dma_zmalloc(buf_size, buf_align, nullptr);

        if (!dma_buf) {
            SPDK_ERRLOG("[ERROR] Failed to allocate DMA buffer\n");
            spdk_bdev_close(app_context->bdev_desc);
            spdk_app_stop(-1);
            return nullptr;
        }

        SPDK_NOTICELOG("[READY] DMA buffer allocated at %p\n", dma_buf);
        return dma_buf;
    }

    void SpdkEngine::threads_cleanup(
        std::vector<spdk_thread*>& workers,
        std::vector<SpdkThreadContext*>& thread_contexts
    ) {
        for (size_t i = 0; i < workers.size(); i++) {
            const char* thread_name = spdk_thread_get_name(workers[i]);
            SPDK_NOTICELOG("[CLEANUP] Sending cleanup message to thread: %s\n", thread_name);
            spdk_thread_send_msg(workers[i], thread_cleanup_cb, thread_contexts[i]);

            SPDK_NOTICELOG("[WAIT] Waiting for thread %s to exit...\n", thread_name);
            while (!spdk_thread_is_exited(workers[i])) {
                // optional: small pause to reduce CPU spinning
                // spdk_delay_us(50);
            }

            SPDK_NOTICELOG("[FREE] Freeing thread context for thread: %s\n", thread_name);
            delete thread_contexts[i];
        }

        SPDK_NOTICELOG("[READY] All threads cleaned up\n");
    }

    void SpdkEngine::thread_cleanup_cb(void* thread_ctx) {
        spdk_thread* thread = spdk_get_thread();
        const char* thread_name = spdk_thread_get_name(thread);
        SpdkThreadContext* thread_context = static_cast<SpdkThreadContext*>(thread_ctx);

        if (thread_context->bdev_io_channel) {
            SPDK_NOTICELOG(
                "[CLEANUP] Closing I/O channel on thread '%s' (core %u)\n",
                thread_name,
                spdk_env_get_current_core()
            );
            spdk_put_io_channel(thread_context->bdev_io_channel);
        }

        SPDK_NOTICELOG("[EXIT] Exiting thread '%s'\n",thread_name);
        spdk_thread_exit(thread);
    }

    void SpdkEngine::thread_cb_contexts_cleanup(
        std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts
    ) {
        for (auto& thread_cb_context : thread_cb_contexts) {
            delete thread_cb_context;
        }
    }

    void SpdkEngine::thread_main_dispatch(
        SpdkAppContext* app_context,
        std::vector<spdk_thread*>& workers,
        std::vector<SpdkThreadContext*>& thread_contexts,
        std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts,
        moodycamel::ConcurrentQueue<int>& available_indexes,
        uint8_t* dma_buf,
        int block_size
    ) {
        SPDK_NOTICELOG("[DISPATCH] Dispatcher started\n");

        for (int i = 0, iter = 0; true; i = (i + 1) % workers.size(), iter++) {

            SPDK_NOTICELOG("[DISPATCH] Iteration %d\n", iter);

            // Wait for the next trigger
            TriggerData snap = app_context->trigger_atomic->load(std::memory_order_acquire);
            while (!snap.has_next) {
                snap = app_context->trigger_atomic->load(std::memory_order_acquire);
            }

            // Check shutdown
            if (snap.is_shutdown) {
                SPDK_NOTICELOG("[DISPATCH] Received shutdown signal\n");
                break;
            }

            // Acquire a free DMA index
            int free_index;
            SPDK_NOTICELOG("[DISPATCH] Waiting for free index\n");
            while (!available_indexes.try_dequeue(free_index)) {
                // Optional: small pause to reduce CPU spinning
                // spdk_delay_us(1);
            }

            spdk_thread* worker = workers[i];
            SPDK_NOTICELOG("[DISPATCH] Using free index %d for thread '%s'\n", free_index, spdk_thread_get_name(worker));

            // Prepare thread context
            SpdkThreadContext* thread_context = thread_contexts[i];
            thread_context->request = snap.request;

            uint8_t* original_buf = thread_context->request->buffer;
            uint8_t* dma_chunk = dma_buf + (free_index * block_size);

            if (thread_context->request->operation == Operation::OperationType::WRITE) {
                SPDK_NOTICELOG("[DISPATCH] Memcopy to DMA buffer index %d (size %zu)\n", free_index, thread_context->request->size);
                std::memcpy(dma_chunk, thread_context->request->buffer, thread_context->request->size);
            }

            thread_context->request->buffer = dma_chunk;

            // Setup callback context
            thread_context->thread_cb_ctx = thread_cb_contexts[free_index];
            thread_context->thread_cb_ctx->index = free_index;
            thread_context->thread_cb_ctx->out_standing->fetch_add(1);

            // Prepare metric data
            thread_context->thread_cb_ctx->metric_data = {
                .size = thread_context->request->size,
                .offset = thread_context->request->offset,
                .start_ns = Metric::get_current_timestamp(),
                .metadata = Common::BlockMetadata {
                    .block_id = thread_context->request->metadata.block_id,
                    .compression = thread_context->request->metadata.compression
                },
                .operation_type = thread_context->request->operation
            };

            // Reset submission flag
            thread_context->submitted->store(false, std::memory_order_release);

            SPDK_NOTICELOG("[DISPATCH] Sending request to thread '%s'\n", spdk_thread_get_name(worker));
            spdk_thread_send_msg(worker, thread_fn, thread_context);

            // Wait for submission completion (spin-wait)
            SPDK_NOTICELOG("[DISPATCH] Waiting for submission done on thread '%s'\n", spdk_thread_get_name(worker));
            while (!thread_context->submitted->load(std::memory_order_acquire)) {
                // Optional: small pause to reduce CPU spinning
                // spdk_delay_us(1);
            }

            // Restore original buffer
            thread_context->request->buffer = original_buf;

            SPDK_NOTICELOG("[DISPATCH] Marking submission done for index %d\n", free_index);
            TriggerData done_snap = {};
            done_snap.has_submitted = true;
            app_context->trigger_atomic->store(done_snap, std::memory_order_release);
        }

        SPDK_NOTICELOG("[DISPATCH] Dispatcher shutdown complete\n");
        TriggerData done_snap = {};
        done_snap.has_submitted = true;
        app_context->trigger_atomic->store(done_snap, std::memory_order_release);
    }

    void SpdkEngine::thread_fn(void* thread_ctx) {
        spdk_thread* thread = spdk_get_thread();
        uint32_t core = spdk_env_get_current_core();
        const char* thread_name = spdk_thread_get_name(thread);

        int rc = 0;
        SpdkThreadContext* thread_context = static_cast<SpdkThreadContext*>(thread_ctx);

        SPDK_NOTICELOG(
            "[THREAD %s | CORE %u] Writing %zu bytes at offset %lu\n",
            thread_name, core,
            thread_context->request->size,
            thread_context->request->offset
        );

        switch (thread_context->request->operation) {
            case Operation::OperationType::READ:
                rc = thread_read(thread_context);
                break;
            case Operation::OperationType::WRITE:
                rc = thread_write(thread_context);
                break;
            case Operation::OperationType::FSYNC:
                rc = thread_fsync(thread_context);
                break;
            case Operation::OperationType::FDATASYNC:
                rc = thread_fdatasync(thread_context);
                break;
            case Operation::OperationType::NOP:
                rc = thread_nop(thread_context);
                break;
        }

        SPDK_NOTICELOG("[THREAD %s | CORE %u] submition return code: %d\n", thread_name, core, rc);

        if (rc == -ENOMEM) {
            SPDK_NOTICELOG("[THREAD %s | CORE %u] Bdev busy, queueing I/O\n", thread_name, core);

            thread_context->bdev_io_wait.bdev = thread_context->bdev;
            thread_context->bdev_io_wait.cb_fn = thread_fn;
            thread_context->bdev_io_wait.cb_arg = thread_context;

            spdk_bdev_queue_io_wait(
                thread_context->bdev,
                thread_context->bdev_io_channel,
                &thread_context->bdev_io_wait
            );

        } else if (rc == 0) {
            SPDK_NOTICELOG("[THREAD %s | CORE %u] Submition completed successfully\n", thread_name, core);
            thread_context->submitted->store(true, std::memory_order_release);
        } else {
            SPDK_ERRLOG("[THREAD %s | CORE %u] Submition failed with rc=%d\n", thread_name, core, rc);
        }
    }

    int SpdkEngine::thread_read(SpdkThreadContext* thread_ctx) {
        return spdk_bdev_read(
            thread_ctx->bdev_desc,
            thread_ctx->bdev_io_channel,
            thread_ctx->request->buffer,
            thread_ctx->request->offset,
            thread_ctx->request->size,
            io_complete,
            thread_ctx->thread_cb_ctx
        );
    }

    int SpdkEngine::thread_write(SpdkThreadContext* thread_ctx) {
        return spdk_bdev_write(
            thread_ctx->bdev_desc,
            thread_ctx->bdev_io_channel,
            thread_ctx->request->buffer,
            thread_ctx->request->offset,
            thread_ctx->request->size,
            io_complete,
            thread_ctx->thread_cb_ctx
        );
    }

    int SpdkEngine::thread_fsync(SpdkThreadContext* thread_ctx) {
        return spdk_bdev_flush(
            thread_ctx->bdev_desc,
            thread_ctx->bdev_io_channel,
            thread_ctx->request->offset,
            thread_ctx->request->size,
            io_complete,
            thread_ctx->thread_cb_ctx
        );
    }

    int SpdkEngine::thread_fdatasync(SpdkThreadContext* thread_ctx) {
        return thread_fsync(thread_ctx);
    }

    int SpdkEngine::thread_nop(SpdkThreadContext* thread_ctx) {
        io_complete(nullptr, true, thread_ctx->thread_cb_ctx);
        return 0;
    }

    void SpdkEngine::io_complete(
        struct spdk_bdev_io* bdev_io,
        bool success,
        void* thread_cb_ctx
    ) {
        SpdkThreadCallBackContext* thread_cb_context =
            static_cast<SpdkThreadCallBackContext*>(thread_cb_ctx);

        SpdkEngine* spdk_engine =
            static_cast<SpdkEngine*>(thread_cb_context->spdk_engine);

        spdk_thread* thread = spdk_get_thread();
        const char* thread_name = spdk_thread_get_name(thread);
        uint32_t core = spdk_env_get_current_core();

        // Free the SPDK I/O if valid
        if (bdev_io) {
            spdk_bdev_free_io(bdev_io);
        }

        if (success) {
            SPDK_NOTICELOG(
                "[THREAD %s | CORE %u] Bdev I/O completed successfully\n",
                thread_name, core
            );
        } else {
            SPDK_ERRLOG(
                "[THREAD %s | CORE %u] Bdev I/O error: %d\n",
                thread_name, core, EIO
            );
        }

        Metric::Metric m = Metric::create_metric(
            thread_cb_context->metric_data.operation_type,
            thread_cb_context->metric_data.metadata.block_id,
            thread_cb_context->metric_data.metadata.compression,
            thread_cb_context->metric_data.start_ns,
            spdk_engine->process_id,
            spdk_engine->thread_id,
            thread_cb_context->metric_data.size,
            thread_cb_context->metric_data.offset,
            success ? thread_cb_context->metric_data.size : 0
        );

        spdk_engine->log_metric(m);
        spdk_engine->record_metric(m);

        thread_cb_context->out_standing->fetch_sub(1);
        thread_cb_context->available_indexes->enqueue(thread_cb_context->index);

        SPDK_NOTICELOG(
            "[THREAD %s | CORE %u] Returned index %d to available queue\n",
            thread_name, core,
            thread_cb_context->index
        );
    }

    void SpdkEngine::bdev_event_cb(
        [[maybe_unused]] enum spdk_bdev_event_type type,
        [[maybe_unused]] struct spdk_bdev* bdev,
        [[maybe_unused]] void *event_ctx
    ) {
        SPDK_NOTICELOG("Unsupported bdev event: type %d\n", type);
    }

    void SpdkEngine::submit(Protocol::IORequest& request) {
        TriggerData snap = {};
        snap.has_next = true;
        snap.is_shutdown = false;
        snap.request = &request;
        publish_and_wait(snap);
    }

    void SpdkEngine::reap_left_completions(void) {
        TriggerData snap = {};
        snap.has_next = true;
        snap.is_shutdown = true;
        publish_and_wait(snap);
    }

    void SpdkEngine::publish_and_wait(const TriggerData& snap) {
        trigger_atomic.store(snap, std::memory_order_release);
        TriggerData current = trigger_atomic.load(std::memory_order_acquire);
        while (!current.has_submitted) {
            current = trigger_atomic.load(std::memory_order_acquire);
        }
    }

    void SpdkEngine::print_queue(moodycamel::ConcurrentQueue<int>& queue) {
        int val;
        std::vector<int> snapshot;
        while (queue.try_dequeue(val)) {
            snapshot.push_back(val);
        }
        for (int v : snapshot) {
            std::cout << v << " ";
            queue.enqueue(v);  // Restore immediately
        }
        std::cout << "size: " << queue.size_approx() << std::endl;
    }
};
#ifndef PRISMO_ENGINE_SPDK_H
#define PRISMO_ENGINE_SPDK_H

#include <spdk/env.h>
#include <spdk/bdev.h>
#include <spdk/event.h>
#include <spdk/thread.h>
#include <prismo/engine/engine.hpp>
#include <prismo/engine/config.hpp>
#include <lib/concurrentqueue/concurrentqueue.h>

namespace Engine {

    struct TriggerData {
        bool has_next;
        bool is_shutdown;
        bool has_submitted;
        Protocol::IORequest* request;

        auto operator<=>(const TriggerData&) const = default;
    };

    struct SpdkAppContext {
        spdk_bdev* bdev;
        spdk_bdev_desc* bdev_desc;
        const SpdkConfig config;

        void* spdk_engine;
        std::atomic<TriggerData>* trigger_atomic;
    };

    struct SpdkThreadCallBackContext {
        void* spdk_engine;
        MetricData metric_data;

        int index;
        std::atomic<int>* out_standing;
        moodycamel::ConcurrentQueue<int>* available_indexes;
    };

    struct SpdkThreadContext {
        spdk_bdev* bdev;
        spdk_bdev_desc* bdev_desc;
        spdk_io_channel* bdev_io_channel;
        spdk_bdev_io_wait_entry bdev_io_wait;

        std::atomic<bool>* submitted;
        Protocol::IORequest* request;
        SpdkThreadCallBackContext* thread_cb_ctx;
    };

    class SpdkEngine : public Base {
        private:
            size_t constexpr static AVAILABLE_INDEXES = 1024;
            std::thread spdk_main_thread;
            std::atomic<TriggerData> trigger_atomic;

            static int start_spdk_app(
                void* spdk_engine,
                const SpdkConfig config,
                std::atomic<TriggerData>* trigger_atomic
            );

            static void bdev_event_cb(
                enum spdk_bdev_event_type type,
                struct spdk_bdev* bdev,
                void* event_ctx
            );

            static void io_complete(
                struct spdk_bdev_io* bdev_io,
                bool success,
                void* cb_arg
            );

            static void thread_main_fn(void* app_ctx);
            static void thread_fn(void* thread_ctx);

            static void thread_setup_io_channel_cb(void* thread_ctx);
            static void thread_cleanup_cb(void* thread_ctx);

            static void init_threads(
                std::vector<uint32_t> pinned_cores,
                std::vector<spdk_thread*>& workers
            );

            static void init_thread_contexts(
                SpdkAppContext* app_context,
                std::atomic<bool>* submitted,
                std::vector<spdk_thread*>& workers,
                std::vector<SpdkThreadContext*>& thread_contexts
            );

            static void init_thread_cb_contexts(
                SpdkAppContext* app_context,
                std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts,
                moodycamel::ConcurrentQueue<int>& available_indexes,
                std::atomic<int>* out_standing
            );

            static void init_available_indexes(
                int total_indexes,
                moodycamel::ConcurrentQueue<int>& available_indexes
            );

            static void* allocate_dma_buffer(
                SpdkAppContext* app_context,
                size_t num_blocks,
                size_t block_size
            );

            static void thread_main_dispatch(
                SpdkAppContext* app_context,
                std::vector<spdk_thread*>& workers,
                std::vector<SpdkThreadContext*>& thread_contexts,
                std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts,
                moodycamel::ConcurrentQueue<int>& available_indexes,
                uint8_t* dma_buf,
                int block_size
            );

            static void threads_cleanup(
                std::vector<spdk_thread*>& workers,
                std::vector<SpdkThreadContext*>& thread_contexts
            );

            static void thread_cb_contexts_cleanup(
                std::vector<SpdkThreadCallBackContext*>& thread_cb_contexts
            );

            static int thread_read(SpdkThreadContext* thread_ctx);
            static int thread_write(SpdkThreadContext* thread_ctx);
            static int thread_fsync(SpdkThreadContext* thread_ctx);
            static int thread_fdatasync(SpdkThreadContext* thread_ctx);
            static int thread_nop(SpdkThreadContext* thread_ctx);

            void publish_and_wait(const TriggerData& snap);

            // NOTE: remove this when tested
            static void print_queue(moodycamel::ConcurrentQueue<int>& queue);

        public:
            explicit SpdkEngine(
                std::shared_ptr<Logger::Base> _logger,
                const SpdkConfig& config
            );

            ~SpdkEngine() override;

            int open(Protocol::OpenRequest& request) override { (void) request; return 0; }
            int close(Protocol::CloseRequest& request) override { (void) request; return 0; }
            void submit(Protocol::IORequest& request) override;
            void reap_left_completions(void) override;
        };
}

#endif
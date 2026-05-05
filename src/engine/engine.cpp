#include <prismo/engine/engine.hpp>

namespace Engine {

    Base::Base(
        Metric::MetricVariant _metric,
        std::shared_ptr<Logger::Base> _logger
    ) :
        metric(_metric),
        logger(_logger)
    {
        process_id = ::getpid();
        thread_id =
            std::hash<std::thread::id>{}(std::this_thread::get_id());
    }

    Base::~Base() {
        std::cout << "~Destroying Engine" << std::endl;
    }

    void Base::record_metric(const Metric::MetricVariant& metric) {
        statistics.record_metric(metric);
    }

    void Base::log_metric(const Metric::MetricVariant& metric) {
        if (logger) logger->info(metric);
    }

    void Base::set_thread_id_current(void) {
        thread_id = std::hash<std::thread::id>{}(std::this_thread::get_id());
    }

    void Base::set_process_id_current(void) {
        process_id = ::getpid();
    }

    void Base::start_statistics(void) {
        statistics.start();
    }

    void Base::finish_statistics(void) {
        statistics.finish();
    }

    const Metric::Statistics Base::get_statistics(void) const {
        return statistics;
    }
};
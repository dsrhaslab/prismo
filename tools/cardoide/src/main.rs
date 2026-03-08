mod campaign;
mod logging;
use chrono::Local;
use clap::Parser;
use std::path::{Path, PathBuf};
use campaign::Campaign;
use logging::{log_fail, log_dim};

#[derive(Parser, Debug)]
#[command(name = "campagne", about = "Campaign runner for prismo workloads")]
struct Cli {
    /// Path to the Prismo binary
    #[arg(short, long, default_value = "../../builddir/prismo")]
    prismo: String,

    /// Directory containing workload files
    #[arg(short = 'd', long, default_value = "../../workloads/campaign")]
    workloads_dir: String,

    /// Output directory for results
    #[arg(short, long, default_value = "../../workloads/results")]
    output_dir: String,

    /// Filter by engine: posix | uring | aio | spdk | all
    #[arg(short, long, default_value = "all")]
    engine: String,

    /// Run only workloads starting from this number (inclusive)
    #[arg(long, default_value_t = 0)]
    workload_from: usize,

    /// Run only workloads up to this number (inclusive)
    #[arg(long, default_value_t = 0)]
    workload_to: usize,

    /// Repetitions for each workload
    #[arg(short, long, default_value_t = 1)]
    repetitions: usize,
}

fn main() {
    let cli = Cli::parse();
    let binary = cli.prismo;
    let workload_dir = PathBuf::from(&cli.workloads_dir);

    let mut results_dir = PathBuf::from(&cli.output_dir);
    results_dir = results_dir.join(
        format!("campaign_{}", Local::now().format("%Y%m%d_%H%M%S"))
    );

    if !Path::new(&binary).exists() {
        log_fail!("binary not found: {}", binary);
        log_dim!("hint: run 'meson compile -C builddir' first");
        std::process::exit(1);
    }

    if !workload_dir.is_dir() {
        log_fail!("workloads directory not found: {}", workload_dir.display());
        std::process::exit(1);
    }

    let mut campaign = Campaign {
        binary: binary,
        workload_dir: workload_dir,
        results_dir: results_dir,
        engine_filter: cli.engine,
        workload_from: cli.workload_from,
        workload_to: cli.workload_to,
        repetitions: cli.repetitions,
        workloads: Vec::new(),
        start_time: std::time::Instant::now(),
        duration: std::time::Duration::new(0, 0),
        passed: 0,
        failed: 0,
    };

    campaign.discover();

    if campaign.workloads.is_empty() {
        log_fail!("no workloads matched (engine={})", campaign.engine_filter);
        std::process::exit(1);
    }

    campaign.print_header();
    campaign.run();
    campaign.print_summary();

    std::process::exit(if campaign.failed > 0 { 1 } else { 0 });
}

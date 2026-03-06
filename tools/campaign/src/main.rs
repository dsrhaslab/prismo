use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Instant;

use chrono::Local;
use clap::Parser;

// ─────────────────────────────────────────────────────────────────────────────
//  CLI
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Parser)]
#[command(name = "campagne", about = "Campaign runner for prismo workloads")]
struct Cli {
    /// Path to the prismo binary
    #[arg(short, long, default_value = "builddir/prismo")]
    binary: String,

    /// Directory containing workload JSON files
    #[arg(short = 'd', long = "workloads-dir", default_value = "workloads/campaign")]
    workloads_dir: String,

    /// Results output directory (default: workloads/results/campaign_<timestamp>)
    #[arg(short, long)]
    output: Option<String>,

    /// Filter by engine: posix | uring | aio | spdk | all
    #[arg(short, long, default_value = "all")]
    engine: String,

    /// Run only workloads numbered X:Y (e.g. 1:18)
    #[arg(short, long)]
    workloads: Option<String>,

    /// Repetitions per workload
    #[arg(short, long, default_value_t = 1)]
    repetitions: usize,

    /// List workloads without executing
    #[arg(short = 'n', long)]
    dry_run: bool,
}

// ─────────────────────────────────────────────────────────────────────────────
//  Colors
// ─────────────────────────────────────────────────────────────────────────────

struct Colors {
    reset: &'static str,
    bold: &'static str,
    dim: &'static str,
    red: &'static str,
    green: &'static str,
    yellow: &'static str,
    cyan: &'static str,
}

const COLORS_ON: Colors = Colors {
    reset: "\x1b[0m",
    bold: "\x1b[1m",
    dim: "\x1b[2m",
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
};

const COLORS_OFF: Colors = Colors {
    reset: "",
    bold: "",
    dim: "",
    red: "",
    green: "",
    yellow: "",
    cyan: "",
};

fn detect_colors() -> &'static Colors {
    if atty::is(atty::Stream::Stdout) {
        &COLORS_ON
    } else {
        &COLORS_OFF
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Logging
// ─────────────────────────────────────────────────────────────────────────────

macro_rules! log_bold {
    ($c:expr, $($arg:tt)*) => {
        println!("{}{}{}", $c.bold, format!($($arg)*), $c.reset);
    };
}

macro_rules! log_info {
    ($c:expr, $($arg:tt)*) => {
        println!("{}:: {}{}", $c.cyan, $c.reset, format!($($arg)*));
    };
}

macro_rules! log_ok {
    ($c:expr, $($arg:tt)*) => {
        println!("{} ✓ {}{}", $c.green, $c.reset, format!($($arg)*));
    };
}

macro_rules! log_fail {
    ($c:expr, $($arg:tt)*) => {
        println!("{} ✗ {}{}", $c.red, $c.reset, format!($($arg)*));
    };
}

macro_rules! log_dim {
    ($c:expr, $($arg:tt)*) => {
        println!("{}   {}{}", $c.dim, format!($($arg)*), $c.reset);
    };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Utilities
// ─────────────────────────────────────────────────────────────────────────────

fn elapsed_fmt(secs: u64) -> String {
    if secs >= 60 {
        format!("{}m{:02}s", secs / 60, secs % 60)
    } else {
        format!("{}s", secs)
    }
}

fn get_engine(name: &str) -> &str {
    if name.ends_with("_spdk") {
        "spdk"
    } else if name.ends_with("_aio") {
        "aio"
    } else if name.ends_with("_uring") {
        "uring"
    } else {
        "posix"
    }
}

fn parse_workload_number(name: &str) -> Option<usize> {
    name.split('_').next()?.parse().ok()
}

// ─────────────────────────────────────────────────────────────────────────────
//  JSON extraction (replaces extract_report_json.py)
// ─────────────────────────────────────────────────────────────────────────────

fn extract_last_json(text: &str) -> Option<serde_json::Value> {
    let end = text.rfind('}')?;
    let bytes = text.as_bytes();
    let mut depth: i32 = 0;
    let mut start = None;

    for i in (0..=end).rev() {
        match bytes[i] {
            b'}' => depth += 1,
            b'{' => {
                depth -= 1;
                if depth == 0 {
                    start = Some(i);
                    break;
                }
            }
            _ => {}
        }
    }

    let start = start?;
    serde_json::from_str(&text[start..=end]).ok()
}

// ─────────────────────────────────────────────────────────────────────────────
//  CSV summary (replaces summarize_campaign.py)
// ─────────────────────────────────────────────────────────────────────────────

fn write_summary_csv(results_dir: &Path, c: &Colors) -> bool {
    let mut reports: Vec<PathBuf> = fs::read_dir(results_dir)
        .into_iter()
        .flatten()
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| {
            p.to_str()
                .map(|s| s.ends_with(".report.json"))
                .unwrap_or(false)
        })
        .collect();

    if reports.is_empty() {
        return false;
    }

    reports.sort();

    let csv_path = results_dir.join("summary.csv");
    let mut wtr = match csv::Writer::from_path(&csv_path) {
        Ok(w) => w,
        Err(_) => return false,
    };

    // header
    let _ = wtr.write_record([
        "workload",
        "jobs",
        "runtime_sec",
        "total_operations",
        "total_bytes",
        "overall_iops",
        "overall_bandwidth_bytes_per_sec",
        "weighted_avg_latency_ns",
        "weighted_p99_latency_ns",
    ]);

    for rp in &reports {
        match summarize_report(rp) {
            Ok(row) => {
                let _ = wtr.write_record([
                    &row.workload,
                    &row.jobs.to_string(),
                    &format!("{:.6}", row.runtime_sec),
                    &row.total_operations.to_string(),
                    &row.total_bytes.to_string(),
                    &format!("{:.2}", row.overall_iops),
                    &format!("{:.2}", row.overall_bw),
                    &format!("{:.2}", row.weighted_avg_lat_ns),
                    &format!("{:.2}", row.weighted_p99_lat_ns),
                ]);
            }
            Err(e) => {
                log_fail!(
                    c,
                    "Failed to summarize {}: {}",
                    rp.file_name().unwrap_or_default().to_string_lossy(),
                    e
                );
            }
        }
    }

    let _ = wtr.flush();
    true
}

struct SummaryRow {
    workload: String,
    jobs: usize,
    runtime_sec: f64,
    total_operations: u64,
    total_bytes: u64,
    overall_iops: f64,
    overall_bw: f64,
    weighted_avg_lat_ns: f64,
    weighted_p99_lat_ns: f64,
}

fn summarize_report(path: &Path) -> Result<SummaryRow, Box<dyn std::error::Error>> {
    let text = fs::read_to_string(path)?;
    let data: serde_json::Value = serde_json::from_str(&text)?;
    let jobs_arr = data["jobs"]
        .as_array()
        .ok_or("missing 'jobs' array")?;

    let mut workload = path
        .file_stem()
        .unwrap_or_default()
        .to_string_lossy()
        .to_string();

    if let Some(stripped) = workload.strip_suffix(".report") {
        workload = stripped.to_string();
    }

    let mut row = SummaryRow {
        workload,
        jobs: jobs_arr.len(),
        runtime_sec: 0.0,
        total_operations: 0,
        total_bytes: 0,
        overall_iops: 0.0,
        overall_bw: 0.0,
        weighted_avg_lat_ns: 0.0,
        weighted_p99_lat_ns: 0.0,
    };

    let mut weighted_p99 = 0.0_f64;
    let mut weighted_avg = 0.0_f64;

    for job in jobs_arr {
        let job_ops = job["total_operations"].as_u64().unwrap_or(0);
        row.total_operations += job_ops;
        row.total_bytes += job["total_bytes"].as_u64().unwrap_or(0);

        let rt = job["runtime_sec"].as_f64().unwrap_or(0.0);
        if rt > row.runtime_sec {
            row.runtime_sec = rt;
        }

        row.overall_iops += job["overall_iops"].as_f64().unwrap_or(0.0);
        row.overall_bw += job["overall_bandwidth_bytes_per_sec"]
            .as_f64()
            .unwrap_or(0.0);

        if let Some(ops) = job["operations"].as_array() {
            for op in ops {
                let count = op["count"].as_u64().unwrap_or(0) as f64;
                let p99 = op["percentiles_ns"]["p99"].as_f64().unwrap_or(0.0);
                let avg = op["latency_ns"]["avg"].as_f64().unwrap_or(0.0);
                weighted_p99 += p99 * count;
                weighted_avg += avg * count;
            }
        }
    }

    if row.total_operations > 0 {
        let total = row.total_operations as f64;
        row.weighted_p99_lat_ns = weighted_p99 / total;
        row.weighted_avg_lat_ns = weighted_avg / total;
    }

    Ok(row)
}

// ─────────────────────────────────────────────────────────────────────────────
//  Workload entry
// ─────────────────────────────────────────────────────────────────────────────

struct Workload {
    name: String,
    engine: String,
    #[allow(dead_code)]
    number: usize,
    config: PathBuf,
}

// ─────────────────────────────────────────────────────────────────────────────
//  Campaign
// ─────────────────────────────────────────────────────────────────────────────

struct Campaign {
    binary: String,
    workload_dir: PathBuf,
    results_dir: PathBuf,
    engine_filter: String,
    workload_from: usize,
    workload_to: usize,
    repetitions: usize,
    dry_run: bool,

    workloads: Vec<Workload>,
    passed: usize,
    failed: usize,
    failed_names: Vec<String>,
}

impl Campaign {
    fn discover(&mut self) {
        let mut configs: Vec<PathBuf> = fs::read_dir(&self.workload_dir)
            .into_iter()
            .flatten()
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.extension().map(|e| e == "json").unwrap_or(false))
            .collect();

        configs.sort();

        for cfg in configs {
            let name = cfg
                .file_stem()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();

            let engine = get_engine(&name).to_string();
            let num = parse_workload_number(&name).unwrap_or(0);

            // engine filter
            if self.engine_filter != "all" && engine != self.engine_filter {
                continue;
            }

            // range filter
            if self.workload_from > 0 && self.workload_to > 0 {
                if num < self.workload_from || num > self.workload_to {
                    continue;
                }
            }

            self.workloads.push(Workload {
                name,
                engine,
                number: num,
                config: cfg,
            });
        }
    }

    fn print_header(&self, c: &Colors) {
        println!();
        log_bold!(c, "╔══════════════════════════════════════════════════════════════════╗");
        log_bold!(c, "║                    PRISMO CAMPAIGN RUNNER                       ║");
        log_bold!(c, "╚══════════════════════════════════════════════════════════════════╝");
        println!();
        log_info!(c, "Binary:       {}", self.binary);
        log_info!(c, "Workloads:    {}", self.workload_dir.display());
        log_info!(c, "Results:      {}", self.results_dir.display());
        log_info!(c, "Engine:       {}", self.engine_filter);

        if self.workload_from > 0 && self.workload_to > 0 {
            log_info!(c, "Range:        {} — {}", self.workload_from, self.workload_to);
        } else {
            log_info!(c, "Range:        all");
        }

        let total = self.workloads.len();
        log_info!(c, "Repetitions:  {}", self.repetitions);
        log_info!(
            c,
            "Total runs:   {} workload(s) × {} rep(s) = {}",
            total,
            self.repetitions,
            total * self.repetitions
        );
        println!();
    }

    fn run_single(&mut self, idx: usize, progress: &str, c: &Colors) {
        let wl = &self.workloads[idx];
        let wl_name = wl.name.clone();
        let wl_config = wl.config.clone();

        for rep in 1..=self.repetitions {
            let rep_suffix = if self.repetitions > 1 {
                format!("_rep{}", rep)
            } else {
                String::new()
            };

            let rep_label = if self.repetitions > 1 {
                format!(" (rep {}/{})", rep, self.repetitions)
            } else {
                String::new()
            };

            let out_json = self
                .results_dir
                .join(format!("{}{}.report.json", wl_name, rep_suffix));

            print!(
                "  {}{}{} {:<45}{}",
                c.cyan, progress, c.reset, wl_name, rep_label
            );
            let _ = std::io::stdout().flush();

            let start = Instant::now();

            let result = Command::new(&self.binary)
                .arg("-c")
                .arg(&wl_config)
                .output();

            let elapsed = start.elapsed().as_secs();

            match result {
                Ok(output) if output.status.success() => {
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let combined = format!(
                        "{}{}",
                        stdout,
                        String::from_utf8_lossy(&output.stderr)
                    );

                    if let Some(json) = extract_last_json(&combined) {
                        if let Ok(text) = serde_json::to_string_pretty(&json) {
                            let _ = fs::write(&out_json, format!("{}\n", text));
                        }
                        println!(
                            "  {}OK{}   {}({}){}",
                            c.green,
                            c.reset,
                            c.dim,
                            elapsed_fmt(elapsed),
                            c.reset
                        );
                        self.passed += 1;
                    } else {
                        println!(
                            "  {}WARN{} {}(JSON extraction failed — {}){}",
                            c.yellow,
                            c.reset,
                            c.dim,
                            elapsed_fmt(elapsed),
                            c.reset
                        );
                        self.failed += 1;
                        self.failed_names
                            .push(format!("{}{} (json-extract)", wl_name, rep_suffix));
                    }
                }
                Ok(output) => {
                    let code = output.status.code().unwrap_or(-1);
                    println!(
                        "  {}FAIL{} {}(exit {} — {}){}",
                        c.red,
                        c.reset,
                        c.dim,
                        code,
                        elapsed_fmt(elapsed),
                        c.reset
                    );
                    self.failed += 1;
                    self.failed_names
                        .push(format!("{}{} (exit {})", wl_name, rep_suffix, code));
                }
                Err(e) => {
                    println!(
                        "  {}FAIL{} {}({} — {}){}",
                        c.red,
                        c.reset,
                        c.dim,
                        e,
                        elapsed_fmt(elapsed),
                        c.reset
                    );
                    self.failed += 1;
                    self.failed_names
                        .push(format!("{}{} ({})", wl_name, rep_suffix, e));
                }
            }
        }
    }

    fn run(&mut self, c: &Colors) {
        let total = self.workloads.len();
        let mut prev_engine = String::new();
        let campaign_start = Instant::now();

        if self.dry_run {
            log_info!(c, "DRY RUN — listing workloads that would execute:");
            println!();
        }

        for i in 0..total {
            let engine = self.workloads[i].engine.clone();
            let name = self.workloads[i].name.clone();

            if engine != prev_engine {
                println!();
                log_bold!(c, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                log_bold!(c, "  Engine: {}", engine.to_uppercase());
                log_bold!(c, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                prev_engine = engine.clone();
            }

            let progress = format!("[{}/{}]", i + 1, total);

            if self.dry_run {
                log_info!(c, "{} {}  (engine={})", progress, name, engine);
                continue;
            }

            self.run_single(i, &progress, c);
        }

        if self.dry_run {
            println!();
            log_info!(c, "Dry run complete. {} workload(s) would execute.", total);
            return;
        }

        let campaign_elapsed = campaign_start.elapsed().as_secs();
        self.print_summary(campaign_elapsed, c);
    }

    fn print_summary(&self, elapsed: u64, c: &Colors) {
        println!();
        log_bold!(c, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        log_bold!(c, "  SUMMARY");
        log_bold!(c, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

        if write_summary_csv(&self.results_dir, c) {
            log_info!(
                c,
                "Summary CSV:  {}",
                self.results_dir.join("summary.csv").display()
            );
        } else {
            log_fail!(c, "Failed to generate summary CSV");
        }

        println!();
        log_ok!(c, "Passed:   {}", self.passed);

        if self.failed > 0 {
            log_fail!(c, "Failed:   {}", self.failed);
            for name in &self.failed_names {
                log_dim!(c, "· {}", name);
            }
        } else {
            log_info!(c, "Failed:   0");
        }

        let total = self.workloads.len() * self.repetitions;
        log_info!(c, "Total:    {} / {}", self.passed + self.failed, total);
        log_info!(c, "Elapsed:  {}", elapsed_fmt(elapsed));
        log_info!(c, "Results:  {}", self.results_dir.display());
        println!();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main
// ─────────────────────────────────────────────────────────────────────────────

fn main() {
    let c = detect_colors();
    let cli = Cli::parse();

    // Resolve root directory (binary default is relative to project root)
    let root_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent()?.parent()?.parent()?.parent().map(|p| p.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."));

    let binary = if cli.binary == "builddir/prismo" {
        root_dir.join(&cli.binary).to_string_lossy().to_string()
    } else {
        cli.binary
    };

    let workload_dir = if cli.workloads_dir == "workloads/campaign" {
        root_dir.join(&cli.workloads_dir)
    } else {
        PathBuf::from(&cli.workloads_dir)
    };

    // Parse workload range
    let (wl_from, wl_to) = if let Some(ref range) = cli.workloads {
        match range.split_once(':') {
            Some((a, b)) => match (a.parse::<usize>(), b.parse::<usize>()) {
                (Ok(from), Ok(to)) => (from, to),
                _ => {
                    log_fail!(c, "invalid range '{}' — expected X:Y (e.g. 1:18)", range);
                    std::process::exit(1);
                }
            },
            None => {
                log_fail!(c, "invalid range '{}' — expected X:Y (e.g. 1:18)", range);
                std::process::exit(1);
            }
        }
    } else {
        (0, 0)
    };

    // Output directory
    let results_dir = match cli.output {
        Some(out) => PathBuf::from(out),
        None => {
            let ts = Local::now().format("%Y%m%d_%H%M%S");
            root_dir.join(format!("workloads/results/campaign_{}", ts))
        }
    };

    // Validate binary
    if !Path::new(&binary).exists() {
        log_fail!(c, "binary not found: {}", binary);
        log_dim!(c, "hint: run 'meson compile -C builddir' first");
        std::process::exit(1);
    }

    if !workload_dir.is_dir() {
        log_fail!(c, "workloads directory not found: {}", workload_dir.display());
        std::process::exit(1);
    }

    let mut campaign = Campaign {
        binary,
        workload_dir,
        results_dir,
        engine_filter: cli.engine,
        workload_from: wl_from,
        workload_to: wl_to,
        repetitions: cli.repetitions,
        dry_run: cli.dry_run,
        workloads: Vec::new(),
        passed: 0,
        failed: 0,
        failed_names: Vec::new(),
    };

    campaign.discover();

    if campaign.workloads.is_empty() {
        log_fail!(c, "no workloads matched (engine={})", campaign.engine_filter);
        std::process::exit(1);
    }

    campaign.print_header(c);

    if !campaign.dry_run {
        let _ = fs::create_dir_all(&campaign.results_dir);
    }

    campaign.run(c);

    std::process::exit(if campaign.failed > 0 { 1 } else { 0 });
}

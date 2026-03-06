use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;

use colored::Colorize;

use crate::logging::{log_banner, log_dim, log_fail, log_info, log_ok, log_section};
use crate::report::write_summary_csv;

const LABEL_WIDTH: usize = 14;

pub fn elapsed_fmt(secs: u64) -> String {
    if secs >= 60 {
        format!("{}m{:02}s", secs / 60, secs % 60)
    } else {
        format!("{}s", secs)
    }
}

pub fn get_engine(name: &str) -> &str {
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

pub fn parse_workload_number(name: &str) -> Option<usize> {
    name.split('_').next()?.parse().ok()
}

pub struct Workload {
    pub name: String,
    pub engine: String,
    #[allow(dead_code)]
    pub number: usize,
    pub config: PathBuf,
}

pub struct Campaign {
    pub binary: String,
    pub workload_dir: PathBuf,
    pub results_dir: PathBuf,
    pub engine_filter: String,
    pub workload_from: usize,
    pub workload_to: usize,
    pub repetitions: usize,
    pub dry_run: bool,

    pub workloads: Vec<Workload>,
    pub passed: usize,
    pub failed: usize,
    pub failed_names: Vec<String>,
}

impl Campaign {
    pub fn discover(&mut self) {
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

            if self.engine_filter != "all" && engine != self.engine_filter {
                continue;
            }

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

    pub fn print_header(&self) {
        log_banner!("PRISMO CAMPAIGN RUNNER");
        log_info!("{:<LABEL_WIDTH$} {}", "Binary:", self.binary);
        log_info!("{:<LABEL_WIDTH$} {}", "Workloads:", self.workload_dir.display());
        log_info!("{:<LABEL_WIDTH$} {}", "Results:", self.results_dir.display());
        log_info!("{:<LABEL_WIDTH$} {}", "Engine:", self.engine_filter);

        if self.workload_from > 0 && self.workload_to > 0 {
            log_info!("{:<LABEL_WIDTH$} {} - {}", "Range:", self.workload_from, self.workload_to);
        } else {
            log_info!("{:<LABEL_WIDTH$} {}", "Range:", "all");
        }

        let total = self.workloads.len();
        log_info!("{:<LABEL_WIDTH$} {}", "Repetitions", self.repetitions);
        log_info!("{:<LABEL_WIDTH$} {} workload(s) x {} rep(s) = {}",
            "Total runs:",
            total,
            self.repetitions,
            total * self.repetitions
        );
    }

    fn run_single(&mut self, idx: usize, progress: &str) {
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
                "  {} {:<45}{}",
                progress.cyan(), wl_name, rep_label
            );
            let _ = std::io::stdout().flush();

            let start = Instant::now();

            let result = Command::new(&self.binary)
                .arg("-c")
                .arg(&wl_config)
                .arg("-o")
                .arg(&out_json)
                .output();

            let elapsed = start.elapsed().as_secs();

            match result {
                Ok(output) if output.status.success() => {
                    println!(
                        "  {}   {}",
                        "OK".green(),
                        format!("({})", elapsed_fmt(elapsed)).dimmed()
                    );
                    self.passed += 1;
                }
                Ok(output) => {
                    let code = output.status.code().unwrap_or(-1);
                    println!(
                        "  {}   {}",
                        "FAIL".red(),
                        format!("(exit {} — {})", code, elapsed_fmt(elapsed)).dimmed()
                    );
                    self.failed += 1;
                    self.failed_names
                        .push(format!("{}{} (exit {})", wl_name, rep_suffix, code));
                }
                Err(e) => {
                    println!(
                        "  {}   {}",
                        "FAIL".red(),
                        format!("({} — {})", e, elapsed_fmt(elapsed)).dimmed()
                    );
                    self.failed += 1;
                    self.failed_names
                        .push(format!("{}{} ({})", wl_name, rep_suffix, e));
                }
            }
        }
    }

    pub fn run(&mut self) {
        let total = self.workloads.len();
        let mut prev_engine = String::new();
        let campaign_start = Instant::now();

        if self.dry_run {
            log_info!("DRY RUN — listing workloads that would execute:");
            println!();
        }

        for i in 0..total {
            let engine = self.workloads[i].engine.clone();
            let name = self.workloads[i].name.clone();

            if engine != prev_engine {
                log_section!(format!("Engine: {}", engine.to_uppercase()));
                prev_engine = engine.clone();
            }

            let progress = format!("[{}/{}]", i + 1, total);

            if self.dry_run {
                log_info!("{} {}  (engine={})", progress, name, engine);
                continue;
            }

            self.run_single(i, &progress);
        }

        if self.dry_run {
            println!();
            log_info!("Dry run complete. {} workload(s) would execute.", total);
            return;
        }

        let campaign_elapsed = campaign_start.elapsed().as_secs();
        self.print_summary(campaign_elapsed);
    }

    fn print_summary(&self, elapsed: u64) {
        log_section!("SUMMARY");

        if write_summary_csv(&self.results_dir) {
            log_info!(
                "{:<LABEL_WIDTH$} {}",
                "Summary CSV:",
                self.results_dir.join("summary.csv").display()
            );
        } else {
            log_fail!("Failed to generate summary CSV");
        }

        println!();
        log_ok!("{:<LABEL_WIDTH$} {}", "Passed:", self.passed);

        if self.failed > 0 {
            log_fail!("{:<LABEL_WIDTH$} {}", "Failed:", self.failed);
            for name in &self.failed_names {
                log_dim!("· {}", name);
            }
        } else {
            log_info!("{:<LABEL_WIDTH$} {}", "Failed:", 0);
        }

        let total = self.workloads.len() * self.repetitions;
        log_info!(
            "{:<LABEL_WIDTH$} {} / {}",
            "Total:",
            self.passed + self.failed,
            total
        );
        log_info!("{:<LABEL_WIDTH$} {}", "Elapsed:", elapsed_fmt(elapsed));
        log_info!("{:<LABEL_WIDTH$} {}", "Results:", self.results_dir.display());
        println!();
    }
}

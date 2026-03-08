use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, Instant};
use crate::logging::{
    log_banner, log_labeled, log_workload_fail, log_workload_ok, log_workload_start
};

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
    pub workloads: Vec<Workload>,

    pub start_time: Instant,
    pub duration: Duration,

    pub passed: usize,
    pub failed: usize,
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
                name: name,
                config: cfg,
            });
        }
    }

    pub fn print_header(&self) {
        log_banner("CONFIGURATION");
        log_labeled("Binary", &self.binary);
        log_labeled("Workloads", &self.workload_dir.display());
        log_labeled("Results", &self.results_dir.display());
        log_labeled("Engine", &self.engine_filter);

        if self.workload_from > 0 && self.workload_to > 0 {
            log_labeled("Range", format!("{} - {}", self.workload_from, self.workload_to));
        } else {
            log_labeled("Range", "all");
        }

        let total = self.workloads.len();
        log_labeled("Repetitions", self.repetitions);
        log_labeled(
            "Total runs",
            format!("{} workload(s) x {} rep(s) = {}", total, self.repetitions, total * self.repetitions)
        );
    }

    fn run_single(&mut self, wl_idx: usize, progress: &str) {
        let wl = &self.workloads[wl_idx];

        for rep in 1..=self.repetitions {
            let rep_suffix = format!("_rep{}", rep);
            let rep_label = format!(" (rep {}/{})", rep, self.repetitions);
            let out_json = self
                .results_dir
                .join(format!("{}{}.report.json", &wl.name, rep_suffix));

            log_workload_start(progress, &wl.name);

            let start = Instant::now();
            let result = Command::new(&self.binary)
                .arg("-c")
                .arg(&wl.config)
                .arg("-o")
                .arg(&out_json)
                .output();

            let elapsed = start.elapsed().as_secs();

            match result {
                Ok(output) if output.status.success() => {
                    log_workload_ok(&rep_label, &elapsed_fmt(elapsed));
                    self.passed += 1;
                }
                Ok(output) => {
                    let code = output.status.code().unwrap_or(-1);
                    log_workload_fail(&rep_label, &format!("(exit {} — {})", code, elapsed_fmt(elapsed)));
                    self.failed += 1;
                }
                Err(e) => {
                    log_workload_fail(&rep_label, &format!("({} — {})", e, elapsed_fmt(elapsed)));
                    self.failed += 1;
                }
            }
        }
    }

    pub fn run(&mut self) {
        log_banner("EXECUTION");
        let _ = fs::create_dir_all(&self.results_dir);
        let total = self.workloads.len();
        self.start_time = Instant::now();

        for i in 0..total {
            let progress = format!("[{}/{}]", i + 1, total);
            self.run_single(i, &progress);
        }

        self.duration = self.start_time.elapsed();
    }

    pub fn print_summary(&self) {
        log_banner("SUMMARY");
        log_labeled("Passed", self.passed);
        log_labeled("Failed", self.failed);

        let total = self.workloads.len() * self.repetitions;
        log_labeled(
            "Total",
            format!("{} / {}", self.passed + self.failed, total)
        );

        log_labeled("Elapsed", elapsed_fmt(self.duration.as_secs()));
        log_labeled("Results", &self.results_dir.display());
    }
}

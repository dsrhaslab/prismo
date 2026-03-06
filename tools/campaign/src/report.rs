use std::fs;
use std::path::{Path, PathBuf};

use crate::logging::log_fail;

// ─────────────────────────────────────────────────────────────────────────────
//  CSV summary
// ─────────────────────────────────────────────────────────────────────────────

pub struct SummaryRow {
    pub workload: String,
    pub jobs: usize,
    pub runtime_sec: f64,
    pub total_operations: u64,
    pub total_bytes: u64,
    pub overall_iops: f64,
    pub overall_bw: f64,
    pub weighted_avg_lat_ns: f64,
    pub weighted_p99_lat_ns: f64,
}

pub fn summarize_report(path: &Path) -> Result<SummaryRow, Box<dyn std::error::Error>> {
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

    // Use the "all" merged entry when present (numjobs > 1),
    // otherwise fall back to the single job entry.
    let summary = jobs_arr
        .iter()
        .find(|j| j["job_id"] == "all")
        .or_else(|| jobs_arr.first())
        .ok_or("empty 'jobs' array")?;

    // Count real jobs (excluding the synthetic "all" entry)
    let num_jobs = jobs_arr
        .iter()
        .filter(|j| j["job_id"] != "all")
        .count();

    let total_ops = summary["total_operations"].as_u64().unwrap_or(0);

    let mut weighted_p99 = 0.0_f64;
    let mut weighted_avg = 0.0_f64;

    if let Some(ops) = summary["operations"].as_array() {
        for op in ops {
            let count = op["count"].as_u64().unwrap_or(0) as f64;
            let p99 = op["percentiles_ns"]["p99"].as_f64().unwrap_or(0.0);
            let avg = op["latency_ns"]["avg"].as_f64().unwrap_or(0.0);
            weighted_p99 += p99 * count;
            weighted_avg += avg * count;
        }
    }

    let (wavg, wp99) = if total_ops > 0 {
        let t = total_ops as f64;
        (weighted_avg / t, weighted_p99 / t)
    } else {
        (0.0, 0.0)
    };

    Ok(SummaryRow {
        workload,
        jobs: num_jobs,
        runtime_sec: summary["runtime_sec"].as_f64().unwrap_or(0.0),
        total_operations: total_ops,
        total_bytes: summary["total_bytes"].as_u64().unwrap_or(0),
        overall_iops: summary["overall_iops"].as_f64().unwrap_or(0.0),
        overall_bw: summary["overall_bandwidth_bytes_per_sec"]
            .as_f64()
            .unwrap_or(0.0),
        weighted_avg_lat_ns: wavg,
        weighted_p99_lat_ns: wp99,
    })
}

pub fn write_summary_csv(results_dir: &Path) -> bool {
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

#!/usr/bin/env python3
import csv
import json
import sys
from pathlib import Path


def flatten_ops(job: dict):
    ops = {}
    for op in job.get("operations", []):
        name = op.get("operation", "unknown")
        ops[name] = {
            "count": op.get("count", 0),
            "iops": op.get("iops", 0),
            "bw": op.get("bandwidth_bytes_per_sec", 0),
            "p99": op.get("percentiles_ns", {}).get("p99", 0),
            "avg_lat": op.get("latency_ns", {}).get("avg", 0),
        }
    return ops


def summarize_report(report_path: Path):
    data = json.loads(report_path.read_text())
    jobs = data.get("jobs", [])

    total_ops = 0
    total_bytes = 0
    weighted_p99 = 0.0
    weighted_avg_lat = 0.0
    total_iops = 0.0
    total_bw = 0.0
    runtime = 0.0

    for job in jobs:
        job_ops = job.get("total_operations", 0)
        total_ops += job_ops
        total_bytes += job.get("total_bytes", 0)
        runtime = max(runtime, float(job.get("runtime_sec", 0.0)))
        total_iops += float(job.get("overall_iops", 0.0))
        total_bw += float(job.get("overall_bandwidth_bytes_per_sec", 0.0))

        ops = flatten_ops(job)
        if job_ops > 0:
            p99_num = sum(op["p99"] * op["count"] for op in ops.values())
            avg_num = sum(op["avg_lat"] * op["count"] for op in ops.values())
            weighted_p99 += p99_num
            weighted_avg_lat += avg_num

    p99_ns = weighted_p99 / total_ops if total_ops else 0.0
    avg_lat_ns = weighted_avg_lat / total_ops if total_ops else 0.0

    return {
        "workload": report_path.name.replace(".report.json", ""),
        "jobs": len(jobs),
        "runtime_sec": runtime,
        "total_operations": total_ops,
        "total_bytes": total_bytes,
        "overall_iops": total_iops,
        "overall_bandwidth_bytes_per_sec": total_bw,
        "weighted_avg_latency_ns": round(avg_lat_ns, 2),
        "weighted_p99_latency_ns": round(p99_ns, 2),
    }


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize_campaign.py <results_dir>")
        return 1

    results_dir = Path(sys.argv[1])
    report_files = sorted(results_dir.glob("*.report.json"))

    if not report_files:
        print(f"no report files found in {results_dir}")
        return 1

    rows = [summarize_report(path) for path in report_files]

    out_csv = results_dir / "summary.csv"
    with out_csv.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {out_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

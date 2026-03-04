#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def extract_last_json_object(text: str) -> dict:
    end = text.rfind('}')
    if end == -1:
        raise ValueError("No JSON object end found in output")

    depth = 0
    start = -1
    for idx in range(end, -1, -1):
        ch = text[idx]
        if ch == '}':
            depth += 1
        elif ch == '{':
            depth -= 1
            if depth == 0:
                start = idx
                break

    if start == -1:
        raise ValueError("No balanced JSON object found in output")

    return json.loads(text[start:end + 1])


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_report_json.py <raw_output_log> <out_report_json>")
        return 1

    raw_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])

    raw_text = raw_path.read_text(errors="replace")
    report = extract_last_json_object(raw_text)
    out_path.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3

import json
import argparse
from datetime import datetime
from pathlib import Path

# Optional PDF export dependencies
try:
    import markdown
    import pdfkit
except ImportError:
    markdown = None
    pdfkit = None


# Constants
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_FILE = BASE_DIR / "data" / "correlated_data.json"


def load_data(file_path):
    if not file_path.exists():
        raise FileNotFoundError(f"Data file not found: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)


def format_wifi_section(entries):
    if not entries:
        return "## Wi-Fi Devices\nNo Wi-Fi data available.\n"

    lines = ["## Wi-Fi Devices\n"]
    for entry in entries:
        lines.append(f"- SSID: {entry.get('ssid', 'N/A')}")
        lines.append(f"  BSSID: {entry.get('bssid', 'N/A')}")
        lines.append(f"  Signal Strength: {entry.get('signal_strength', 'N/A')}")
        lines.append(f"  Channel: {entry.get('channel', 'N/A')}")
        lines.append(f"  Encryption: {entry.get('encryption', 'N/A')}")
        lines.append(f"  Times Seen: {entry.get('times_seen', 'N/A')}\n")
    return "\n".join(lines)


def format_bluetooth_section(entries):
    if not entries:
        return "## Bluetooth Devices\nNo Bluetooth data available.\n"

    lines = ["## Bluetooth Devices\n"]
    for entry in entries:
        lines.append(f"- Name: {entry.get('name', 'N/A')}")
        lines.append(f"  MAC Address: {entry.get('mac', 'N/A')}")
        lines.append(f"  Vendor: {entry.get('vendor', 'N/A')}")
        lines.append(f"  Signal Strength: {entry.get('signal_strength', 'N/A')}\n")
    return "\n".join(lines)


def format_osint_section(entries):
    if not entries:
        return "## OSINT Findings\nNo OSINT data available.\n"

    lines = ["## OSINT Findings\n"]
    for entry in entries:
        lines.append(f"- Type: {entry.get('type', 'N/A')}")
        lines.append(f"  Value: {entry.get('value', 'N/A')}")
        lines.append(f"  Source: {entry.get('source', 'N/A')}")
        lines.append(f"  Linked Device: {entry.get('linked_device', 'N/A')}\n")
    return "\n".join(lines)


def format_correlation_section(entries):
    if not entries:
        return "## Correlations\nNo correlation data available.\n"

    lines = ["## Correlations\n"]
    for entry in entries:
        lines.append(f"- Entities: {', '.join(entry.get('entities', []))}")
        lines.append(f"  Reason: {entry.get('reason', 'N/A')}")
        lines.append(f"  Timeframe: {entry.get('timeframe', 'N/A')}\n")
    return "\n".join(lines)


def generate_markdown(data):
    report_lines = [
        f"# OSINT Correlation Report",
        f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC\n"
    ]

    report_lines.append(format_wifi_section(data.get("wifi")))
    report_lines.append(format_bluetooth_section(data.get("bluetooth")))
    report_lines.append(format_osint_section(data.get("osint")))
    report_lines.append(format_correlation_section(data.get("correlations")))

    return "\n".join(report_lines)


def save_markdown(content, path):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[INFO] Markdown report written to: {path}")


def save_pdf(markdown_text, pdf_path):
    if not markdown or not pdfkit:
        print("[WARNING] PDF generation skipped. Install 'markdown' and 'pdfkit' to enable this feature.")
        return

    html = markdown.markdown(markdown_text)
    pdfkit.from_string(html, str(pdf_path))
    print(f"[INFO] PDF report written to: {pdf_path}")


def parse_args():
    parser = argparse.ArgumentParser(description="Generate a structured OSINT correlation report from JSON.")
    parser.add_argument("--output", help="Base output name (default: report-YYYYMMDD-HHMMSS)")
    parser.add_argument("--pdf", action="store_true", help="Generate PDF report in addition to Markdown")
    parser.add_argument("--input", help="Path to correlated_data.json (default is internal path)")
    return parser.parse_args()


def main():
    args = parse_args()
    input_path = Path(args.input) if args.input else DATA_FILE
    data = load_data(input_path)

    report = generate_markdown(data)
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    base_name = args.output or f"report-{timestamp}"
    md_path = Path(f"{base_name}.md")
    pdf_path = Path(f"{base_name}.pdf")

    save_markdown(report, md_path)

    if args.pdf:
        save_pdf(report, pdf_path)


if __name__ == "__main__":
    main()

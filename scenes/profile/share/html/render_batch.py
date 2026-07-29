#!/usr/bin/env python3
"""Render multiple RhythmFall Recap cards in one Playwright session."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from render_card import _inject_payload, _launch_browser


def main() -> int:
	parser = argparse.ArgumentParser(description="Render multiple Wrapped cards to PNG")
	parser.add_argument("--manifest", required=True, help="JSON manifest with html_dir, width, height, jobs[]")
	args = parser.parse_args()

	manifest_path = Path(args.manifest).resolve()
	if not manifest_path.is_file():
		print("MANIFEST_MISSING", file=sys.stderr)
		return 4

	manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
	html_dir = Path(str(manifest.get("html_dir", ""))).resolve()
	width = int(manifest.get("width", 1080))
	height = int(manifest.get("height", 1920))
	device_scale = float(manifest.get("device_scale_factor", 1.0))
	jobs = manifest.get("jobs", [])
	if not isinstance(jobs, list) or not jobs:
		print("JOBS_EMPTY", file=sys.stderr)
		return 4

	shell_path = html_dir / "card_shell.html"
	if not shell_path.is_file():
		print("SHELL_MISSING", file=sys.stderr)
		return 4

	try:
		from playwright.sync_api import sync_playwright
	except ImportError:
		print("PLAYWRIGHT_MISSING", file=sys.stderr)
		return 2

	temp_html = html_dir / "_render_batch_temp.html"
	try:
		with sync_playwright() as p:
			browser = _launch_browser(p)
			page = browser.new_page(
				viewport={"width": width, "height": height},
				device_scale_factor=device_scale,
			)
			for job in jobs:
				payload_path = Path(str(job.get("payload", ""))).resolve()
				out_path = Path(str(job.get("out", ""))).resolve()
				if not payload_path.is_file():
					print(f"PAYLOAD_MISSING: {payload_path}", file=sys.stderr)
					return 5
				payload = json.loads(payload_path.read_text(encoding="utf-8-sig"))
				_inject_payload(shell_path, payload, temp_html)
				out_path.parent.mkdir(parents=True, exist_ok=True)
				page.goto(temp_html.as_uri(), wait_until="load", timeout=15000)
				page.wait_for_timeout(60)
				card = page.locator("#card")
				card.wait_for(state="visible", timeout=10000)
				card.screenshot(path=str(out_path), type="png")
			browser.close()
	except Exception as exc:  # noqa: BLE001
		print(f"RENDER_FAILED: {exc}", file=sys.stderr)
		return 3
	finally:
		temp_html.unlink(missing_ok=True)

	print("OK")
	return 0


if __name__ == "__main__":
	sys.exit(main())

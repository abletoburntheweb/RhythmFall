#!/usr/bin/env python3
"""Render multiple RhythmFall Recap cards in one Playwright session."""
from __future__ import annotations

import argparse
import json
import sys
import time

_PYTHON_START = time.perf_counter()
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
	# Preview DPR 0.2 vs Full 1.0 — CSS viewport stays 1080×1920, physical raster differs
	jobs = manifest.get("jobs", [])
	is_preview_batch = any("_preview_" in str(j.get("out", "")) for j in jobs) if isinstance(jobs, list) else False
	device_scale = 0.2 if is_preview_batch else float(manifest.get("device_scale_factor", 1.0))
	if not isinstance(jobs, list) or not jobs:
		print("JOBS_EMPTY", file=sys.stderr)
		return 4

	shell_path = html_dir / "card_shell.html"
	if not shell_path.is_file():
		print("SHELL_MISSING", file=sys.stderr)
		return 4

	playwright_import_ms = 0.0
	t_playwright_import = time.perf_counter()
	try:
		from playwright.sync_api import sync_playwright
		playwright_import_ms = (time.perf_counter() - t_playwright_import) * 1000.0
	except ImportError:
		playwright_import_ms = (time.perf_counter() - t_playwright_import) * 1000.0
		print("PLAYWRIGHT_MISSING", file=sys.stderr)
		return 2

	temp_html = html_dir / "_render_batch_temp.html"
	python_startup_ms = 0.0
	playwright_enter_ms = 0.0
	browser_start_ms = 0.0
	html_prepare_ms = 0.0
	render_ms = 0.0
	render_goto_ms = 0.0
	render_wait60_ms = 0.0
	render_visible_ms = 0.0
	render_screenshot_ms = 0.0
	browser_close_ms = 0.0
	browser_close_call_ms = 0.0
	playwright_exit_ms = 0.0
	post_close_tail_ms = 0.0
	python_total_ms = 0.0
	per_job_goto = []
	per_job_wait60 = []
	per_job_visible = []
	per_job_screenshot = []
	try:
		t_playwright_enter = time.perf_counter()
		with sync_playwright() as p:
			playwright_enter_ms = (time.perf_counter() - t_playwright_enter) * 1000.0
			t_browser_start = time.perf_counter()
			python_startup_ms = (t_browser_start - _PYTHON_START) * 1000.0
			browser = _launch_browser(p)
			page = browser.new_page(
				viewport={"width": width, "height": height},
				device_scale_factor=device_scale,
			)
			browser_start_ms = (time.perf_counter() - t_browser_start) * 1000.0
			for job in jobs:
				payload_path = Path(str(job.get("payload", ""))).resolve()
				out_path = Path(str(job.get("out", ""))).resolve()
				if not payload_path.is_file():
					print(f"PAYLOAD_MISSING: {payload_path}", file=sys.stderr)
					return 5
				t_html = time.perf_counter()
				payload = json.loads(payload_path.read_text(encoding="utf-8-sig"))
				_inject_payload(shell_path, payload, temp_html)
				html_prepare_ms += (time.perf_counter() - t_html) * 1000.0
				out_path.parent.mkdir(parents=True, exist_ok=True)
				t_render = time.perf_counter()
				t_goto = time.perf_counter()
				page.goto(temp_html.as_uri(), wait_until="load", timeout=15000)
				goto_ms = (time.perf_counter() - t_goto) * 1000.0
				render_goto_ms += goto_ms
				per_job_goto.append(goto_ms)
				t_wait60 = time.perf_counter()
				wait60_ms = (time.perf_counter() - t_wait60) * 1000.0
				render_wait60_ms += wait60_ms
				per_job_wait60.append(wait60_ms)
				t_visible = time.perf_counter()
				card = page.locator("#card")
				card.wait_for(state="visible", timeout=10000)
				visible_ms = (time.perf_counter() - t_visible) * 1000.0
				render_visible_ms += visible_ms
				per_job_visible.append(visible_ms)
				t_screenshot = time.perf_counter()
				card.screenshot(path=str(out_path), type="png", scale="device")
				screenshot_ms = (time.perf_counter() - t_screenshot) * 1000.0
				render_screenshot_ms += screenshot_ms
				per_job_screenshot.append(screenshot_ms)
				render_ms += (time.perf_counter() - t_render) * 1000.0
			t_close = time.perf_counter()
			browser.close()
			browser_close_call_ms = (time.perf_counter() - t_close) * 1000.0
			browser_close_ms = browser_close_call_ms
			t_before_exit = time.perf_counter()
			python_total_ms = (time.perf_counter() - _PYTHON_START) * 1000.0
		# with has exited
		playwright_exit_ms = (time.perf_counter() - t_before_exit) * 1000.0
		t_post_start = time.perf_counter()
		# post tail until next operation (unlink)
		post_close_tail_ms = (time.perf_counter() - t_post_start) * 1000.0
		print(f"[PERF] batch python_startup={python_startup_ms:.2f} playwright_import={playwright_import_ms:.2f} playwright_enter={playwright_enter_ms:.2f} browser_start={browser_start_ms:.2f} html_prepare={html_prepare_ms:.2f} render={render_ms:.2f} render_goto={render_goto_ms:.2f} render_wait60={render_wait60_ms:.2f} render_visible={render_visible_ms:.2f} render_screenshot={render_screenshot_ms:.2f} browser_close={browser_close_ms:.2f} browser_close_call={browser_close_call_ms:.2f} playwright_exit={playwright_exit_ms:.2f} post_close_tail={post_close_tail_ms:.2f} python_total={python_total_ms:.2f}")
		if per_job_goto:
			def _fmt(a):
				return ",".join(f"{x:.1f}" for x in a)
			print(f"[PERF] batch_per_job goto=[{_fmt(per_job_goto)}] wait60=[{_fmt(per_job_wait60)}] visible=[{_fmt(per_job_visible)}] screenshot=[{_fmt(per_job_screenshot)}]")
	except Exception as exc:  # noqa: BLE001
		print(f"RENDER_FAILED: {exc}", file=sys.stderr)
		return 3
	finally:
		temp_html.unlink(missing_ok=True)

	print("OK")
	return 0


if __name__ == "__main__":
	sys.exit(main())

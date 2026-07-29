#!/usr/bin/env python3
"""Render a RhythmFall Wrapped card HTML template to PNG via Playwright."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _inject_payload(shell_path: Path, payload: dict, out_html: Path) -> None:
	shell = shell_path.read_text(encoding="utf-8")
	inject = "window.__CARD__ = " + json.dumps(payload, ensure_ascii=False) + ";"
	if "/*__CARD_DATA__*/" not in shell:
		raise RuntimeError("card_shell.html missing /*__CARD_DATA__*/ placeholder")
	html = shell.replace("/*__CARD_DATA__*/", inject)
	out_html.write_text(html, encoding="utf-8")


def _launch_browser(playwright):
	last_err = None
	for channel in ("msedge", "chrome", None):
		try:
			kwargs = {"headless": True}
			if channel:
				kwargs["channel"] = channel
			return playwright.chromium.launch(**kwargs)
		except Exception as exc:  # noqa: BLE001
			last_err = exc
	raise RuntimeError(f"Could not launch browser: {last_err}")


def main() -> int:
	parser = argparse.ArgumentParser(description="Render Wrapped card to PNG")
	parser.add_argument("--html-dir", required=True, help="Directory with card_shell.html, cards.css, cards.js")
	parser.add_argument("--payload", required=True, help="JSON payload file")
	parser.add_argument("--out", required=True, help="Output PNG path")
	parser.add_argument("--width", type=int, default=1080)
	parser.add_argument("--height", type=int, default=1920)
	parser.add_argument("--device-scale-factor", type=float, default=1.0, dest="device_scale_factor")
	args = parser.parse_args()

	html_dir = Path(args.html_dir).resolve()
	payload_path = Path(args.payload).resolve()
	out_path = Path(args.out).resolve()

	if not (html_dir / "card_shell.html").is_file():
		print("SHELL_MISSING", file=sys.stderr)
		return 4

	payload = json.loads(payload_path.read_text(encoding="utf-8-sig"))
	temp_html = html_dir / "_render_temp.html"
	try:
		_inject_payload(html_dir / "card_shell.html", payload, temp_html)
	except Exception as exc:  # noqa: BLE001
		print(f"INJECT_FAILED: {exc}", file=sys.stderr)
		return 5

	try:
		from playwright.sync_api import sync_playwright
	except ImportError:
		print("PLAYWRIGHT_MISSING", file=sys.stderr)
		return 2

	out_path.parent.mkdir(parents=True, exist_ok=True)
	url = temp_html.as_uri()

	try:
		with sync_playwright() as p:
			browser = _launch_browser(p)
			page = browser.new_page(
				viewport={"width": args.width, "height": args.height},
				device_scale_factor=args.device_scale_factor,
			)
			page.goto(url, wait_until="load", timeout=15000)
			page.wait_for_timeout(80)
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

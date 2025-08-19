#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path
from datetime import datetime
from playwright.sync_api import sync_playwright


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def run(url: str) -> None:
    artifacts = Path("artifacts")
    ensure_dir(artifacts)
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    screenshot_path = artifacts / f"viewer-{ts}.png"

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        logs: list[str] = []
        page.on("console", lambda msg: logs.append(f"[{msg.type}] {msg.text}"))

        page.goto(url, wait_until="load")
        # Wait specifically for the first heading to appear
        page.wait_for_selector("#markdown h1", timeout=10000)
        # Take screenshot
        page.screenshot(path=str(screenshot_path), full_page=True)

        # Emit a brief summary to stdout
        locator = page.locator("#markdown h1").first
        heading = locator.inner_text()
        print(f"OK viewer loaded. heading={heading!r} screenshot={screenshot_path}")
        if logs:
            print("Console logs:")
            for line in logs[:20]:
                print(line)
        browser.close()


if __name__ == "__main__":
    # Default to local server path
    url = os.environ.get("VIEWER_URL", "http://127.0.0.1:8000/code/miso/tools/viewer/web/index.html")
    run(url)



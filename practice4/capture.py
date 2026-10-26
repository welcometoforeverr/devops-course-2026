"""Capture the real application in Chromium after an RPC-backed POST."""
from pathlib import Path
from playwright.sync_api import sync_playwright
Path("evidence").mkdir(exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1280, "height": 900}, device_scale_factor=1)
    page.goto("http://127.0.0.1:8000/")
    page.get_by_role("button", name="Бросить кубики").click()
    page.wait_for_load_state("networkidle")
    assert "gRPC unavailable" not in page.inner_text("body")
    page.screenshot(path="evidence/django-dice.png", full_page=True)
    for port in (8001, 8002):
        page.goto(f"http://127.0.0.1:{port}/")
        page.get_by_role("button", name="Бросить кубики").click()
        page.wait_for_load_state("networkidle")
        assert "gRPC unavailable" not in page.inner_text("body")
        page.screenshot(path=f"evidence/django-{port}.png", full_page=True)
    browser.close()

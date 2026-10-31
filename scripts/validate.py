#!/usr/bin/env python3
"""Validate project files (used locally and in CI). Exit 1 on any failure."""
import json, re, sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
errors = []

def fail(msg):
    errors.append(msg)
    print(f"FAIL: {msg}")

def ok(msg):
    print(f"ok:   {msg}")

REQUIRED = ["app/index.html", "app/css/style.css", "app/js/app.js", "Dockerfile", ".dockerignore",
            "docker-compose.yml", "docker/nginx.conf", ".github/workflows/ci-cd.yml",
            "monitoring/monitor.sh", "monitoring/setup-cron.sh", "scripts/trivy-scan.sh",
            "deploy/ec2-bootstrap.sh", "deploy/nginx/devops-platform.conf", "README.md", ".gitignore"]
for f in REQUIRED:
    (ok if (ROOT / f).is_file() else fail)(f"required file {f}")

class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids = set(); self.refs = []
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a: self.ids.add(a["id"])
        for k in ("href", "src"):
            if k in a and a[k] and not a[k].startswith(("#", "http", "mailto:")):
                self.refs.append(a[k])

html_path = ROOT / "app/index.html"
if html_path.is_file():
    p = P(); p.feed(html_path.read_text(encoding="utf-8"))
    for i in ["health-badge", "d-version", "m-cpu", "m-mem", "m-disk", "m-up"]:
        (ok if i in p.ids else fail)(f"index.html has id '{i}'")
    for r in p.refs:
        (ok if (ROOT / "app" / r).is_file() else fail)(f"index.html references existing file {r}")

# secret scan
patterns = {"AWS access key": r"AKIA[0-9A-Z]{16}", "private key": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
            "GitHub token": r"gh[pousr]_[A-Za-z0-9]{36,}"}
skip = {".git", "reports", "logs"}
hits = 0
for f in ROOT.rglob("*"):
    if f.is_file() and not (set(f.relative_to(ROOT).parts) & skip) and f.name != "validate.py":
        try: txt = f.read_text(encoding="utf-8")
        except Exception: continue
        for name, pat in patterns.items():
            if re.search(pat, txt): fail(f"possible {name} in {f.relative_to(ROOT)}"); hits += 1
if not hits: ok("no secret patterns found")

for f in ROOT.rglob("*.json"):
    if not (set(f.relative_to(ROOT).parts) & skip):
        try: json.loads(f.read_text(encoding="utf-8")); ok(f"valid JSON {f.relative_to(ROOT)}")
        except Exception as e: fail(f"invalid JSON {f}: {e}")

if errors:
    print(f"\n{len(errors)} problem(s) found."); sys.exit(1)
print("\nAll validation checks passed.")

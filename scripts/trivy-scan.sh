#!/usr/bin/env bash
# trivy-scan.sh - scan a Docker image with Trivy (runs Trivy in a container; needs only Docker).
# Usage: ./scripts/trivy-scan.sh [image]   (default: devops-platform:local)
# Writes reports/trivy-report.txt, reports/trivy-report.json. Exits 1 if CRITICAL vulns found.
set -euo pipefail
IMAGE="${1:-devops-platform:local}"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
mkdir -p "$OUT_DIR"
command -v docker >/dev/null || { echo "ERROR: docker not found" >&2; exit 1; }
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "ERROR: image '$IMAGE' not found. Build it first." >&2; exit 1; }

run_trivy() {
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy-cache:/root/.cache/ -v "$OUT_DIR":/reports \
    aquasec/trivy:latest image "$@"
}

echo ">> Full report (all severities)"
run_trivy --severity CRITICAL,HIGH,MEDIUM,LOW --format table -o /reports/trivy-report.txt "$IMAGE"
run_trivy --severity CRITICAL,HIGH,MEDIUM,LOW --format json  -o /reports/trivy-report.json "$IMAGE"
cat "$OUT_DIR/trivy-report.txt"

echo ">> Policy gate: fail on CRITICAL (with a fix available)"
if run_trivy --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE" >/dev/null; then
  echo "PASS: no fixable CRITICAL vulnerabilities."
else
  echo "FAIL: fixable CRITICAL vulnerabilities found. See reports/trivy-report.txt" >&2
  exit 1
fi

#!/usr/bin/env bash
# Run *inside* gasclaw-mgmt only: gateway reachability + optional OpenClaw Telegram status + MiniMax check.
#
# Host usage (recommended — copies fix script so MiniMax can be re-applied after openclaw CLI):
#   scripts/run_inside_mgmt_health_suite.sh
#
# Raw (MiniMax verify may fail unless /tmp/fix_openclaw_minimax_local.py exists):
#   docker cp scripts/fix_openclaw_minimax_local.py gasclaw-mgmt:/tmp/
#   docker exec -i gasclaw-mgmt bash -s < scripts/inside_mgmt_health_suite.sh
#
# Optional env:
#   GASCLAW_BRIDGE_HOST=172.17.0.1

set -euo pipefail

BRIDGE="${GASCLAW_BRIDGE_HOST:-172.17.0.1}"

declare -A PORTS=(
  [gasclaw-minimax]=18793
  [gasclaw-dev]=18794
  [gasclaw-gasskill]=18796
  [gasclaw-context]=18797
  [gasclaw-mgmt]=18798
)

echo "=== Bridge host: $BRIDGE (override with GASCLAW_BRIDGE_HOST) ==="
echo

fail=0
for name in gasclaw-minimax gasclaw-dev gasclaw-gasskill gasclaw-context gasclaw-mgmt; do
  p="${PORTS[$name]}"
  if [[ "$name" == "gasclaw-mgmt" ]]; then
    host="127.0.0.1"
  else
    host="$BRIDGE"
  fi
  url="http://${host}:${p}/health"
  printf '%s %-18s :%s /health ' "$(date -Is)" "$name" "$p"
  if out=$(curl -sf -m 8 "$url" 2>/dev/null); then
    echo "$out"
    if ! echo "$out" | grep -q 'live'; then
      echo "  (unexpected body)" >&2
      fail=1
    fi
  else
    echo "FAIL"
    fail=1
  fi
  curl -sf -m 3 "http://${host}:${p}/ready" >/dev/null && echo "  /ready OK" || echo "  /ready FAIL" >&2
done

echo
echo "=== OpenClaw Telegram (this container) — NOTE: this CLI may rewrite agent models.json on some builds ==="
openclaw channels status 2>&1 || true

if [[ -f /tmp/fix_openclaw_minimax_local.py ]]; then
  echo
  echo "=== Re-applying MiniMax patch after openclaw CLI (undo kimi overwrite) ==="
  python3 /tmp/fix_openclaw_minimax_local.py 2>&1 || true
else
  echo
  echo "WARN: /tmp/fix_openclaw_minimax_local.py missing — copy from host: docker cp scripts/fix_openclaw_minimax_local.py gasclaw-mgmt:/tmp/" >&2
fi

echo
echo "=== MiniMax primary + per-agent models (this container) ==="
python3 <<'PY'
import glob
import json
import pathlib
import sys

PRIMARY = "moonshot/minimax-m2.5"
home = pathlib.Path.home()
oj = home / ".openclaw" / "openclaw.json"
if not oj.is_file():
    print("FAIL: missing ~/.openclaw/openclaw.json")
    sys.exit(1)
cfg = json.loads(oj.read_text(encoding="utf-8"))
primary = (cfg.get("agents") or {}).get("defaults", {}).get("model", {}).get("primary", "")
models = (cfg.get("agents") or {}).get("defaults", {}).get("models", {})
bad = [k for k in models if "kimi" in k.lower() or "k2p5" in k.lower()]
print("primary:", primary)
if primary != PRIMARY:
    print("FAIL: expected primary", PRIMARY)
    sys.exit(1)
if bad:
    print("FAIL: kimi entries in agents.defaults.models:", bad)
    sys.exit(1)
for mpath in glob.glob(str(home / ".openclaw" / "agents" / "*" / "agent" / "models.json")):
    raw = json.loads(pathlib.Path(mpath).read_text(encoding="utf-8"))
    prov = raw.get("providers") or {}
    if "kimi-coding" in prov:
        print("FAIL: kimi-coding provider still present in", mpath)
        sys.exit(1)
    moon = prov.get("moonshot") or {}
    mids = [m.get("id") for m in (moon.get("models") or [])]
    if "kimi-k2.5" in mids or "k2p5" in str(mids).lower():
        print("FAIL: kimi/k2 models in moonshot at", mpath, "ids:", mids)
        sys.exit(1)
    if mids and "minimax-m2.5" not in mids:
        print("FAIL: moonshot models must include minimax-m2.5:", mpath, mids)
        sys.exit(1)
print("OK: MiniMax configuration for gasclaw-mgmt")
PY

echo
echo "=== Peer containers: MiniMax (only if docker + /var/run/docker.sock in this container) ==="
if command -v docker >/dev/null 2>&1 && [[ -S /var/run/docker.sock ]]; then
  PRIMARY="moonshot/minimax-m2.5"
  for c in gasclaw-minimax gasclaw-dev gasclaw-gasskill gasclaw-context; do
    echo "--- $c ---"
    if ! docker exec "$c" true 2>/dev/null; then
      echo "SKIP (not running)"
      fail=1
      continue
    fi
    if ! docker exec -i "$c" python3 - "$PRIMARY" <<'PEERPY'
import glob
import json
import pathlib
import sys

want = sys.argv[1]
home = pathlib.Path.home()
oj = home / ".openclaw" / "openclaw.json"
if not oj.is_file():
    print("FAIL: missing openclaw.json")
    sys.exit(1)
cfg = json.loads(oj.read_text(encoding="utf-8"))
primary = (cfg.get("agents") or {}).get("defaults", {}).get("model", {}).get("primary", "")
models = (cfg.get("agents") or {}).get("defaults", {}).get("models", {})
bad = [k for k in models if "kimi" in k.lower() or "k2p5" in k.lower()]
print("primary:", primary)
if primary != want:
    print("FAIL: expected", want)
    sys.exit(1)
if bad:
    print("FAIL: kimi entries:", bad)
    sys.exit(1)
for mpath in glob.glob(str(home / ".openclaw" / "agents" / "*" / "agent" / "models.json")):
    raw = json.loads(pathlib.Path(mpath).read_text(encoding="utf-8"))
    prov = raw.get("providers") or {}
    if "kimi-coding" in prov:
        print("FAIL: kimi-coding in", mpath)
        sys.exit(1)
    moon = prov.get("moonshot") or {}
    mids = [m.get("id") for m in (moon.get("models") or [])]
    if "kimi-k2.5" in mids:
        print("FAIL: kimi-k2.5 in moonshot at", mpath)
        sys.exit(1)
    if mids and "minimax-m2.5" not in mids:
        print("FAIL: moonshot models must include minimax-m2.5:", mpath, mids)
        sys.exit(1)
print("OK")
PEERPY
    then
      fail=1
    fi
  done
else
  echo "SKIP (no Docker in this container). Peer MiniMax audit runs on the host via check_all_containers_minimax.sh."
  echo "To run peers from inside mgmt: mount /var/run/docker.sock and install docker CLI (see examples/gasclaw-mgmt-docker-socket.override.yml.example)."
fi

exit "$fail"

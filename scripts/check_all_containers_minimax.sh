#!/usr/bin/env bash
# Run on the **host** (needs docker). Verifies primary model + moonshot/minimax in every Gasclaw stack container.
# gasclaw-mgmt cannot see other containers' filesystems without a Docker socket.

set -euo pipefail

CONTAINERS=(
  gasclaw-minimax
  gasclaw-dev
  gasclaw-gasskill
  gasclaw-context
  gasclaw-mgmt
)

PRIMARY="moonshot/minimax-m2.5"
fail=0

for c in "${CONTAINERS[@]}"; do
  echo "=== $c ==="
  if ! docker exec "$c" true 2>/dev/null; then
    echo "SKIP (container not running)"
    fail=1
    continue
  fi
  if ! docker exec -i "$c" python3 - "$PRIMARY" <<'PY'
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
PY
  then
    fail=1
  fi
done

exit "$fail"

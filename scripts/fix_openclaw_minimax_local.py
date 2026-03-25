#!/usr/bin/env python3
"""Rewrite OpenClaw configs on THIS machine to MiniMax via LiteLLM only.

Removes kimi-coding/k2p5 providers and sets primary moonshot/minimax-m2.5.
Run inside a container:  python3 /path/to/fix_openclaw_minimax_local.py

Preserves moonshot.baseUrl from each existing models.json (LAN LiteLLM vs CloudFront).
"""

from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

PRIMARY = "moonshot/minimax-m2.5"
DEFAULT_BASE = "https://api.minimax.villamarket.ai/v1"


def _standard_providers(moonshot_base_url: str) -> dict:
    return {
        "moonshot": {
            "baseUrl": moonshot_base_url,
            "api": "openai-completions",
            "models": [
                {
                    "id": "minimax-m2.5",
                    "name": "MiniMax M2.5",
                    "reasoning": False,
                    "input": ["text", "image"],
                    "cost": {
                        "input": 0,
                        "output": 0,
                        "cacheRead": 0,
                        "cacheWrite": 0,
                    },
                    "contextWindow": 256000,
                    "maxTokens": 8192,
                }
            ],
            "apiKey": "MOONSHOT_API_KEY",
        }
    }


def patch_models_json(path: Path) -> None:
    raw = json.loads(path.read_text(encoding="utf-8"))
    prov = raw.get("providers") or {}
    moon = prov.get("moonshot") or {}
    base = moon.get("baseUrl") or DEFAULT_BASE

    new_providers = _standard_providers(base)
    if "github-copilot" in prov:
        new_providers["github-copilot"] = prov["github-copilot"]

    out = {"providers": new_providers}
    path.write_text(json.dumps(out, indent=2), encoding="utf-8")


def patch_openclaw_json(path: Path) -> None:
    cfg = json.loads(path.read_text(encoding="utf-8"))
    agents = cfg.setdefault("agents", {})
    defaults = agents.setdefault("defaults", {})
    model = defaults.setdefault("model", {})
    model["primary"] = PRIMARY

    models = defaults.setdefault("models", {})
    drop = [k for k in list(models.keys()) if "kimi" in k.lower() or k == "moonshot/kimi-k2.5"]
    for k in drop:
        del models[k]
    models[PRIMARY] = {}

    path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")


def main() -> int:
    home = Path.home()
    oc = home / ".openclaw"
    oj = oc / "openclaw.json"
    if not oj.is_file():
        print("error: missing ~/.openclaw/openclaw.json", file=sys.stderr)
        return 1

    patch_openclaw_json(oj)
    for path in glob.glob(str(oc / "agents/*/agent/models.json")):
        patch_models_json(Path(path))
        print("patched", path)
    print("patched", oj)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

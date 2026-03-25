#!/usr/bin/env python3
"""Rewrite OpenClaw configs on THIS machine to MiniMax via LiteLLM only.

Removes kimi-coding/k2p5 providers and sets primary moonshot/kimi-k2.5 via LiteLLM.
Run inside a container:  python3 /path/to/fix_openclaw_minimax_local.py

Preserves moonshot.baseUrl from each existing models.json (LAN LiteLLM vs CloudFront).
"""

from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

PRIMARY = "moonshot/kimi-k2.5"
DEFAULT_BASE = "https://api.minimax.villamarket.ai/v1"
# Session store uses short ids (moonshot model id), not the full "moonshot/..." slug.
SESSION_MODEL_ID = "kimi-k2.5"


def _standard_providers(moonshot_base_url: str) -> dict:
    return {
        "moonshot": {
            "baseUrl": moonshot_base_url,
            "api": "openai-completions",
            "models": [
                {
                    "id": "kimi-k2.5",
                    "name": "Kimi K2.5",
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


def _scrub_model_like(obj: object) -> None:
    """Rewrite persisted session metadata that still points at Kimi."""
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if k in ("model", "modelId") and isinstance(v, str):
                low = v.lower()
                if "kimi" in low or "k2p5" in low or low in ("kimi-k2.5", "k2p5"):
                    obj[k] = SESSION_MODEL_ID
            else:
                _scrub_model_like(v)
    elif isinstance(obj, list):
        for item in obj:
            _scrub_model_like(item)


def patch_sessions_json(path: Path) -> bool:
    """Fix agents/*/sessions/sessions.json model fields (otherwise gateway keeps requesting Kimi)."""
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    before = json.dumps(raw)
    _scrub_model_like(raw)
    after = json.dumps(raw)
    if before != after:
        path.write_text(json.dumps(raw, indent=2), encoding="utf-8")
        return True
    return False


def patch_openclaw_json(path: Path) -> None:
    cfg = json.loads(path.read_text(encoding="utf-8"))
    agents = cfg.setdefault("agents", {})
    defaults = agents.setdefault("defaults", {})
    model = defaults.setdefault("model", {})
    model["primary"] = PRIMARY
    # Fallbacks often still point at moonshot/kimi-k2.5 — LiteLLM then errors with "Unknown model".
    fbs = model.get("fallbacks")
    if isinstance(fbs, list):
        fbs = [x for x in fbs if "kimi" not in str(x).lower() and "k2p5" not in str(x).lower()]
        if fbs:
            model["fallbacks"] = fbs
        else:
            model.pop("fallbacks", None)
    elif "fallbacks" in model:
        model.pop("fallbacks", None)

    models = defaults.setdefault("models", {})
    drop = [k for k in list(models.keys()) if k.lower() in ("kimi-coding/k2p5", "moonshot/kimi-coding")]
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
    for path in glob.glob(str(oc / "agents/*/sessions/sessions.json")):
        p = Path(path)
        if patch_sessions_json(p):
            print("scrubbed models in", p)
    print("patched", oj)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Pre-download the WebUI dashboard dist into a portable package.

Run with the packaged Python after dependencies are installed:

    python warmup_dashboard.py <package_root>

This seeds ``<root>/data/dist`` so the portable package starts fully
offline without downloading dashboard assets on first run.
"""

import asyncio
import os
import sys
from pathlib import Path


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd().resolve()
    if not (root / "main.py").is_file():
        print(f"[portable] ERROR: {root} does not look like an AstrBot package.", file=sys.stderr)
        return 1

    os.environ["ASTRBOT_ROOT"] = str(root)
    sys.path.insert(0, str(root))

    for sub in ("config", "plugins", "temp/system", "knowledge_base", "site-packages"):
        (root / "data" / sub).mkdir(parents=True, exist_ok=True)

    import runtime_bootstrap

    runtime_bootstrap.initialize_runtime_bootstrap()

    from astrbot.core.updater import AstrBotUpdater

    dist = asyncio.run(AstrBotUpdater().ensure_dashboard())
    dist_path = Path(dist) if dist else None
    if not dist_path or not (dist_path / "index.html").is_file():
        print("[portable] ERROR: dashboard dist was not prepared.", file=sys.stderr)
        return 1

    print(f"[portable] dashboard dist ready: {dist_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

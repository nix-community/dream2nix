import os
from pathlib import Path
from typing import Any

env: dict[str, str] = os.environ.copy()


def get_out_path() -> Path:
    out = env.get("out")
    out_path = Path("")
    if out:
        out_path = Path(out)
    return out_path


def get_env() -> dict[str, Any]:
    return os.environ.copy()

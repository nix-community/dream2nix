import os
from enum import Enum
from typing import Any, Optional, TypedDict
from pathlib import Path
from .logger import logger
from dataclasses import dataclass

env: dict[str, str] = os.environ.copy()


@dataclass
class Output:
    out: Path
    lib: Path
    deps: Path


def get_outputs() -> Output:
    outputs = {
        "out": Path(get_env().get("out")),
        "lib": Path(get_env().get("lib")),
        "deps": Path(get_env().get("deps")),
    }
    if None in outputs.values():
        logger.error(
            f"\
At least one out path uninitialized: {outputs}"
        )
        exit(1)
    return Output(outputs["out"], outputs["lib"], outputs["deps"])


def is_main_package() -> bool:
    """Returns True or False depending on the 'isMain' env variable."""
    return bool(get_env().get("isMain"))


def get_env() -> dict[str, Any]:
    """Returns a copy of alle the current env variables"""
    return env


@dataclass
class Info:
    name: str
    version: str


def get_self() -> Info:
    return Info(get_env().get("pname", "unknown"), get_env().get("version", "unknown"))


class InstallMethod(Enum):
    copy = "copy"
    symlink = "symlink"


def get_install_method() -> InstallMethod:
    """Returns the value of 'installMethod'"""
    install_method: Optional[str] = get_env().get("installMethod")
    try:
        return InstallMethod(install_method)
    except ValueError:
        logger.error(
            f"\
Unknown install method: '{install_method}'. Choose: \
{', '.join([ e.value for e in InstallMethod])}"
        )
        exit(1)

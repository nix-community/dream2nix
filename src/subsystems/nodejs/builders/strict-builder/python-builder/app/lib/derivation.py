"""
    some utility functions to reference the value of
    variables from the overlaying derivation (via env)
"""
import os
from enum import Enum
from typing import Optional
from pathlib import Path
from .logger import logger
from dataclasses import dataclass

env: dict[str, str] = os.environ.copy()


@dataclass
class Output:
    out: Path
    lib: Path


def get_outputs() -> Output:
    outputs = {
        "out": Path(get_env("out")),
        "lib": Path(get_env("lib")),
    }
    return Output(outputs["out"], outputs["lib"])


def is_main_package() -> bool:
    """Returns True or False depending on the 'isMain' env variable."""
    return bool(get_env("isMain"))


def get_env(key: str) -> str:
    """
    Returns the value of the required env variable
    Prints an error end exits execution if the env variable is not set
    """
    try:
        value = env[key]
    except KeyError:
        logger.error(f"env variable ${key} is not set")
        exit(1)
    return value


def get_package_json_path() -> Path:
    return Path(get_env("packageJSON"))


@dataclass
class Info:
    name: str
    version: str


def get_self() -> Info:
    """ """
    return Info(env.get("pname", "unknown"), env.get("version", "unknown"))


class InstallMethod(Enum):
    copy = "copy"
    symlink = "symlink"


def get_install_method() -> InstallMethod:
    """Returns the value of 'installMethod'"""
    install_method: Optional[str] = env.get("installMethod")
    try:
        return InstallMethod(install_method)
    except ValueError:
        logger.error(
            f"\
Unknown install method: '{install_method}'. Choose: \
{', '.join([ e.value for e in InstallMethod])}"
        )
        exit(1)

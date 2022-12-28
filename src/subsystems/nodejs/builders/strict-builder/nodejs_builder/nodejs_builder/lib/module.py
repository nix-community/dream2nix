import os
from enum import Enum
from typing import Any, Optional, TypedDict

from .logger import logger

env: dict[str, str] = os.environ.copy()


def is_main_package() -> bool:
    """Returns True or False depending on the 'isMain' env variable."""
    return bool(get_env().get("isMain"))


def get_env() -> dict[str, Any]:
    """Returns a copy of alle the current env variables"""
    return env


class SelfInfo(TypedDict):
    name: str
    version: str


def get_self() -> SelfInfo:
    return {
        "name": get_env().get("pname", "unknown"),
        "version": get_env().get("version", "unknown"),
    }


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

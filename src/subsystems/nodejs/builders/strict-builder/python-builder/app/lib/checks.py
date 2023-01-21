import platform as p
import sys
from typing import Any, Literal, Union

from .logger import logger
from .package import get_package_json

NodeArch = Literal[
    "x32",
    "x64",
    "arm",
    "arm64",
    "s390",
    "s390x",
    "mipsel",
    "ia32",
    "mips",
    "ppc",
    "ppc64",
]

# a map containing some 'uname' mappings into the node 'process.arch' values.
arch_map: dict[str, NodeArch] = {
    "i386": "x32",
    "i686": "x32",
    "x86_64": "x64",
    "aarch64_be": "arm64",
    "aarch64": "arm64",
    "armv8b": "arm64",
    "armv8l": "arm64",
    "mips64": "mips",
    "ppcle": "ppc64",
}


def check_platform() -> bool:
    """
    Checks if bot cpu and platform is supported.
    e.g. cpu: "arm", platform: "linux"
    """
    platform: str = sys.platform  # 'linux','darwin',...
    arch: str = p.machine()
    package_json = get_package_json()

    # try to translate the value into some known node cpu.
    # returns the unparsed string, as fallback as the arch_map is not complete.
    node_arch: Union[NodeArch, str] = arch_map.get(arch, arch)
    is_compatible = True
    if package_json and (
        not _is_os_supported(package_json, platform)
        or not _is_arch_supported(package_json, node_arch)
    ):
        logger.info(
            f"\
Package is not compatible with current platform '{platform}' or cpu '{node_arch}'"
        )
        is_compatible = False

    return is_compatible


def _is_arch_supported(package_json: dict[str, Any], arch: str) -> bool:
    """
    Checks whether the current cpu architecture is supported
    Reads the package.json, npm states:
    architecture can be declared cpu=["x64"] as supported
    Or be excluded with '!' -> cpu=["!arm"]
    """
    if "cpu" in package_json:
        supports = package_json["cpu"]
        if arch not in supports or f"!{arch}" in supports:
            return False

    # return true by default
    # because not every project defines 'cpu' in package.json
    return True


def _is_os_supported(package_json: dict[str, Any], platform: str) -> bool:
    """
    Checks whether the current system is supported
    Reads the package.json, npm states:
    Systems can be declared os=["linux"] as supported
    Or be excluded with '!' -> os=["!linux"]
    """
    if "os" in package_json:
        supports = package_json["os"]
        if platform not in supports or f"!{platform}" in supports:
            return False

    # return true by default
    # because not every project defines 'os' in package.json
    return True

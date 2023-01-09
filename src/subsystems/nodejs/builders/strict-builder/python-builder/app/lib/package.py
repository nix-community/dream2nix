import json
import os
from pathlib import Path
from typing import Any, Optional, TypedDict, Union

from .dependencies import Dependency, DepsTree
from .derivation import get_env

package_json_cache = {}


def get_package_json(path: Path = Path("")) -> Union[dict[str, Any], None]:
    if path not in package_json_cache:
        if not os.path.isfile(path / Path("package.json")):
            # there is no package.json in the folder
            return None
        with open(f"{path}/package.json", encoding="utf-8-sig") as f:
            package_json_cache[path] = json.load(f)

    return package_json_cache[path]


def has_scripts(
    package_json: dict[str, Any],
    lifecycle_scripts: tuple[str] = (
        "preinstall",
        "install",
        "postinstall",
    ),
):
    return package_json and (
        package_json.get("scripts", {}).keys() & set(lifecycle_scripts)
    )


def get_bins(dep: Dependency) -> dict[str, Path]:
    package_json = get_package_json(Path(dep.derivation))
    bins: dict[str, Path] = {}

    if package_json and "bin" in package_json and package_json["bin"]:
        binary = package_json["bin"]
        if isinstance(binary, str):
            name = package_json["name"].split("/")[-1]
            bins[name] = Path(binary)
        else:
            for name, relpath in binary.items():
                bins[name] = Path(relpath)
    return bins


def create_binary(target: Path, source: Path):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not os.path.lexists(target):
        target.symlink_to(Path("..") / source)


def get_all_deps_tree() -> DepsTree:
    deps = {}
    dependenciesJsonPath = get_env().get("depsTreeJSONPath")
    if dependenciesJsonPath:
        with open(dependenciesJsonPath) as f:
            deps = json.load(f)
    return deps


class NodeModulesTree(TypedDict):
    version: str
    # mypy does not allow recursive types yet.
    # The real type is:
    # Optional[dict[str, NodeModulesPackage]]
    dependencies: Optional[dict[str, Any]]


NodeModulesPackage = dict[str, NodeModulesTree]


def get_node_modules_tree() -> dict[str, Any]:
    tree = {}
    dependenciesJsonPath = get_env().get("nmTreeJSONPath")
    if dependenciesJsonPath:
        with open(dependenciesJsonPath) as f:
            tree = json.load(f)
    return tree

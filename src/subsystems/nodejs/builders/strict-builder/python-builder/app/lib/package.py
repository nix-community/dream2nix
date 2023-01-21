import json
from pathlib import Path
from typing import Any, Optional, TypedDict

from .dependencies import Dependency, DepsTree
from .derivation import get_env, env

package_json_cache: dict[Path, dict[str, Any]] = {}


def get_package_json(
    path: Path = Path(env.get("packageJSON", ""))
) -> Optional[dict[str, Any]]:
    finalPath = path
    result: Optional[dict[str, Any]]

    if "package.json" not in path.name:
        finalPath = path / Path("package.json")

    if finalPath not in package_json_cache:
        if not finalPath.exists():
            # there is no package.json in the folder
            result = None
        else:
            with open(finalPath, encoding="utf-8-sig") as f:
                parsed: dict[str, Any] = json.load(f)

                result = parsed
                package_json_cache[path] = parsed

    else:
        result = package_json_cache[path]

    return result


def has_scripts(
    package_json: dict[str, Any],
    lifecycle_scripts: tuple[str, str, str] = (
        "preinstall",
        "install",
        "postinstall",
    ),
) -> bool:
    result = False
    if package_json:
        result = package_json.get("scripts", {}).keys() & set(lifecycle_scripts)
    return result


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
    if not target.exists():
        target.symlink_to(Path("..") / source)


def get_all_deps_tree() -> DepsTree:
    deps = {}
    dependenciesJsonPath = get_env("depsTreeJSONPath")
    if dependenciesJsonPath:
        with open(dependenciesJsonPath) as f:
            deps = json.load(f)
    return deps


class NodeModulesPackage(TypedDict):
    version: str
    # mypy does not allow recursive types yet.
    # The real type is:
    # Optional[dict[str, NodeModulesPackage]]
    dependencies: Optional[dict[str, Any]]


NodeModulesTree = dict[str, NodeModulesPackage]


def get_node_modules_tree() -> dict[str, Any]:
    tree = {}
    dependenciesJsonPath = get_env("nmTreeJSONPath")
    if dependenciesJsonPath:
        with open(dependenciesJsonPath) as f:
            tree = json.load(f)
    return tree

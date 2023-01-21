from dataclasses import dataclass
from typing import Any, Callable, Literal, Optional, TypedDict

from .logger import logger


@dataclass
class Dependency:
    name: str
    version: str
    derivation: str
    parent: Optional["Dependency"] = None
    dependencies: Optional[dict[str, Any]] = None

    def __str__(self: "Dependency") -> str:
        return f"{self.name}@{self.version}"


def get_all_deps(all_deps: dict[str, Any], name: str, version: str) -> list[str]:
    """
    Returns all dependencies of 'name@version' as flattened list.
    """

    def is_found(
        accumulator: Any, dep: Dependency, dep_tree: Optional[DepsTree]
    ) -> bool:
        return not bool(accumulator)

    def find_exact_dependency(
        accumulator: Any, dep: Dependency, dep_tree: Optional[DepsTree]
    ) -> Any:
        if accumulator:
            return accumulator

        if str(dep) == f"{name}@{version}":
            return dep_tree
        return None

    subtree = recurse_deps_tree(
        all_deps,
        find_exact_dependency,
        accumulator=None,
        pred=is_found,
        order="top-down",
    )

    def flatten(accumulator: Any, dep: Dependency, dep_tree: Optional[DepsTree]) -> Any:
        accumulator.append(str(dep))
        return accumulator

    flattened: list[str] = []
    if subtree:
        flattened = recurse_deps_tree(subtree, flatten, [])

    return flattened


class Meta(TypedDict):
    derivation: str
    deps: Optional[dict[str, dict[str, Any]]]


DepsTree = dict[str, dict[str, Meta]]


def recurse_deps_tree(
    deps: DepsTree,
    callback: Callable[[Any, Dependency, Optional[DepsTree]], Any],
    accumulator: Any,
    parent: Optional[Dependency] = None,
    order: Literal["bottom-up", "top-down"] = "bottom-up",
    pred: Optional[Callable[[Any, Dependency, Optional[DepsTree]], bool]] = None,
):
    """
    Generic function that traverses the dependency tree and calls
    'callback' on every node in the tree

    Parameters
    ----------
    deps : DepsTree
        The tree of dependencies, that will be iterated through.
    callback : Callable[[Any, Dependency, Optional[DepsTree]], Any]
        takes an accumulator (like 'fold' )
    accumulator : Any
        The initial value for the accumulator passed to 'callback'
    parent : Dependency
        The parent dependency, defaults to None, is set automatically during recursion
    order : Literal["bottom-up", "top-down"]
        The order in which the callback gets called: "bottom-up" or "top-down"
    pred : Callable[[Any, Dependency, Optional[DepsTree]], bool]
        Like 'callback' but returns a bool that will stop recursion if False

    Returns
    -------
    accumulator
        the last return value from 'callback: Callable'
    """

    dependencies: list[Dependency] = []

    for name, versions in deps.items():
        for version, meta in versions.items():
            nested_deps = meta["deps"]
            derivation = meta["derivation"]
            direct_dependency = Dependency(
                name=name,
                version=version,
                derivation=derivation,
                parent=parent,
                dependencies=nested_deps,
            )
            dependencies.append(direct_dependency)

    for dependency in dependencies:

        if order == "top-down":
            accumulator = callback(accumulator, dependency, dependency.dependencies)

        if dependency.dependencies:
            stop = False
            if pred is not None:
                stop = not pred(accumulator, dependency, dependency.dependencies)
            if not stop:
                accumulator = recurse_deps_tree(
                    dependency.dependencies,
                    callback,
                    accumulator=accumulator,
                    parent=dependency,
                    order=order,
                )
            else:
                logger.debug(
                    f"stopped recursing the dependency tree at {dependency}\
    -> because the predicate function returned 'False'"
                )
                return accumulator

        if order == "bottom-up":
            accumulator = callback(accumulator, dependency, dependency.dependencies)

    return accumulator

from dataclasses import dataclass
from typing import Any, Callable, Literal, Optional, TypedDict, Union

from .logger import logger


@dataclass
class Dependency:
    name: str
    version: str
    derivation: str
    parent: Union["Dependency", None] = None
    dependencies: Union[dict[str, Any], None] = None

    def repr(self: "Dependency") -> str:
        return f"{self.name}@{self.version}"


def get_all_deps(all_deps: dict[str, Any], name: str, version: str) -> list[str]:
    """
    Returns all dependencies. as flattened list
    """

    def is_found(acc: Any, dep: Dependency, dep_tree: Optional[DepsTree]) -> bool:
        return not bool(acc)

    def find_exact_dependency(
        acc: Any, dep: Dependency, dep_tree: Optional[DepsTree]
    ) -> Any:
        if acc:
            return acc

        if dep.repr() == f"{name}@{version}":
            return dep_tree
        return None

    subtree = recurse_deps_tree(
        all_deps, find_exact_dependency, acc=None, pred=is_found, order="top-down"
    )

    def flatten(acc: Any, dep: Dependency, dep_tree: Optional[DepsTree]) -> Any:
        acc.append(dep.repr())
        return acc

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
    cb: Callable[[Any, Dependency, Optional[DepsTree]], Any],
    acc: Any,
    parent: Union[Dependency, None] = None,
    order: Literal["bottom-up", "top-down"] = "bottom-up",
    pred: Optional[Callable[[Any, Dependency, Optional[DepsTree]], bool]] = None,
):
    """
    Generic function that traverses the dependency tree and calls
    'cb' on every node in the tree

    Parameters
    ----------
    deps : DepsTree
        The nested tree of dependencies, that will be iterated through.
    cb : Callable[[Any, Dependency, Optional[DepsTree]], Any]
        takes an accumulator (like 'fold' )
    acc : Any
        The initial value for the accumulator passed to 'cb'
    parent : Dependency
        The parent dependency, defaults to None, is set automatically during recursion
    order : Literal["bottom-up", "top-down"]
        The order in which the callback gets called: "bottom-up" or "top-down"
    pred : Callable[[Any, Dependency, Optional[DepsTree]], bool]
        Like 'cb' but returns a bool that will stop recursion if False

    Returns
    -------
    acc
        the last return value from 'cb: Callable'
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
            acc = cb(acc, dependency, dependency.dependencies)

        if dependency.dependencies:
            stop = False
            if pred is not None:
                stop = not pred(acc, dependency, dependency.dependencies)
            if not stop:
                acc = recurse_deps_tree(
                    dependency.dependencies,
                    cb,
                    acc=acc,
                    parent=dependency,
                    order=order,
                )
            else:
                logger.debug(
                    f"stopped recursing the dependency tree at {dependency.repr()}\
    -> because the predicate function returned 'False'"
                )
                return acc

        if order == "bottom-up":
            acc = cb(acc, dependency, dependency.dependencies)

    return acc

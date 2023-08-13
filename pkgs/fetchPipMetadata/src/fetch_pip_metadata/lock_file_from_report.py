from __future__ import annotations
from typing import Optional, Tuple
import subprocess
import json
from pathlib import Path

from pip._vendor.packaging.requirements import Requirement
from packaging.utils import (
    canonicalize_name,
)


def repo_root(directory):
    proc = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        stdout=subprocess.PIPE,
        cwd=directory,
    )
    # fall back to the current directory if not a git repo
    if proc.returncode == 128:
        return str(Path(".").absolute())
    return proc.stdout.strip()


def nix_show_derivation(path):
    proc = subprocess.run(
        ["nix", "show-derivation", path],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
    )
    if proc.returncode != 0:
        return None
    # attrs are keyed by derivation path, which we don't know,
    # but there should be only one in our case.
    return list(json.loads(proc.stdout).values())[0]


def lock_info_from_fod(store_path, drv_json):
    drv_out = drv_json.get("outputs", {}).get("out", {})
    assert str(store_path) == drv_out.get("path")
    assert "r:sha256" == drv_out.get("hashAlgo")
    url = drv_json.get("env", {}).get("urls")  # TODO multiple? commas?
    sha256 = drv_out.get("hash")
    if not (url and sha256):
        raise Exception(
            f"fatal: requirement '{store_path}' does not seem to be a FOD.\n"
            f"No URL ({url}) or hash ({sha256}) found."
        )
    return {"type": "url", "url": url, "sha256": sha256}


def lock_info_from_file_url(download_info):
    path = path_from_file_url(download_info["url"])

    if path is not None:
        return lock_info_from_path(path)


def path_from_file_url(url):
    prefix = "file://"
    prefix_len = len(prefix)
    if url.startswith(prefix):
        return Path(url[prefix_len:]).absolute()


def lock_info_from_path(full_path):
    # See whether the path is relative to our local repo
    repo = Path(repo_root("."))
    if repo in full_path.parents or repo == full_path:
        return {"type": "url", "url": str(full_path.relative_to(repo)), "sha256": None}

    # Otherwise, we assume its in /nix/store and just the "top-level"
    # store path /nix/store/$hash-name/
    store_path = Path("/").joinpath(*full_path.parts[:4])
    if not Path("/nix/store") == store_path.parent:
        raise Exception(
            f"fatal: requirement '{full_path}' refers to something outside "
            f"/nix/store and our local repo '{repo}'"
        )

    # Check if its a FOD, if so use nix to print the derivation of our
    # out_path in json and get hash and url from that
    drv_json = nix_show_derivation(store_path)
    if drv_json:
        return lock_info_from_fod(store_path, drv_json)
    else:
        proc = subprocess.run(
            ["nix", "hash", "path", store_path],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
        )
        if proc.returncode == 0:
            sha256 = proc.stdout
            return {
                "type": "url",
                "url": "",
                "sha256": sha256,
            }  # need to find a way to get the URL
        else:
            raise Exception(
                f"fatal: requirement '{full_path}' refers to something we "
                "can't understand"
            )


def lock_info_from_archive(download_info) -> Optional[Tuple[str, Optional[str]]]:
    try:
        archive_info = download_info["archive_info"]
    except KeyError:
        return None

    hash = archive_info.get("hash", "").split("=", 1)
    sha256 = hash[1] if hash[0] == "sha256" else None

    return {"type": "url", "url": download_info["url"], "sha256": sha256}


def lock_info_from_vcs(download_info) -> Optional[Tuple[str, Optional[str]]]:
    try:
        vcs_info = download_info["vcs_info"]
    except KeyError:
        return None

    match vcs_info["vcs"]:
        case "git":
            url = download_info["url"]
            rev = vcs_info["commit_id"]
            sha256 = json.loads(
                subprocess.run(
                    ["nix-prefetch-git", url, rev],
                    capture_output=True,
                    universal_newlines=True,
                    check=True,
                ).stdout
            )["sha256"]

            return {"type": "git", "url": url, "rev": rev, "sha256": sha256}


def lock_info_fallback(download_info):
    return {"type": "url", "url": download_info["url"], "sha256": None}


def lock_entry_from_report_entry(install):
    """
    Convert an entry of report['install'] to an object we want to store
    in our lock file, but don't add dependencies yet.
    """
    name = canonicalize_name(install["metadata"]["name"])
    download_info = install["download_info"]

    for lock_info in (
        lock_info_from_archive,
        lock_info_from_vcs,
        lock_info_from_file_url,
    ):
        info = lock_info(download_info)
        if info is not None:
            break
    else:
        info = lock_info_fallback(download_info)

    return name, dict(
        version=install["metadata"]["version"],
        **info,
    )


def evaluate_extras(req, extras, env):
    """
    Given a python requirement string, a dictionary representing a python
    platform environment as in report['environment'], and a set of extras,
    we want to check if this package is required on this platform with the
    requested extras.
    """
    if not extras:
        return req.marker.evaluate({**env, "extra": ""})
    else:
        return any({req.marker.evaluate({**env, "extra": e}) for e in extras})


def evaluate_requirements(env, reqs, dependencies, root_name, extras, seen):
    """
    Recursively walk the dependency tree and check if requirements
    are needed for our current platform with our requested set of extras.
    If so, add them to our lock files dependencies field and delete
    requirements to save space in the file.
    A circuit breaker is included to avoid infinite recursion in nix.
    """
    seen = seen.copy()
    seen.append(root_name)

    if root_name not in dependencies:
        dependencies[root_name] = set()

    for req in reqs[root_name]:
        if (not req.marker) or evaluate_extras(req, extras, env):
            req_name = canonicalize_name(req.name)
            if req_name not in seen:
                dependencies[root_name].add(req_name)
                evaluate_requirements(
                    env, reqs, dependencies, req_name, req.extras, seen
                )  # noqa: 501
    return dependencies


def lock_file_from_report(report):
    """
    Pre-process pips report.json for easier consumation by nix.
    We extract name, version, url and hash of the source distribution or
    wheel. We also preprocess requirements and their environment markers to
    the effective, platform-specific dependencies of each package. This makes
    heavy use of `packaging` which is hard to impossible to re-implement
    correctly in nix.

    We output a dictionary mapping normalized package names to a dict
    of version, url, sha256 and a list of normalized names of the packages
    effective dependencies on this platform and with the extras requested.

    This function can be further improved by also locking dependencies for
    non-selected extras, provided by our toplevel packages aka "roots".
    """
    packages = dict()
    # environment to evaluate pythons requirement markers in, contains
    # things such as your operating system, platform and python interpreter.
    env = report["environment"]
    # trace packages directly requested from pip to know where to start
    # walking the dependency tree.
    roots = dict()
    # packages in the report are a list, so we cache their requirement
    # strings in a list for faster lookups while we walk the tree below.
    requirements = dict()
    # targets to lock dependencies for, i.e. env markers like "dev" or "tests"
    targets = dict()

    # ensure at least one package is requested
    if not any(install.get("requested", False) for install in report["install"]):
        raise Exception("Cannot determine roots, nothing requested")

    # iterate over all packages pip installed to find roots
    # of the tree and gather basic information, such as urls
    for install in report["install"]:
        name, package = lock_entry_from_report_entry(install)
        packages[name] = package
        metadata = install["metadata"]
        requirements[name] = [Requirement(r) for r in metadata.get("requires_dist", [])]
        # (directly) "requested" packages are those at the root of our tree.
        if install.get("requested", False):
            # If no set of extras was explicitly requested, we default
            # to all extras provided by this package.
            provided_extras = set(metadata.get("provides_extra", []))
            roots[name] = install.get("requested_extras", set())

    # recursively iterate over the dependency tree from top to bottom
    # to evaluate optional requirements (extras) correctly
    for root_name, extras in roots.items():
        for extra in set(extras).union(set(["default"])):
            extras = [] if extra == "default" else [extra]
            dependencies = dict()
            evaluate_requirements(
                env, requirements, dependencies, root_name, extras, list()
            )
            if extra not in targets:
                targets[extra] = dependencies
            else:
                targets[extra].update(dependencies)

    # iterate over targets to deduplicate dependencies already in the default set
    # with the same indirect deps
    default_pkgs = targets["default"]
    default_names = set(default_pkgs.keys())
    for extra, pkgs in targets.items():
        if extra == "default":
            continue
        names = set(pkgs.keys())
        for name in default_names.intersection(names):
            if pkgs[name] == default_pkgs[name]:
                del pkgs[name]

    return {
        "sources": packages,
        "targets": {
            target: {pkg: sorted(list(deps)) for pkg, deps in pkgs.items()}
            for target, pkgs in targets.items()
        },
    }

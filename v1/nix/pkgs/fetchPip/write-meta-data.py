#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.pkginfo python3Packages.packaging
"""
Given a directory of python source distributions (.tar.gz) and wheels,
return a JSON representation of their dependency tree.

We want to put each python package into a separate derivation,
therefore nix needs to know which of those packages depend on
each other.

We only care about the graph between packages, as we start from
a complete set of python packages in the right version
- resolved & fetched by `pip download`, `mach-nix` or other tools.

That means that version specifiers as in (PEP 440; https://peps.python.org/pep-0508/)
and extras specified in markers (PEP 508; https://peps.python.org/pep-0508/)
 can be ignored for now.

We rely on `pkginfo` (https://pythonhosted.org/pkginfo/) to read `Requires-Dist`
et al as specified in https://packaging.python.org/en/latest/specifications/core-metadata/#id23
And we use `packaging` (https://packaging.pypa.io/en/stable/index.html) to parse
dependency declarations.

The output is a list of tuples. First element in each tuple is the package name,
second a list of dependencies. Output is sorted by the number of dependencies,
so that leafs of the dependency tree come first, the package to install last.
"""

import sys
import tarfile
import zipfile
import json
from pathlib import Path
from importlib.metadata import Distribution

from pkginfo import SDist, Wheel
from packaging.requirements import Requirement
from packaging.utils import (
    parse_sdist_filename,
    parse_wheel_filename,
    canonicalize_name,
)


def _is_tar(pkg_file):
    return pkg_file.suffixes[-2:] == [".tar", ".gz"]


def _is_zip(pkg_file):
    return pkg_file.suffixes[-1] == ".zip"


def _is_source_dist(pkg_file):
    return _is_tar(pkg_file) or _is_zip(pkg_file)


def _get_name_version(pkg_file):
    if _is_source_dist(pkg_file):
        name, version, *_ = parse_sdist_filename(pkg_file.name)
    else:
        name, version, *_ = parse_wheel_filename(pkg_file.name)
    return canonicalize_name(name), version


def get_pkg_info(pkg_file):
    try:
        if pkg_file.suffix == ".whl":
            return Wheel(str(pkg_file))
        elif _is_source_dist(pkg_file):
            return SDist(str(pkg_file))
        else:
            raise NotImplementedError(f"Unknown file format: {pkg_file}")
    except ValueError:
        pass


def _is_required_dependency(requirement):
    # We set the extra field to an empty string to effectively ignore all optional
    # dependencies for now.
    return not requirement.marker or requirement.marker.evaluate({"extra": ""})


def read_source_dist_file(source_dist_file, filename):
    if _is_tar(source_dist_file):
        with tarfile.open(source_dist_file) as tar:
            try:
                with tar.extractfile(filename) as f:
                    return f.read().decode("utf-8")
            except KeyError as e:
                return
    elif _is_zip(source_dist_file):
        with zipfile.ZipFile(source_dist_file) as zip:
            try:
                with zip.open(filename) as f:
                    return f.read().decode("utf-8")
            except KeyError as e:
                return


def usage():
    print(f"{sys.argv[0]} <pkgs-directory>")
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        usage()
    pkgs_path = Path(sys.argv[1])
    if not (pkgs_path.exists and pkgs_path.is_dir()):
        usage()

    dependencies = {}
    for pkg_file in pkgs_path.iterdir():
        pkg_info = get_pkg_info(pkg_file)
        name, version = _get_name_version(pkg_file)

        if pkg_info:
            requirements = [Requirement(req) for req in pkg_info.requires_dist]
        else:
            requirements = []

        # For source distributions which do *not* include modern metadata,
        # we fallback to reading egg-info.
        if not requirements and _is_source_dist(pkg_file):
            if egg_requires := read_source_dist_file(
                pkg_file,
                f"{name}-{version}/{name.replace('-', '_')}.egg-info/requires.txt",
            ):
                requirements = [
                    Requirement(req)
                    for req in Distribution._deps_from_requires_text(egg_requires)
                ]

        # For source distributions which  include neither, we fallback to reading requirements.txt
        # This might be re-considered in the future but is currently needed to make things like
        # old ansible releases work.
        if not requirements and _is_source_dist(pkg_file):
            if requirements_txt := read_source_dist_file(
                pkg_file, f"{name}-{version}/requirements.txt"
            ):
                requirements = [
                    Requirement(req)
                    for req in requirements_txt.split("\n")
                    if req and not req.startswith("#")
                ]

        requirements = filter(_is_required_dependency, requirements)
        dependencies[name] = dict(
            version=str(version),
            file=str(pkg_file.relative_to(pkgs_path)),
            dependencies=sorted([canonicalize_name(req.name) for req in requirements]),
        )

    dependencies = dict(sorted(dependencies.items()))
    print(json.dumps(dependencies, indent=2))

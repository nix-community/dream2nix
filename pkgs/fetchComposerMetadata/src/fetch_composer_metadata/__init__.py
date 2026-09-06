#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


def nix_prefetch_git(url: str, rev: str) -> str:
    """Prefetch a git repository and return its sha256 hash."""
    try:
        result = subprocess.run(
            ["nix-prefetch-git", "--quiet", url, rev],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(result.stdout)
        return data["sha256"]
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to prefetch {url}@{rev}: {e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(
            f"Warning: Failed to parse nix-prefetch-git output for {url}@{rev}: {e}",
            file=sys.stderr,
        )
        return None


def nix_prefetch_url(url: str) -> str:
    """Prefetch an url and return its sha256 hash."""
    try:
        result = subprocess.run(
            ["nix-prefetch-url", "--quiet", url],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Warning: Failed to prefetch {url}@{rev}: {e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(
            f"Warning: Failed to parse nix-prefetch-url output for {url}@{rev}: {e}",
            file=sys.stderr,
        )
        return None


def extract_source_spec(pkg: dict) -> dict | None:
    """Extract source specification from a package, prefetching git hashes."""
    if "source" in pkg:
        source = pkg["source"]
        if source.get("type") == "path":
            return {
                "type": "path",
                "path": source.get("path", source.get("url", "")),
            }
        elif source.get("type") == "git":
            url = source["url"]
            rev = source.get("reference", "")
            result = {
                "type": "git",
                "url": url,
                "rev": rev,
                "submodules": False,
            }
            hash_value = nix_prefetch_git(url, rev)
            if hash_value:
                result["hash"] = hash_value
            return result

    elif "dist" in pkg:
        dist = pkg["dist"]
        if dist.get("type") == "path":
            return {
                "type": "path",
                "path": dist.get("url", ""),
            }
        elif dist.get("type") in ["zip", "tar", "xz", "gz"]:
            # FIXME: we should probably write the precise type in the
            # lockfile, but I think php-granular doesn’t handle "url"
            # type yet and it throws an error anyway (seems rare enough
            # though)
            sum = dist.get("shasum")
            if "url" in dist and dist["url"] != "" and (sum is None or sum == ""):
                sum = nix_prefetch_url(dist["url"])
            return {
                "type": "url",
                "url": dist.get("url", ""),
                "hash": sum,
            }


def process_composer_lock(
    composer_json: dict,
    composer_lock: dict,
    project_name: str,
    source_path: str,
    no_dev: bool = False,
) -> dict:
    """
    Process composer.json and composer.lock to generate dream2nix lock format.

    Returns a dict with:
    - sources: package sources with hashes
    - dependencies: dependency graph
    - metadata: additional package metadata
    """
    # Build the list of packages
    packages = []

    # Add the top-level package
    toplevel_pkg = {
        "name": project_name,
        "version": composer_json.get("version", "unknown"),
        "source": {
            "type": "path",
            "path": source_path,
        },
        "require": {
            **(composer_json.get("require", {})),
            **({} if no_dev else composer_json.get("require-dev", {})),
        },
    }
    packages.append(toplevel_pkg)

    # Add packages from composer.lock
    packages.extend(composer_lock.get("packages", []))
    if not no_dev:
        packages.extend(composer_lock.get("packages-dev", []))
    pkgver_by_name = {p.get("name"): p.get("version", "unknown") for p in packages}

    # Extract sources with hashes and build dependency graph
    sources: dict[str, dict[str, Any]] = {}
    dependencies: dict[str, dict[str, list]] = {}
    all_requires = {}
    for pkg in packages:
        name = pkg.get("name")
        version = pkg.get("version", "unknown")

        if name is None:
            continue

        source_spec = extract_source_spec(pkg)
        if source_spec:
            if name not in sources:
                sources[name] = {}
            sources[name][version] = source_spec

        require = {
            name: pkg.get("version") if version == "self.version" else version
            for name, version in pkg.get("require").items()
        }
        all_requires.update(require)

        if name not in dependencies:
            dependencies[name] = {}
        dependencies[name][version] = []
        # Filter out php, extensions, and composer-api requirements
        for dep_name, dep_version in require.items():
            if dep_name in ["php", "composer-plugin-api", "composer-runtime-api"]:
                continue
            if dep_name.startswith("ext-"):
                continue
            if dep_name in pkgver_by_name:
                dependencies[name][version].append(
                    {"name": dep_name, "version": pkgver_by_name[dep_name]}
                )

    # Extract PHP version requirement and extensions
    php_semver = composer_json.get("require", {}).get("php", "*")
    php_extensions = [
        name.removeprefix("ext-") for name in all_requires if name.startswith("ext-")
    ]

    # Build the result
    result = {
        "sources": sources,
        "dependencies": dependencies,
        "metadata": {
            "projectName": project_name,
            "projectVersion": toplevel_pkg["version"],
            "phpSemver": php_semver,
            "phpExtensions": list(set(php_extensions)),
            "noDev": no_dev,
        },
    }

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Fetch composer metadata and prefetch git hashes"
    )
    parser.add_argument(
        "--json-args-file",
        type=Path,
        help="Path to JSON file with arguments",
        required=True,
    )

    # parse the json args from the json-args-file
    args = parser.parse_args()
    with open(args.json_args_file, "r") as f:
        json_args = json.load(f)

    # Get composer.json path - can be absolute or relative
    composer_json_path_str = json_args.get("composerJsonPath", "composer.json")
    composer_json_path = Path(composer_json_path_str)

    # If it's a relative path, make it relative to cwd
    if not composer_json_path.is_absolute():
        composer_json_path = Path.cwd() / composer_json_path

    if not composer_json_path.exists():
        print(
            f"Error: composer.json not found at {composer_json_path}", file=sys.stderr
        )
        sys.exit(1)

    with open(composer_json_path) as f:
        composer_json = json.load(f)

    # Get composer.lock path - can be absolute, relative, or None
    composer_lock_path_str = json_args.get("composerLockPath")
    if composer_lock_path_str:
        composer_lock_path = Path(composer_lock_path_str)
        if not composer_lock_path.is_absolute():
            composer_lock_path = Path.cwd() / composer_lock_path
    else:
        # Default to same directory as composer.json
        composer_lock_path = composer_json_path.parent / "composer.lock"

    if composer_lock_path.exists():
        with open(composer_lock_path) as f:
            composer_lock = json.load(f)
    else:
        print(
            f"Warning: composer.lock not found at {composer_lock_path}", file=sys.stderr
        )
        composer_lock = {"packages": [], "packages-dev": []}

    # Use the directory containing composer.json as the source path
    source_path = str(composer_json_path.parent)

    # Get project name
    project_name = json_args.get("projectName") or composer_json.get("name", "unknown")
    no_dev = json_args.get("noDev", False)

    # Process and generate lock data
    result = process_composer_lock(
        composer_json=composer_json,
        composer_lock=composer_lock,
        project_name=project_name,
        source_path=source_path,
        no_dev=no_dev,
    )

    # Write output
    with open(os.getenv("out"), "w") as f:
        json.dump(result, f, indent=2)


if __name__ == "__main__":
    main()

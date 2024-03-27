#!/usr/bin/env python3

# Generate a lock file based on plan.json. Unfortunately plan.json doesn't
# inlude all required information - it's missing revision of cabal file which
# breaks the compilation later on due to invalid version constraints, so we
# are augmenting it with correct revision and link to the valid cabal file

from hashlib import sha256
from urllib.parse import urljoin
import json
import os
import requests
import subprocess
import sys

with open("./dist-newstyle/cache/plan.json") as f:
    plan = f.read()

plan = json.loads(plan)

pkgs = list(
    filter(
        (
            lambda pkg: pkg.get("pkg-src") is not None
            and pkg["pkg-src"]["type"] == "repo-tar"
        ),
        plan["install-plan"],
    )
)
pkg_len = len(pkgs)

lock = {}


def to_sri(h):
    return subprocess.run(
        ["nix", "hash", "to-sri", "--type", "sha256", h],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


for i, pkg in enumerate(pkgs):
    name = pkg["pkg-name"]
    id = pkg["id"]
    version = pkg["pkg-version"]

    print(f"[{i+1}/{pkg_len}] Resolving revision for {name}-{version}")

    revisions = requests.get(
        f"https://hackage.haskell.org/package/{name}-{version}/revisions/",
        headers={"Accept": "application/json"},
    ).json()

    url = pkg["pkg-src"]["repo"]["uri"]
    url = urljoin(url, "package/")
    url = urljoin(url, f"{name}/")
    url = urljoin(url, f"{name}-{version}.tar.gz")

    for rev in revisions:
        no = rev["number"]
        rev_url = (
            f"https://hackage.haskell.org/package/{name}-{version}/revision/{no}.cabal"
        )
        rev_cabal = requests.get(rev_url).text
        rev_hash = sha256(rev_cabal.encode("utf-8")).hexdigest()

        if rev_hash == pkg["pkg-cabal-sha256"]:
            # Cabal gives hash before unpack, so we need to prefetch the source
            src_hash = subprocess.run(
                ["nix-prefetch-url", "--unpack", "--type", "sha256", url],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            src_hash = to_sri(src_hash)

            lock[id] = {
                "name": name,
                "version": version,
                "cabal": {
                    "url": rev_url,
                    "hash": to_sri(rev_hash),
                },
                "src": {
                    "url": url,
                    "hash": src_hash,
                },
            }
            break
    else:
        print(f"Could not find revision for {name}-{version}")
        sys.exit(1)

with open(os.environ.get("out"), "w") as f:
    json.dump(lock, f, indent=2)

#!/usr/bin/env python3

# Generate a lock file based on plan.json. Unfortunately plan.json doesn't
# inlude all required information - it's missing revision of cabal file which
# breaks the compilation later on due to invalid version constraints, so we
# are augmenting it with correct revision and link to the valid cabal file

from hashlib import sha256
import json
import os
import requests
import subprocess
import sys

subprocess.run(["cabal", "freeze"])

with open('./dist-newstyle/cache/plan.json') as f:
    plan = f.read()

plan = json.loads(plan)

pkgs = list(filter((lambda pkg: pkg.get('pkg-src') is not None
                    and pkg['pkg-src']['type'] == 'repo-tar')
                   , plan['install-plan']))
pkg_len = len(pkgs)

for i,pkg in enumerate(pkgs):
    name = pkg["pkg-name"]
    id = pkg["id"]
    version = pkg["pkg-version"]

    print(f"[{i}/{pkg_len}] Resolving revision for {name}")

    revisions = requests.get(f'https://hackage.haskell.org/package/{name}/revisions/'
                             , headers={'Accept': 'application/json'}).json()
    for rev in revisions:
        no = rev['number']
        rev_url = f'https://hackage.haskell.org/package/{name}-{version}/revision/{no}.cabal'
        rev_cabal = requests.get(rev_url).text
        rev_hash = sha256(rev_cabal.encode('utf-8')).hexdigest()
        if rev_hash == pkg['pkg-cabal-sha256']:
            pkg['pkg-cabal-url'] = rev_url
            break
    else:
        print(f'Could not find revision for {name}-{version}')
        sys.exit(1)

with open(os.environ.get("out"), "w") as f:
    json.dump(plan, f, indent=2)

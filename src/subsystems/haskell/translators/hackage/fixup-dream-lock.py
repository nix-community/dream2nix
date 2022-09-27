import json
import os
import sys

lock = json.load(sys.stdin)
version = os.environ.get('version')
hash = os.environ.get('hash')

# set default package version correctly
name = lock['_generic']['defaultPackage']
lock['sources'][name][version] = dict(
  type="http",
  url=f"https://hackage.haskell.org/package/{name}-{version}/{name}-{version}.tar.gz",
  hash=f"sha256:{hash}",
)

print(json.dumps(lock, indent=2))

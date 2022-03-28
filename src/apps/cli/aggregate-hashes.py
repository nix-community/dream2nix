import json
import os
import re
import sys

from nix_ffi import nix

def strip_hashes_from_lock(lock):
  for name, versions in lock['sources'].items():
    for source in versions.values():
      if 'hash' in source:
        del source['hash']

def aggregate_hashes(lock, outputDreamLock, dream2nix_src):
    print("Building FOD of aggregates sources to retrieve output hash")
    # remove hashes from lock file and init sourcesAggregatedHash with empty string
    strip_hashes_from_lock(lock)
    lock['_generic']['sourcesAggregatedHash'] = ""
    with open(outputDreamLock, 'w') as f:
      json.dump(lock, f, indent=2)
    # compute FOD hash of aggregated sources
    proc = nix(
      "build", "--impure", "-L", "--show-trace", "--expr",
      f"(import {dream2nix_src} {{}}).fetchSources {{ dreamLock = {outputDreamLock}; }}"
    )
    print(proc.stderr.decode())
    # read the output hash from the failed build log
    match = re.search(r"FOD_HASH=(.*=)", proc.stderr.decode())
    if not match:
      print(proc.stderr.decode())
      print(proc.stdout.decode())
      print(
        "Error: Could not find FOD hash in FOD log",
        file=sys.stderr,
      )
    hash = match.groups()[0]
    print(f"Computed FOD hash: {hash}")
    # store the hash in the lock
    lock['_generic']['sourcesAggregatedHash'] = hash
    return lock

if __name__ == '__main__':
  dreamLockFile = sys.argv[1]
  with open(dreamLockFile) as f:
    lock = json.load(f)
  dream2nix_src = os.environ.get('dream2nixWithExternals')
  new_lock = aggregate_hashes(lock, dreamLockFile, dream2nix_src)
  with open(dreamLockFile, 'w') as f:
    json.dump(new_lock, f, indent=2)

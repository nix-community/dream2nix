import json
import os
import subprocess as sp
import sys

from jsonschema import validate

from nix_ffi import callNixFunction

dream2nix_src = os.environ.get("dream2nixSrc")

def find_repo_root():
  proc = sp.run(
    ['git', 'rev-parse', '--show-toplevel'],
    capture_output=True,
  )
  if proc.returncode:
    print(proc.stderr.decode(), file=sys.stderr)
    print(
      f"\nProbably not inside git repo {config['repoName']}\n"
      f"Please clone the repo first.",
      file=sys.stderr
    )
    exit(1)
  return proc.stdout.decode().strip()

with open(os.environ.get("dream2nixConfig")) as f:
  config = json.load(f)
  config["isRepo"] = False
  if config['repoName'] and config ['packagesDir']:
    config['packagesDir'] = f"{find_repo_root()}/{config['packagesDir']}"
    config["isRepo"] = True

def checkLockJSON(lock):
  lock_schema_raw=open(dream2nix_src+"/specifications/dream-lock-schema.json").read()
  lock_schema=json.loads(lock_schema_raw)
  try:
    validate(lock, schema=lock_schema)
  except:
    print(
      "Error in lock. Dumping for debugging at ./dream-lock.json.fail",
      file=sys.stderr,
    )
    with open("./dream-lock.json.fail", 'w') as f:
      json.dump(lock, f, indent=2)
    raise


def list_translators_for_source(sourcePath):
  translatorsList = callNixFunction(
    "translators.translatorsForInput",
    inputDirectories=[sourcePath],
    inputFiles=[],
  )
  return list(sorted(translatorsList, key=lambda t: t['compatible']))


def strip_hashes_from_lock(lock):
  for name, versions in lock['sources'].items():
    for source in versions.values():
      if 'hash' in source:
        del source['hash']

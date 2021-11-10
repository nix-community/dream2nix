import json
import os
import subprocess as sp
import sys
import tempfile

from jsonschema import validate

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
  config.["isRepo"] = False
  if config['repoName'] and config ['packagesDir']:
    config['packagesDir'] = f"{find_repo_root()}/{config['packagesDir']}"
    config.["isRepo"] = True

def checkLockJSON(lock):
  lock_schema_raw=open(dream2nix_src+"/specifications/dream-lock-schema.json").read()
  lock_schema=json.loads(lock_schema_raw)
  validate(lock, schema=lock_schema)


def callNixFunction(function_path, **kwargs):
  with tempfile.NamedTemporaryFile("w") as input_json_file:
    json.dump(dict(**kwargs), input_json_file, indent=2)
    input_json_file.seek(0) # flushes write cache
    env = os.environ.copy()
    env.update(dict(
      FUNC_ARGS=input_json_file.name
    ))
    proc = sp.run(
      [
        "nix", "eval", "--show-trace", "--impure", "--raw", "--expr",
        f'''
          let
            d2n = (import {dream2nix_src} {{}});
          in
            builtins.toJSON (
              (d2n.utils.makeCallableViaEnv d2n.{function_path}) {{}}
            )
        ''',
      ],
      capture_output=True,
      env=env
    )
  if proc.returncode:
    print(f"Failed calling nix function '{function_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  # parse result data
  return json.loads(proc.stdout)


def buildNixFunction(function_path, **kwargs):
  with tempfile.NamedTemporaryFile("w") as input_json_file:
    json.dump(dict(**kwargs), input_json_file, indent=2)
    input_json_file.seek(0) # flushes write cache
    env = os.environ.copy()
    env.update(dict(
      FUNC_ARGS=input_json_file.name
    ))
    proc = sp.run(
      [
        "nix", "build", "--show-trace", "--impure", "-o", "tmp-result", "--expr",
        f'''
          let
            d2n = (import {dream2nix_src} {{}});
          in
            (d2n.utils.makeCallableViaEnv d2n.{function_path}) {{}}
        ''',
      ],
      capture_output=True,
      env=env
    )
  if proc.returncode:
    print(f"Failed calling nix function '{function_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  # return store path of result
  result = os.path.realpath("tmp-result")
  os.remove("tmp-result")
  return result


def buildNixAttribute(attribute_path):
  proc = sp.run(
    [
      "nix", "build", "--show-trace", "--impure", "-o", "tmp-result", "--expr",
      f"(import {dream2nix_src} {{}}).{attribute_path}",
    ],
    capture_output=True,
  )
  if proc.returncode:
    print(f"Failed to build '{attribute_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  result = os.path.realpath("tmp-result")
  os.remove("tmp-result")
  return result


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

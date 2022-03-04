import json
import os
import subprocess as sp
import sys
import tempfile

dream2nix_src = os.environ.get("dream2nixSrc")

def nix(*args, **kwargs):
  return sp.run(["nix", "--option", "experimental-features", "nix-command flakes"] + list(args), capture_output=True, **kwargs)

def callNixFunction(function_path, **kwargs):
  with tempfile.NamedTemporaryFile("w") as input_json_file:
    json.dump(dict(**kwargs), input_json_file, indent=2)
    input_json_file.seek(0) # flushes write cache
    env = os.environ.copy()
    env.update(dict(
      FUNC_ARGS=input_json_file.name
    ))
    proc = nix(
      "eval", "--show-trace", "--impure", "--raw", "--expr",
      f'''
        let
          d2n = (import {dream2nix_src} {{}});
        in
          builtins.toJSON (
            (d2n.utils.callViaEnv d2n.{function_path})
          )
      ''',
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
    proc = nix(
      "build", "--show-trace", "--impure", "-o", "tmp-result", "--expr",
      f'''
        let
          d2n = (import {dream2nix_src} {{}});
        in
          (d2n.utils.callViaEnv d2n.{function_path})
      ''',
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
  proc = nix(
    "build", "--show-trace", "--impure", "-o", "tmp-result", "--expr",
    f"(import {dream2nix_src} {{}}).{attribute_path}",
  )
  if proc.returncode:
    print(f"Failed to build '{attribute_path}'", file=sys.stderr)
    print(proc.stderr.decode(), file=sys.stderr)
    exit(1)

  result = os.path.realpath("tmp-result")
  os.remove("tmp-result")
  return result

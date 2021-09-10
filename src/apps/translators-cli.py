import argparse
import json
import os
import re
import subprocess as sp
import sys
import tempfile


with open (os.environ.get("translatorsJsonFile")) as f:
  translators = json.load(f)


# TODO: detection translator automatically according to files
def auto_detect_translator(files, subsystem):
  return list(translators[subsystem].keys())[0]


def stripHashesFromLock(lock):
  for source in lock['sources'].values():
    del source['hash']


def parse_args():

  parser = argparse.ArgumentParser(
    prog="translate",
    description="translate projects to nix",
  )

  parser.add_argument(
    "-s", "--subsystem",
    help="which subsystem to use, (eg: python, nodejs, ...)",
    choices=translators.keys()
  )

  parser.add_argument(
    "-t", "--translator",
    help="which specific translator to use",
    default="auto"
  )

  parser.add_argument(
    "-o", "--output",
    help="output file/directory (generic lock)",
    default="./dream.lock"
  )

  parser.add_argument(
    "-c", "--combined",
    help="Store only one hash for all sources combined (smaller lock file -> larger FOD)",
    action="store_true"
  )

  parser.add_argument(
    "input",
    help="input files containing relevant metadata",
    nargs="+"
  )

  args = parser.parse_args()

  # TODO: detection subsystem automatically according to files
  if not hasattr(args, "subsystem"):
    print("Please specify subsystem (-s, --subsystem)", file=sys.stderr)
    parser.print_help()
    exit(1)

  return args


def main():

  args = parse_args()

  subsystem = args.subsystem
  files = args.input

  # determine translator
  if args.translator == "auto":
    translator = auto_detect_translator(files, subsystem)
  else:
    translator = args.translator

  # determine output directory
  if os.path.isdir(args.output):
    output = f"{args.output}/dream.lock"
  else:
    output = args.output

  # translator arguments
  translatorInput = dict(
    inputFiles=files,
    outputFile=output,
  )

  # dump translator arguments to json file and execute translator
  with tempfile.NamedTemporaryFile("w") as inputJson:
    json.dump(translatorInput, inputJson, indent=2)
    inputJson.seek(0) # flushes write cache
    sp.run(
      [f"{translators[subsystem][translator]}/bin/translate", inputJson.name] + sys.argv[1:]
    )

  # raise error if output wasn't produced
  if not os.path.isfile(output):
    raise Exception(f"Translator '{translator}' failed to create dream.lock")

  # read produced lock file
  with open(output) as f:
    lock = json.load(f)

  # calculate combined hash
  if args.combined:

    print("Start building combined sourced FOD to get output hash")

    # remove hashes from lock file and init sourcesCombinedHash with emtpy string
    stripHashesFromLock(lock)
    lock['generic']['sourcesCombinedHash'] = ""
    with open(output, 'w') as f:
      json.dump(lock, f, indent=2)

    # compute FOD hash of combined sources
    dream2nix_src = os.environ.get("dream2nixSrc")
    proc = sp.run(
      [
        "nix", "build", "--impure", "-L", "--expr",
        f"(import {dream2nix_src} {{}}).fetchSources {{ genericLock = {output}; }}"
      ],
      capture_output=True,
    )

    # read the output hash from the failed build log
    match = re.search(r"FOD_PATH=(.*=)", proc.stderr.decode())
    if not match:
      print(proc.stderr.decode())
      print(proc.stdout.decode())
      raise Exception("Could not find FOD hash in FOD log")
    hash = match.groups()[0]
    print(f"Computed FOD hash: {hash}")

    # store the hash in the lock
    lock['generic']['sourcesCombinedHash'] = hash
    with open(output, 'w') as f:
      json.dump(lock, f, indent=2)
    

  print(f"Created {output}")


if __name__ == "__main__":
  main()

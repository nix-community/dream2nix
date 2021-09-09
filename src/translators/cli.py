import argparse
import json
import os
import subprocess as sp
import sys
import tempfile


with open (os.environ.get("translatorsJsonFile")) as f:
  translators = json.load(f)


# TODO: detection translator automatically according to files
def auto_detect_translator(files, subsystem):
  return list(translators[subsystem].keys())[0]


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

  if not os.path.isfile(output):
    raise Exception(f"Translator '{translator}' failed to create dream.lock")

  print(f"Created {output}")


if __name__ == "__main__":
  main()

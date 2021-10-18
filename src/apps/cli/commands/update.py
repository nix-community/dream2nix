import json
import os
import subprocess as sp
import sys
import tempfile

from cleo import Command, option

from utils import buildNixFunction, callNixFunction


class UpdateCommand(Command):
  description = (
    "Update an existing dream2nix based package"
  )

  name = "update"

  options = [
    option("dream-lock", None, "dream.lock file or its parent directory", flag=False, value_required=True),
    option("updater", None, "name of the updater module to use", flag=False),
    option("new-version", None, "new package version", flag=False),
  ]

  def handle(self):
    if self.io.is_interactive():
      self.line(f"\n{self.description}\n")

    dreamLockFile = os.path.abspath(self.option("dream-lock"))
    if not dreamLockFile.endswith('dream.lock'):
      dreamLockFile = os.path.abspath(dreamLockFile + "/dream.lock")

    # parse dream lock
    with open(dreamLockFile) as f:
      lock = json.load(f)

    # find right updater
    updater = self.option('updater')
    if not updater:
      updater = callNixFunction("updaters.getUpdaterName", dreamLock=dreamLockFile)
      if updater is None:
        print(
          f"Could not find updater for this package. Specify manually via --updater",
          file=sys.stderr,
        )
        exit(1)

    # find new version
    version = self.option('version')
    if not version:
      update_script = buildNixFunction(
        "updaters.makeUpdateScript",
        dreamLock=dreamLockFile,
        updater=updater,
      )
      update_proc = sp.run([f"{update_script}/bin/run"], capture_output=True)
      version = update_proc.stdout.decode().strip()
    print(f"\nUpdating to version {version}")

    cli_py = os.path.abspath(f"{__file__}/../../cli.py")
    # delete the hash
    mainPackageSource = lock['sources'][lock['generic']['mainPackage']]
    updatedSourceSpec = callNixFunction(
      "fetchers.updateSource",
      source=mainPackageSource,
      newVersion=version,
    )
    lock['sources'][lock['generic']['mainPackage']] = updatedSourceSpec
    with tempfile.NamedTemporaryFile("w", suffix="dream.lock") as tmpDreamLock:
      json.dump(lock, tmpDreamLock, indent=2)
      tmpDreamLock.seek(0)  # flushes write cache
      sp.run(
        [
          sys.executable, f"{cli_py}", "package", "--force", "--source", tmpDreamLock.name,
          "--output", os.path.abspath(os.path.dirname(dreamLockFile))
        ]
        + lock['generic']['translatorParams'].split()
      )

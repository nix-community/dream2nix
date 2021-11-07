import json
import os
import subprocess as sp
import sys
import tempfile

from cleo import Command, argument, option

from utils import config, buildNixFunction, callNixFunction


class UpdateCommand(Command):
  description = (
    f"Update an existing package in {config['repoName']}"
  )

  name = "update"

  arguments = [
    argument(
      "name",
      "name of the package or path containing a dream-lock.json",
    ),
  ]

  options = [
    option("updater", None, "name of the updater module to use", flag=False),
    option("to-version", None, "target package version", flag=False),
  ]

  def handle(self):
    if self.io.is_interactive():
      self.line(f"\n{self.description}\n")

    if config['packagesDir'] and '/' not in self.argument("name"):
      dreamLockFile =\
        os.path.abspath(
          f"{config['packagesDir']}/{self.argument('name')}/dream-lock.json")
    else:
      dreamLockFile = os.path.abspath(self.argument("name"))
      if not dreamLockFile.endswith('dream-lock.json'):
        dreamLockFile = os.path.abspath(dreamLockFile + "/dream-lock.json")

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
    print(f"updater module is: {updater}")

    # find new version
    old_version = lock['_generic']['mainPackageVersion']
    version = self.option('to-version')
    if not version:
      update_script = buildNixFunction(
        "updaters.makeUpdateScript",
        dreamLock=dreamLockFile,
        updater=updater,
      )
      update_proc = sp.run([f"{update_script}/bin/run"], capture_output=True)
      version = update_proc.stdout.decode().strip()
    print(f"Updating from version {old_version} to {version}")

    cli_py = os.path.abspath(f"{__file__}/../../cli.py")
    # delete the hash
    mainPackageName = lock['_generic']['mainPackageName']
    mainPackageVersion = lock['_generic']['mainPackageVersion']
    mainPackageSource = lock['sources'][mainPackageName][mainPackageVersion]
    updatedSourceSpec = callNixFunction(
      "fetchers.updateSource",
      source=mainPackageSource,
      newVersion=version,
    )
    lock['sources'][mainPackageName][mainPackageVersion] = updatedSourceSpec
    with tempfile.NamedTemporaryFile("w", suffix="dream-lock.json") as tmpDreamLock:
      json.dump(lock, tmpDreamLock, indent=2)
      tmpDreamLock.seek(0)  # flushes write cache
      sp.run(
        [
          sys.executable, f"{cli_py}", "add", tmpDreamLock.name, "--force",
          "--target", os.path.abspath(os.path.dirname(dreamLockFile))
        ]
        + lock['_generic']['translatorParams'].split()
      )

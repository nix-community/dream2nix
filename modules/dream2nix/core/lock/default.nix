{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.lock;

  # LOAD
  file = config.paths.lockFileAbs;
  data = l.fromJSON (l.readFile file);
  fileExists = l.pathExists file;

  generatedRefreshScript =
    if cfg.fields == {}
    then removeLockFileScript
    else refresh';

  invalidationHashCurrent = l.hashString "sha256" (l.toJSON cfg.invalidationData);
  invalidationHashLocked = fileContent.invalidationHash or null;

  # script to remove the lock file if no fields are defined
  removeLockFileScript = config.deps.writePython3Bin "refresh" {} ''
    import os
    import subprocess
    from pathlib import Path

    repo_path = Path(subprocess.run(
        ['${config.paths.findRoot}'],  # noqa: E501
        check=True, text=True, capture_output=True
    ).stdout.strip())
    lock_path_rel = Path('${config.paths.package}/${config.paths.lockFile}')  # noqa: E501
    lock_path = repo_path / lock_path_rel.relative_to(lock_path_rel.anchor)

    if lock_path.exists():
        os.remove(lock_path)
  '';

  # script to re-compute all fields for the lock file and dump it to a file
  refresh' = config.deps.writePython3Bin "refresh" {} ''
    import tempfile
    import subprocess
    import json
    from pathlib import Path

    refresh_scripts = json.loads('${l.toJSON cfg.fields}')  # noqa: E501
    repo_path = Path(subprocess.run(
        ['${config.paths.findRoot}'],  # noqa: E501
        check=True, text=True, capture_output=True)
        .stdout.strip())
    lock_path_rel = Path('${config.paths.package}/${config.paths.lockFile}')  # noqa: E501
    lock_path = repo_path / lock_path_rel.relative_to(lock_path_rel.anchor)
    lock_path.parent.mkdir(parents=True, exist_ok=True)


    def run_refresh_script(script):
        with tempfile.NamedTemporaryFile() as out_file:
            subprocess.run(
                [script],
                check=True, shell=True, env={"out": out_file.name})
            # open the file again via its name (it might have been replaced)
            with open(out_file.name) as out:
                return json.load(out)


    def run_refresh_scripts(refresh_scripts):
        """
          recursively iterate over a nested dict and replace all values,
          executable scripts, with the content of their $out$out files.
        """
        for name, value in refresh_scripts.items():
            refresh_scripts[name] = run_refresh_script(value["script"])
        return refresh_scripts


    lock_data = run_refresh_scripts(refresh_scripts)
    # error out if invalidation hash is already present
    if "invalidationHash" in lock_data:
        raise Exception("invalidationHash already present in lock file")
    else:
        lock_data["invalidationHash"] = "${invalidationHashCurrent}"  # noqa: E501
    with open(lock_path, 'w') as out_file:
        json.dump(lock_data, out_file, indent=2)
    print(f"lock file written to {out_file.name}")
    print("Add this file to git if flakes is used.")
  '';

  computeFODHash = fod: let
    drvPath = l.unsafeDiscardStringContext fod.drvPath;
  in
    config.deps.writePython3 "update-FOD-hash-${config.name}" {} ''
      import codecs
      import json
      import os
      import re
      import subprocess
      import sys

      out_path = os.getenv("out")
      drv_path = "${drvPath}"  # noqa: E501
      nix_build = ["${config.deps.nix}/bin/nix", "build", "-L", drv_path]  # noqa: E501
      with subprocess.Popen(nix_build, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:  # noqa: E501
          for line in process.stdout:
              line = line.strip()
              print(line)
              search = r"error: hash mismatch in fixed-output derivation '.*${fod.name}.*':"  # noqa: E501
              if re.match(search, line):
                  print("line matched")
                  specified = next(process.stdout).strip().split(" ", 1)
                  got = next(process.stdout).strip().split(" ", 1)
                  assert specified[0].strip() == "specified:"
                  assert got[0].strip() == "got:"
                  checksum = got[1].strip()
                  print(f"Found hash: {checksum}")
                  with open(out_path, 'w') as f:
                      json.dump(checksum, f, indent=2)
                  exit(0)
          process.wait()
          if process.returncode:
              print("Could not determine hash", file=sys.stdout)
              exit(1)
      # At this point the derivation was built successfully and we can just read
      #   the hash from the drv file.
      show_derivation = ["${config.deps.nix}/bin/nix", "derivation show", drv_path]  # noqa: E501
      result = subprocess.run(show_derivation, stdout=subprocess.PIPE, text=True)
      drv = json.loads(result.stdout)
      checksum = drv[drv_path]["outputs"]["out"]["hash"]
      checksum =\
          codecs.encode(codecs.decode(checksum, 'hex'), 'base64').decode().strip()
      checksum = f"sha256-{checksum}"
      print(f"Found hash: {checksum}")
      with open(out_path, 'w') as f:
          json.dump(checksum, f, indent=2)
    '';

  updateHint = ''
    To create or update the lock file, run:

      bash -c $(nix-build ${config.lock.refresh.drvPath} --no-link)/bin/refresh

    Alternatively `nix run` the .lock attribute of your package.
  '';

  errorMissingFile = ''
    The lock file ${config.paths.package}/${config.paths.lockFile}
      for drv-parts module '${config.name}' is missing.

    ${updateHint}
  '';

  errorOutdated = ''
    The lock file ${config.paths.package}/${config.paths.lockFile}
      for drv-parts module '${config.name}' is outdated.

    ${updateHint}
  '';

  errorOutdatedField = field: ''
    The lock file ${config.paths.package}/${config.paths.lockFile}
      for drv-parts module '${config.name}' does not contain field `${field}`.

    ${updateHint}
  '';

  fileContent =
    if ! fileExists
    then throw errorMissingFile
    else data;

  loadField = field: val:
    if
      # load the default value (if specified) whenever the field is not found in
      #   the lock file or the lock file doesn't exist.
      (cfg.fields.${field}.default != null)
      && (! fileExists || ! fileContent ? ${field})
    then cfg.fields.${field}.default
    else if fileContent ? ${field}
    then fileContent.${field}
    else throw (errorOutdatedField field);

  loadedContent =
    if invalidationHashCurrent != invalidationHashLocked
    then throw errorOutdated
    else l.mapAttrs loadField cfg.fields;

  # makes a value more lazy to the module system, so it can be overridden
  # without the original value being evaluated.
  mkLazy =
    lib.mkOverride
    (lib.modules.defaultOverridePriority or lib.modules.defaultPriority);
in {
  imports = [
    ./interface.nix
    ../assertions.nix
    ../deps
  ];

  config = {
    lock.refresh = config.deps.writeScriptBin "refresh" ''
      #!/usr/bin/env bash
      set -Eeuo pipefail

      ### Executing auto generated refresh script

      currDir="$(realpath .)"
      ${generatedRefreshScript}/bin/refresh
      cd "$currDir"


      ### Executing custom scripts defined via lock.extraScrips

      ${lib.concatStringsSep "\n" (map toString cfg.extraScripts)}
    '';

    lock.content = mkLazy loadedContent;

    lock.lib = {inherit computeFODHash;};

    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit (nixpkgs) nix writeScriptBin;
        inherit (nixpkgs.writers) writePython3 writePython3Bin;
      };
  };
}

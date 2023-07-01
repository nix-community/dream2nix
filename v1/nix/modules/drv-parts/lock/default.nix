{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.lock;

  # LOAD
  file = cfg.repoRoot + cfg.lockFileRel;
  data = l.fromJSON (l.readFile file);
  fileExists = l.pathExists file;

  refresh = config.deps.writePython3Bin "refresh" {} ''
    import tempfile
    import subprocess
    import json
    from pathlib import Path

    refresh_scripts = json.loads('${l.toJSON cfg.fields}')  # noqa: E501
    repo_path = Path(subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'],
        check=True, text=True, capture_output=True)
        .stdout.strip())
    lock_path_rel = Path('${cfg.lockFileRel}')  # noqa: E501
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
      show_derivation = ["${config.deps.nix}/bin/nix", "show-derivation", drv_path]  # noqa: E501
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

  errorMissingFile = ''
    The lock file ${cfg.repoRoot}${cfg.lockFileRel}
      for drv-parts module '${config.name}' is missing.

    To update it using flakes:

      nix run -L .#${config.name}.config.lock.refresh

    To update it without flakes:

      bash -c $(nix-build ${config.lock.refresh.drvPath} --no-link)/bin/refresh
  '';

  errorOutdated = field: ''
    The lock file ${cfg.repoRoot}${cfg.lockFileRel}
      for drv-parts module '${config.name}' does not contain field `${field}`.

    To update it using flakes:

      nix run -L .#${config.name}.config.lock.refresh

    To update it without flakes:

      bash -c $(nix-build ${config.lock.refresh.drvPath} --no-link)/bin/refresh

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
    else throw (errorOutdated field);

  loadedContent = l.mapAttrs loadField cfg.fields;
in {
  imports = [
    ./interface.nix
  ];

  config = {
    lock.refresh = refresh;

    lock.content = loadedContent;

    lock.lib = {inherit computeFODHash;};

    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit (nixpkgs) nix;
        inherit (nixpkgs.writers) writePython3 writePython3Bin;
      };
  };
}

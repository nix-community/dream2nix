{
  lib,
  pkgs,
  getSource,
  getSourceSpec,
  subsystemAttrs,
  dreamLock,
  ...
}: let
  l = lib // builtins;

  allDependencies =
    l.flatten
    (
      l.mapAttrsToList
      (
        name: versions:
          l.map (version: {inherit name version;}) (l.attrNames versions)
      )
      dreamLock.dependencies
    );
in rec {
  # Generates a shell script that writes git vendor entries to .cargo/config.
  # `replaceWith` is the name of the vendored source(s) to use.
  writeGitVendorEntries = replaceWith: let
    makeEntry = source: ''
      [source."${source.url}${l.optionalString (source ? type) "?${source.type}=${source.value}"}"]
      replace-with = "${replaceWith}"
      git = "${source.url}"
      ${l.optionalString (source ? type) "${source.type} = \"${source.value}\""}
    '';
    entries = l.map makeEntry subsystemAttrs.gitSources;
  in ''
    mkdir -p $CARGO_HOME && touch $CARGO_HOME/config.toml
    cat >> $CARGO_HOME/config.toml <<EOF
    ${l.concatStringsSep "\n" entries}
    EOF
  '';

  # Vendors the dependencies passed as Cargo expects them
  vendorDependencies = deps: let
    makeSource = dep: let
      path = getSource dep.name dep.version;
      spec = getSourceSpec dep.name dep.version;
      stripUniqSuffix = version: l.removeSuffix ("$" + spec.type) version;
    in {
      inherit path spec dep;
      name = "${dep.name}-${stripUniqSuffix dep.version}";
    };
    sources = l.map makeSource deps;

    findCrateSource = source: let
      cargo = "${pkgs.cargo}/bin/cargo";
      jq = "${pkgs.jq}/bin/jq";
      sponge = "${pkgs.moreutils}/bin/sponge";

      writeConvertScript = from: to:
        pkgs.writers.writePython3
        "${from}-to-${to}.py"
        {libraries = [pkgs.python3Packages.toml];}
        ''
          import toml
          import json
          import sys
          t = ${from}.loads(sys.stdin.read())
          sys.stdout.write(${to}.dumps(t))
        '';
      tomlToJson = writeConvertScript "toml" "json";
      jsonToToml = writeConvertScript "json" "toml";

      pkg = source.dep;
    in ''
      # If the target package is in a workspace, or if it's the top-level
      # crate, we should find the crate path using `cargo metadata`.
      crateCargoTOML=$(${cargo} metadata --format-version 1 --no-deps --manifest-path $tree/Cargo.toml | \
        ${jq} -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path')
      # If the repository is not a workspace the package might be in a subdirectory.
      if [[ -z $crateCargoTOML ]]; then
        for manifest in $(find $tree -name "Cargo.toml"); do
          echo Looking at $manifest
          crateCargoTOML=$(${cargo} metadata --format-version 1 --no-deps --manifest-path "$manifest" | ${jq} -r '.packages[] | select(.name == "${pkg.name}") | .manifest_path' || :)
          if [[ ! -z $crateCargoTOML ]]; then
            break
          fi
        done
        if [[ -z $crateCargoTOML ]]; then
          >&2 echo "Cannot find path for crate '${pkg.name}-${pkg.version}' in the tree in: $tree"
          exit 1
        fi
      else
        # we need to patch dependencies with `workspace = true` (workspace inheritance)
        workspaceDependencies="$(cat "$tree/Cargo.toml" | ${tomlToJson} | ${jq} -cr '.workspace.dependencies')"
        if [[ "$workspaceDependencies" != "null" ]]; then
          tree="$(pwd)/${pkg.name}-${pkg.version}"
          cp -prd --no-preserve=mode,ownership "$(dirname $crateCargoTOML)" "$tree"
          crateCargoTOML="$tree/Cargo.toml"
          cat "$crateCargoTOML" \
          | ${tomlToJson} \
          | ${jq} -cr --argjson workspaceDependencies "$workspaceDependencies" \
            --from-file ${./patch-workspace-deps.jq} \
          | ${jsonToToml} \
          | ${sponge} "$crateCargoTOML"
        fi
      fi
      echo Found crate ${pkg.name} at $crateCargoTOML
      tree="$(dirname $crateCargoTOML)"
    '';
    makeScript = source: let
      isGit = source.spec.type == "git";
      isPath = source.spec.type == "path";
    in
      l.optionalString (!isPath) ''
        tree="${source.path}"
        ${l.optionalString isGit (findCrateSource source)}
        echo Vendoring crate ${source.name}
        if [ -d $out/${source.name} ]; then
          echo Crate is already vendored
          echo Crates with duplicate versions cannot be vendored as Cargo does not support this behaviour
          exit 1
        else
          cp -prd "$tree" $out/${source.name}
          chmod u+w $out/${source.name}
          ${l.optionalString isGit "printf '{\"files\":{},\"package\":null}' > $out/${source.name}/.cargo-checksum.json"}
        fi
      '';
  in
    pkgs.runCommandLocal "vendor" {} ''
      mkdir -p $out

      ${
        l.concatMapStringsSep "\n"
        makeScript
        sources
      }
    '';

  # All dependencies in the Cargo.lock file, vendored
  vendoredDependencies = vendorDependencies allDependencies;

  copyVendorDir = from: to: ''cp -rs --no-preserve=mode,ownership ${from} ${to}'';
}

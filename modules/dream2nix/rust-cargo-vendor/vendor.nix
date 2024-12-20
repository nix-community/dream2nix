{
  lib,
  getRoot,
  getSource,
  getSourceSpec,
  sourceRoot,
  subsystemAttrs,
  dreamLock,
  moreutils,
  writePython3,
  python3Packages,
  runCommandLocal,
  ...
} @ args: let
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
    echo "dream2nix: Writing git vendor entries to $CARGO_HOME/config.toml"
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
      normalizeVersion = version: l.removeSuffix ("$" + spec.type) version;
    in {
      inherit path spec dep;
      name = "${dep.name}-${normalizeVersion dep.version}";
    };
    sources = l.map makeSource deps;

    findCrateSource = source: let
      cargo = "${args.cargo}/bin/cargo";
      jq = "${args.jq}/bin/jq";
      sponge = "${moreutils}/bin/sponge";

      writeConvertScript = from: to:
        writePython3
        "${from}-to-${to}.py"
        {libraries = [python3Packages.toml];}
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
        # we need to patch manifest attributes with `workspace = true` (workspace inheritance)
        workspaceAttrs="$(cat "$tree/Cargo.toml" | ${tomlToJson} | ${jq} -cr '.workspace')"
        if [[ "$workspaceAttrs" != "null" ]]; then
          tree="$(pwd)/${pkg.name}-${pkg.version}"
          cp -prd --no-preserve=mode,ownership "$(dirname $crateCargoTOML)" "$tree"
          crateCargoTOML="$tree/Cargo.toml"
          cat "$crateCargoTOML" \
          | ${tomlToJson} \
          | ${jq} -cr --argjson workspaceAttrs "$workspaceAttrs" \
            --from-file ${./patch-workspace.jq} \
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
    runCommandLocal "vendor" {} ''
      mkdir -p $out

      ${
        l.concatMapStringsSep "\n"
        makeScript
        sources
      }
    '';

  # All dependencies in the Cargo.lock file, vendored
  vendoredDependencies = vendorDependencies allDependencies;

  copyVendorDir = from: to: ''
    echo "dream2nix: installing cargo vendor directory from ${from} to ${to}"
    cp -rs --no-preserve=mode,ownership ${from} ${to}
  '';

  # Gets the root source for a package
  getRootSource = pname: version: let
    root = getRoot pname version;
  in
    getSource root.pname root.version;

  # Generates a script that replaces relative path dependency paths with absolute
  # ones, if the path dependency isn't in the source dream2nix provides
  replaceRelativePathsWithAbsolute = replacements: let
    replace =
      l.concatStringsSep
      " \\\n"
      (
        l.mapAttrsToList
        (
          # TODO: this is not great, because it forces us to include the entire
          # sourceRoot here, which could possibly cause more rebuilds than necessary
          # when source is changed (although this mostly depends on how the project
          # repository is structured). doing this properly is pretty complex, but
          # it should still be done later.
          from: relPath: ''--replace "\"${from}\"" "\"${sourceRoot}/${relPath}\""''
        )
        replacements
      );
  in ''
    echo "dream2nix: replacing relative dependency paths with absolute paths in Cargo.toml"
    substituteInPlace ./Cargo.toml \
      ${replace}
  '';
}

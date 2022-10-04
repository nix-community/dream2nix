{
  dlib,
  lib,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = {
    # dream2nix utils
    apps,
    subsystems,
    utils,
    # nixpkgs dependencies
    coreutils,
    curl,
    gnutar,
    gzip,
    jq,
    moreutils,
    rustPlatform,
    ...
  }:
    utils.writePureShellScript
    [
      coreutils
      curl
      gnutar
      gzip
      jq
      moreutils
      rustPlatform.rust.cargo
    ]
    ''
      # according to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      cargoArgs=$(jq '.project.subsystemInfo.cargoArgs | select (.!=null)' -c -r $jsonInput)
      name=$(jq '.project.name' -c -r $jsonInput)
      version=$(jq '.project.version' -c -r $jsonInput)

      pushd $TMPDIR

      # download and unpack package source
      mkdir source
      curl -L https://crates.io/api/v1/crates/$name/$version/download > $TMPDIR/tarball
      cd source
      cat $TMPDIR/tarball | tar xz --strip-components 1
      cd -

      # generate arguments for cargo-toml translator
      echo "{
        \"source\": \"$TMPDIR/source\",
        \"outputFile\": \"$outputFile\",
        \"project\": {
          \"relPath\": \"\",
          \"subsystemInfo\": {
            \"cargoArgs\": \"$cargoArgs\"
          }
        }
      }" > $TMPDIR/newJsonInput

      popd

      # we don't need to run cargo-toml translator if Cargo.lock exists
      if [ -f "$TMPDIR/source/Cargo.lock" ]; then
        ${subsystems.rust.translators.cargo-lock.translateBin} $TMPDIR/newJsonInput
      else
        ${subsystems.rust.translators.cargo-toml.translateBin} $TMPDIR/newJsonInput
      fi

      # add main package source info to dream-lock.json
      echo "
        {
          \"type\": \"crates-io\",
          \"hash\": \"$(sha256sum $TMPDIR/tarball | cut -d " " -f 1)\"
        }
      " > $TMPDIR/sourceInfo.json

      ${apps.replaceRootSources}/bin/replaceRootSources \
        $outputFile $TMPDIR/sourceInfo.json
    '';

  # inherit options from cargo-lock translator
  extraArgs =
    dlib.translators.translators.rust.cargo-lock.extraArgs
    // {
      cargoArgs = {
        description = "Additional arguments for Cargo";
        type = "argument";
        default = "";
        examples = [
          "--verbose"
        ];
      };
    };
}

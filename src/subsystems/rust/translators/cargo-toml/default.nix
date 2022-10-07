{
  pkgs,
  utils,
  translators,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = let
    inherit
      (pkgs)
      coreutils
      jq
      rustPlatform
      ;
  in
    utils.writePureShellScript
    [
      coreutils
      jq
      rustPlatform.rust.cargo
    ]
    ''
      # according to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)
      cargoArgs=$(jq '.project.subsystemInfo.cargoArgs | select (.!=null)' -c -r $jsonInput)

      pushd $TMPDIR
      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath

      cargo generate-lockfile $cargoArgs
      cargoResult=$?

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput
      popd

      if [ $cargoResult -eq 0 ]; then
        ${translators.cargo-lock.translateBinFinal} $TMPDIR/newJsonInput
      else
        echo "cargo failed to generate the lockfile"
        exit 1
      fi
    '';

  # inherit options from cargo-lock translator
  extraArgs =
    translators.cargo-lock.extraArgs
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

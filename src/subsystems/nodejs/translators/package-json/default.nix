{
  utils,
  pkgs,
  translators,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin = let
    inherit
      (pkgs)
      bash
      coreutils
      git
      jq
      nodePackages
      openssh
      ;
  in
    utils.writePureShellScript
    [
      bash
      coreutils
      git
      jq
      nodePackages.npm
      openssh
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      source=$(jq '.source' -c -r $jsonInput)
      relPath=$(jq '.project.relPath' -c -r $jsonInput)
      npmArgs=$(jq '.project.subsystemInfo.npmArgs' -c -r $jsonInput)

      pushd $TMPDIR
      cp -r $source/* ./
      chmod -R +w ./
      newSource=$(pwd)

      cd ./$relPath
      rm -rf package-lock.json yarn.lock

      echo "translating in temp dir: $(pwd)"

      if [ "$(jq '.project.subsystemInfo.noDev' -c -r $jsonInput)" == "true" ]; then
        echo "excluding dev dependencies"
        jq '.devDependencies = {}' ./package.json > package.json.mod
        mv package.json.mod package.json
        npm install --package-lock-only --omit=dev $npmArgs
      else
        npm install --package-lock-only $npmArgs
      fi

      jq ".source = \"$newSource\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      popd
      ${translators.package-lock.translateBinFinal} $TMPDIR/newJsonInput
    '';

  # inherit options from package-lock translator
  extraArgs =
    translators.package-lock.extraArgs
    // {
      npmArgs = {
        description = "Additional arguments for npm";
        type = "argument";
        default = "";
        examples = [
          "--force"
        ];
      };
    };
}

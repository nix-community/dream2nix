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
    # nixpkgs dependenies
    bash,
    coreutils,
    git,
    jq,
    moreutils,
    nodePackages,
    openssh,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      git
      jq
      moreutils
      nodePackages.npm
      openssh
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      name=$(jq '.project.name' -c -r $jsonInput)
      version=$(jq '.project.version' -c -r $jsonInput)
      npmArgs=$(jq '.project.subsystemInfo.npmArgs' -c -r $jsonInput)

      if [ "$version" = "null" ]; then
        candidate="$name"
      else
        candidate="$name@$version"
      fi


      pushd $TMPDIR
      newSource=$(pwd)

      npm install $candidate --package-lock-only $npmArgs

      jq ".source = \"$newSource\" | .project.relPath = \"\"" -c -r $jsonInput > $TMPDIR/newJsonInput

      popd

      # call package-lock translator
      ${subsystems.nodejs.translators.package-lock.translateBin} $TMPDIR/newJsonInput

      # generate source info for main package
      url=$(npm view $candidate dist.tarball)
      hash=$(npm view $candidate dist.integrity)
      echo "
        {
          \"type\": \"http\",
          \"url\": \"$url\",
          \"hash\": \"$hash\"
        }
      " > $TMPDIR/sourceInfo.json

      # add main package source info to dream-lock.json
      ${apps.callNixWithD2N} eval --json "
        with dream2nix.utils.dreamLock;
        replaceRootSources {
          dreamLock = l.fromJSON (l.readFile \"$outputFile\");
          newSourceRoot = l.fromJSON (l.readFile \"$TMPDIR/sourceInfo.json\");
        }
      " \
        | sponge "$outputFile"
    '';

  # inherit options from package-lock translator
  extraArgs =
    dlib.translators.translators.nodejs.package-lock.extraArgs
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

{
  apps,
  utils,
  translators,
  pkgs,
  ...
}: {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and specialArgs
  translateBin =
    utils.writePureShellScript
    (with pkgs; [
      coreutils
      curl
      jq
      git
      moreutils
    ])
    ''
      # according to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))
      name=$(jq '.project.name' -c -r $jsonInput)
      version=$(jq '.project.version' -c -r $jsonInput)

      pushd $TMPDIR

      # download and unpack package source
      curl https://packagist.org/packages/$name.json | \
        jq -rcM ".package.versions.\"$version\".source" \
        > source_manifest
      SOURCE_URL=$(jq -rcM ".url" source_manifest)
      SOURCE_REV=$(jq -rcM ".reference" source_manifest)

      mkdir source
      pushd source
      git init
      git remote add origin $SOURCE_URL
      git fetch --depth 1 origin $SOURCE_REV
      git checkout FETCH_HEAD
      mv composer.json composer.json.orig
      jq ".version = \"$version\"" composer.json.orig > composer.json
      popd

      # generate arguments for package-lock translator
      echo "{
        \"source\": \"$TMPDIR/source\",
        \"outputFile\": \"$outputFile\",
        \"project\": {
          \"name\": \"$name\",
          \"relPath\": \"\"
        }
      }" > $TMPDIR/newJsonInput

      popd

      if [ -f $TMPDIR/source/composer.lock ]
      then
        echo 'Translating with composer-lock'
        ${translators.composer-lock.finalTranslateBin} $TMPDIR/newJsonInput
      else
        echo 'Translating with composer-json'
        ${translators.composer-json.finalTranslateBin} $TMPDIR/newJsonInput
      fi

      # add main package source info to dream-lock.json
      echo "
        {
          \"type\": \"git\",
          \"url\": \"$SOURCE_URL\",
          \"rev\": \"$SOURCE_REV\"
        }
      " > $TMPDIR/sourceInfo.json

      ${apps.replaceRootSources}/bin/replaceRootSources \
        $outputFile $TMPDIR/sourceInfo.json
    '';

  # inherit options from composer-json translator
  extraArgs = translators.composer-json.extraArgs;
}

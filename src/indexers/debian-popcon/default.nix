{
  pkgs,
  utils,
  ...
}: {
  indexBin =
    utils.writePureShellScript
    (with pkgs; [coreutils curl jq gnused gawk])
    ''
      cd $WORKDIR

      input=''${1:?"please provide an input as a JSON file"}

      outFile=$(jq '.outputFile' -c -r $input)
      maxPackages=$(jq '.maxPackages' -c -r $input)
      exclusions=$(jq '.modifications.exclusions' -c -r $input)
      additions=$(jq '.modifications.additions' -c -r $input)

      tmpFile="$TMPDIR/tmp.json"
      helpFile="$TMPDIR/help.json"

      url="https://popcon.debian.org/by_vote"
      curl -k "$url" > "$tmpFile"

      # remove top comment line
      sed -i '/^#/d' $tmpFile
      head -n$maxPackages $tmpFile > $helpFile
      mv $helpFile $tmpFile
      awk '{print $2}' $tmpFile > $helpFile

      # remove enclosing square brackets
      additions=''${additions:1}
      additions=''${additions::-1}

      # remove double quotes from each package name
      additions=$(echo $additions | sed 's/,/ /g')
      for pkg in $additions;do
        pkg="''${pkg%\"}"
        pkg="''${pkg#\"}"
        echo $pkg >> $helpFile
      done

      # remove enclosing square brackets
      exclusions=''${exclusions:1}
      exclusions=''${exclusions::-1}

      # remove double quotes from each package name
      exclusions=$(echo $exclusions | sed 's/,/ /g')
      for pkg in $exclusions;do
        pkg="''${pkg%\"}"
        pkg="''${pkg#\"}"
        sed -i -e "/$pkg/d" $helpFile
      done

      jq -R -s -c 'split("\n")' < $helpFile >$tmpFile
      sed -i -e 's/,""//g' $tmpFile
      sed -i -e 's/\["/\["debian:/g' $tmpFile
      sed -i -e 's/,"/,"debian:/g' $tmpFile
      mv "$tmpFile" "$(realpath $outFile)"
    '';
}

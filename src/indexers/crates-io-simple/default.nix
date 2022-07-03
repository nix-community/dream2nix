{...}: {
  indexBin = {
    utils,
    coreutils,
    curl,
    jq,
    ...
  }:
    utils.writePureShellScript
    [coreutils curl jq]
    ''
      cd $WORKDIR

      input=''${1:?"please provide an input as a JSON file"}

      outFile=$(jq '.outputFile' -c -r $input)
      tmpFile="$TMPDIR/tmp.json"
      echo "[]" > "$tmpFile"

      sortBy=$(jq '.sortBy' -c -r $input)
      maxPages=$(jq '.maxPages' -c -r $input)

      for currentPage in $(seq 1 $maxPages); do
        jqQuery="$(jq '.' -c -r "$tmpFile") + (.crates | map(\"crates-io:\" + .name + \"\/\" + .max_stable_version))"
        url="https://crates.io/api/v1/crates?page=$currentPage&per_page=100&sort=$sortBy"
        curl -k "$url" | jq "$jqQuery" -r > "$tmpFile"
      done

      mv "$tmpFile" "$(realpath $outFile)"
    '';
}

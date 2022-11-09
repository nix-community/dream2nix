{
  pkgs,
  utils,
  ...
}: {
  indexBin =
    utils.writePureShellScript
    (with pkgs; [coreutils curl jq python3])
    ''
      input=''${1:?"please provide an input as a JSON file"}

      outFile=$(jq '.outputFile' -c -r $input)
      tmpFile="$TMPDIR/tmp.json"
      echo "[]" > "$tmpFile"

      sortBy=$(jq '.sortBy' -c -r $input)
      export number=$(jq '.number' -c -r $input)

      # calculate number of pages to query
      # page size is always 100
      # result will be truncated to the given $number later
      numPages=$(($number/100 + ($number % 100 > 0)))

      for currentPage in $(seq 1 $numPages); do
        url="https://crates.io/api/v1/crates?page=$currentPage&per_page=100&sort=$sortBy"
        echo "fetching page $currentPage"
        curl -k "$url" | python3 ${./process-result.py} "$tmpFile"
      done

      mv "$tmpFile" "$(realpath $outFile)"
    '';
}

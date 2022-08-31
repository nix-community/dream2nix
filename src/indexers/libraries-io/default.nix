/*
Indexer which utilizes the libraries.io api.
Given a platform (like npm or crates-io), it returns a list of packages sorted
by the highest number of dependents
(the number of other packages which depend on that package).

This indexer requires an api key that must first be created on libraries.io.
Github login is supported, so this is very straight forward.

More options could be added.
libraries.io also supports other interesting popularity metrics:
  - dependent_repos_count
  - stars
  - forks
  - rank (source rank, see https://libraries.io/api#project-sourcerank)
*/
{...}: {
  indexBin = {
    utils,
    coreutils,
    curl,
    jq,
    lib,
    python3,
    ...
  }: let
    l = lib // builtins;
    platformMap = {
      npm = "npm";
      crates-io = "cargo";
      pypi = "pypi";
    };
  in
    utils.writePureShellScript
    [coreutils curl jq python3]
    ''
      input=''${1:?"please provide an input as a JSON file"}

      outFile=$(jq '.outputFile' -c -r $input)

      echo "loading api key"
      if [ -z ''${API_KEY+x} ]; then
        echo "Please define env variable API_KEY for libaries.io api key"
        exit 1
      fi
      apiKey="$API_KEY"

      export platform=$(jq '.platform' -c -r $input)
      export number=$(jq '.number' -c -r $input)

      # calculate number of pages to query
      # page size is always 100
      # result will be truncated to the given $number later
      numPages=$(($number/100 + ($number % 100 > 0)))

      # get platform
      platformQuery=$(jq ".\"$platform\"" -c -r ${l.toFile "platform-map.json" (l.toJSON platformMap)})

      echo "Starting to query $numPages pages..."

      echo "[]" > $outFile
      for page in $(seq 1 $numPages); do
        echo "requesting page $page"
        url="https://libraries.io/api/search?page=$page&sort=dependents_count&per_page=100&platforms=$platformQuery&api_key=$apiKey"
        curl -k "$url" | python3 ${./process-result.py} $outFile
      done
    '';
}

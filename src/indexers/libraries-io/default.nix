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
    [coreutils curl jq]
    ''
      cd $WORKDIR

      input=''${1:?"please provide an input as a JSON file"}

      outFile=$(jq '.outputFile' -c -r $input)

      apiKey=$(jq '.apiKey' -c -r $input)
      platform=$(jq '.platform' -c -r $input)
      number=$(jq '.number' -c -r $input)

      # calculate number of pages to query
      # page size is always 100
      # result will be truncated to the given $number
      numPages=$(($number/100 + ($number % 100 > 0)))

      # get platform
      platformQuery=$(jq ".\"$platform\"" -c -r ${l.toFile "platform-map.json" (l.toJSON platformMap)})
      jqQuery=".[] | [(\"$platform:\" + .name + \"/\" + (.versions | sort_by(.published_at))[-1].number)] | add"

      echo "Starting to query $numPages pages..."

      rm -f $outFile
      for page in $(seq 1 $numPages); do
        url="https://libraries.io/api/search?page=$page&sort=dependents_count&per_page=100&platforms=$platformQuery&api_key=$apiKey"
        curl -k "$url" | jq "$jqQuery" -r >> $outFile
      done

      # truncate entries to $number and convert back to json
      head -n $number $outFile | jq --raw-input --slurp 'split("\n") | .[0:-1]' > ''${outFile}.final
      mv ''${outFile}.final $outFile
    '';
}

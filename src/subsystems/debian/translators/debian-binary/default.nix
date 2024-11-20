{
  pkgs,
  utils,
  ...
}: {
  type = "impure";

  # A derivation which outputs a single executable at `$out`.
  # The executable will be called by dream2nix for translation
  # The input format is specified in /specifications/translator-call-example.json.
  # The first arg `$1` will be a json file containing the input parameters
  # like defined in /src/specifications/translator-call-example.json and the
  # additional arguments required according to extraArgs
  #
  # The program is expected to create a file at the location specified
  # by the input parameter `outFile`.
  # The output file must contain the dream lock data encoded as json.
  # See /src/specifications/dream-lock-example.json
  translateBin =
    utils.writePureShellScript
    (with pkgs; [
      bash
      coreutils
      jq
      nix
      (callPackage ./aptdream {})
      python3
    ])
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      export outputFile=$(realpath -m $(jq '.outputFile' -c -r $jsonInput))

      pkgsName=$(jq '.project.name' -c -r $jsonInput)

      cd $TMPDIR

      mkdir ./state
      touch ./status
      mkdir ./download

      mkdir -p ./etc/apt
      echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" >> ./etc/apt/sources.list

      export NAME=$pkgsName
      python3 ${./generate_dream_lock.py}
    '';

  # If the translator requires additional arguments, specify them here.
  # When users run the CLI, they will be asked to specify these arguments.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  extraArgs = {};
}

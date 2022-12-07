export dream2nix=$(realpath .)

# define names for new modules (pick names matching to your subsystem)
export subsystem="my-subsystem" # example: nodejs
export pureTranslator="my-pure-translator" # example: package-lock
export impureTranslator="my-impure-translator" # example: package-json
export builder="my-builder" # pick `default` as name if not sure

# define path to example flake
export myFlake="$dream2nix/examples/$subsystem"

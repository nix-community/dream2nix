# Translators
This document classifies different methods for translating requirement/lock files to the generic lock format and describes how the resulting packages can be integrated into nix builds inside and outside of nixpkgs.


## pure-nix (preferred)
Suitable if:
- the input contains information like URLs and hashes
- nix supports the hashing algorithm
- the input can be processed with the nix language directly

Usage outside of nixpkgs:
- The input + translator are enough, not requiring any pre-processing.

Usage inside nixpkgs:
- The input + translator are enough, not requiring any pre-processing.

## IFD/recursive (compatible with import from derivation or recursive nix)
Suitable if:
- the input contains information like URLs and hashes
- nix understands the hashing algorithm
- to process the input, a nix build is required, because for example:
  - the format cannot be parsed with the nix language (yaml etc.)
  - processing the input is too complex and therefore inefficient in nix language

Usage outside of nixpkgs:
- The input + translator are enough. The generic lock file is generated via IFD

Usage inside nixpkgs:
- generic lock file must be pre-generated using dream2nix cli

## impure (running outside of nix build)
Suitable if:
- the input is missing URLs or hashes
- the method used to process the input contains impurities, like for example:
  - queries to an online index with varying responses
  - packages must be downloaded to discover important meta data like dependencies.

Usage outside of nixpkgs:
- generic lock file must be pre-generated using dream2nix cli

Usage inside nixpkgs:
- generic lock file must be pre-generated using dream2nix cli

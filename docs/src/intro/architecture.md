# Architecture

The general architecture should consist of these components:  
`Input -> Translation -> Generic Lock -> Fetching -> Building`

```
┌───────┐
│ Input │◄── Arbitrary
└────┬──┘                 URLs + Metadata containing Build instructions
     │   ┌──────────┐     in standardized minimalistic form (json)
     └──►│Translator│        │
         └───────┬──┘        ▼
           ▲     │   ┌────────────┐
           │     └──►│Generic Lock│
           │         └─────────┬──┘
  - pure-nix                   │   ┌────────┐
  - IFD / recursive-nix        ├──►│Fetcher │◄── Same across all
  - impure (external)          │   └────────┘    languages/frameworks
                               │       ▼
                               │   ┌────────┐
                               └──►│Builder │◄── Reads extra metadata
                                   └────────┘    from generic lock
```

Input:
- can consist of:
  - requirement constraints
  - requirement files
  - lock-files
  - project's source tree

Translator:
  - read input and generate generic lock format containing:
    - URLs + hashes of sources
    - metadata for building
  - different strategies can be used:
    - `pure-nix`: translate input by using the nix language only
    - `IFD/recursive`: translate using a nix build
    - `external`: translate using an external tool which resolves against an online package index
  - for more information about translators and how nixpkgs compatibility is guaranteed, check [Translators](./translators.md)

Generic Lock (standardized format):
  - Produced by `Translator`. Contains URLs + hashes for sources and metadata relevant for building.
  - The contained format for sources and dependency relations is independent of the build system. Fetching works always the same.
  - The metadata also contains build system specific attributes as individual approaches are required here. A specific builder for the individual build system will later read this metadata and transform it into nix derivations.
  - It is not relevant which steps/strategies have been taken to create this lock. From this point on, there are no impurities. This format will contain everything necessary for a fully reproducible build.
  - This format can always be put into nixpkgs, not requiring any IFD (given the nix code for the builder exists within nixpkgs).
  - In case of a pure-nix translator, the generic lock data can be generated on the fly and passed directly to the builder, preventing unnecessary usage of IFD.

Fetcher:
  - Since a generic lock was produced in the previous step, the fetching layer can be the same across all build systems.

Builder:
  - Receives sources from fetcher and metadata produced by the translator.
  - The builder transforms the metadata into nix derivation(s).
  - Strictly separating the builder from previous phases allows:
    - switching between different build strategies or upgrading the builder without having to re-run the translator each time.
    - reducing code duplication if a project contains multiple packages built via dream2nix.


### Example (walk through the phases)
#### python project with poetry.lock
As an example we package a python project that uses poetry for dependency management.
Poetry uses `pyproject.toml` and `poetry.lock` to lock dependencies
- Input: pyproject.toml, poetry.lock (toml)
- Translator: written in pure nix, reading the toml input and generating the generic lock format
- Generic Lock (for explanatory purposes dumped to json and commented):
    ```json
    {
      // generic lock format version
      "version": 1,

      // format for sources is always the same (not specific to python)
      "sources": {
        "requests": {
          "type": "tarball",
          "url": "https://download.pypi.org/requests/2.28.0",
          "hash": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
        },
        "certifi": {
          "type": "github",
          "owner": "certifi",
          "repo": "python-certifi",
          "hash": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
        }
      },

      // generic metadata (not specific to python)
      "_generic": {

        // this indicates which builder must be used
        "subsystem": "python",

        // translator which generated this file
        // (not relevant for building)
        "producedBy": "translator-poetry-1",

        // dependency graph of the packages
        "dependencies": {
          "requests": [
            "certifi"
          ]
        }
      },

      // all fields inside 'subsystem' are specific to
      // the selected subsystem (python)
      "_subsystem": {

        // tell the python builder how the inputs must be handled
        "sourceFormats": {
          "requests": "sdist",  // triggers build instructions for sdist
          "certifi": "wheel"    // triggers build instructions for wheel
        }
      }
    }
    ```
- This lock data can now either:
  - be dumped to a .json file and committed to a repo
  - passed directly to the fetching/building layer
- the fetcher will only read the sources section and translate it to standard fetcher calls.
- the building layer will read the "subsystem" attribute and select the python builder for building.
- the python builder will read all information from "subsystem" and translate the data to a final derivation.

Notes on IFD, FOD and code generation:  
- No matter which type of translator is used, it is always possible to export the generic lock to a file, which can later be evaluated without using IFD or FOD, similar to current nix code generators, just with a standardized format.
- If the translator supports IFD or is written in pure nix, it is optional to the user to skip exporting the generic lock and instead evaluate everything on the fly.

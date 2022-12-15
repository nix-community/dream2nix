# dream2nix
Automate reproducible packaging for various language ecosystems

{{#include ./warning.md}}

{{#include ./funding.md}}

dream2nix focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility, by not enforcing [IFD (import from derivation)][glossary]
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk-free opt-in aggregated fetching (larger [FODs][glossary], less checksums)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for automated packaging solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UX for all 2nix solutions.


### Modularity:
The following phases which are generic to basically all existing 2nix solutions:
  - parsing project metadata
  - resolving/locking dependencies (not always required)
  - fetching sources
  - building/installing packages

... should be separated from each other with well defined interfaces.

This will allow for free composition of different approaches for these phases.
The user should be able to freely choose between:
  - input metadata formats (eg. lock file formats)
  - metadata fetching/translation strategies: IFD vs. in-tree
  - source fetching strategies: granular fetching vs fetching via single large FOD to minimize expression file size
  - installation strategies: build dependencies individually vs inside a single derivation.

### Customizability
Every Phase mentioned in the previous section should be customizable at a high degree via override functions. Practical examples:
  - Inject extra requirements/dependencies
  - fetch sources from alternative locations
  - replace or modify sources
  - customize the build/installation procedure

### Maintainability
Due to the modular architecture with strict interfaces, contributors can add support for new lock-file formats or new strategies for fetching, building, installing more easily.

### Compatibility
Depending on where the nix code is used, different approaches are desired or discouraged. While IFD might be desired for some out of tree projects to achieve simplified UX, it is strictly prohibited in nixpkgs due to nix/hydra limitations.
All solutions which follow the dream2nix specification will be compatible with both approaches without having to re-invent the tool.

### Code de-duplication
Common problems that apply to many 2nix solutions can be solved once by the framework. Examples:
  - handling cyclic dependencies
  - handling sources from various origins (http, git, local, ...)
  - generate nixpkgs/hydra friendly output (no IFD)
  - good user interface

### Code de-duplication in nixpkgs
Essential components like package update scripts or fetching and override logic are provided by the dream2nix framework and are stored only once in the source tree instead of several times.

### Risk free opt-in FOD fetching
Optionally, to save more storage space, individual hashes for source can be omitted and a single large FOD used instead.
Due to a unified minimalistic fetching layer the risk of FOD hash breakages should be very low.

### Common UI across many 2nix solutions
2nix solutions which follow the dream2nix framework will have a unified UI for workflows like project initialization or code generation. This will allow quicker onboarding of new users by providing familiar workflows across different build systems.

### Reduced effort to develop new 2nix solutions
Since the framework already solves common problems and provides an interface for integrating new build systems, developers will have an easier time creating their next 2nix solution.

### Further reading

- [Architectural Considerations](./intro/architecture.md)
- [Potential impact on nixpkgs](./intro/nixpkgs-improvements.md)

[glossary]: https://nixos.wiki/wiki/Glossary "glossary"

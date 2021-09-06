## [WIP] dream2nix - A generic framework for 2nix tools
dream2nix is an approach to create a generic framework for 2nix tools.
It focuses on the following aspects:
  - Modularity
  - Customizability
  - Maintainability
  - Compatibility (not enforcing features like IFD)
  - Code de-duplication across 2nix tools
  - Common UI across 2nix tools
  - Reduce effort to develop new 2nix solutions

### Motivation
2nix tools, or in other words, tools converting instructions of other build systems to nix build instructions, are an important part of the nix/nixos ecosystem. These tools make packaging workflows easier and often allow to manage complexity that would be hard/impossible to manage without the 2nix tools.

Yet the current landscape of 2nix tools has certain weaknesses. Existing 2nix tools are very monolithic. Authors of these tools are often motivated by some specific use case and therefore the individual approaches are strongly biased and not flexible. All existing tools have quite different user interfaces, use different strategies of parsing, resolving, fetching, building with significantly different options for customizability. As a user of these tools it often feels like there is some part of the tool that suits the needs well, but at the same time it has undesirable hard coded behaviour. Often one would like to use some aspect of one tool combined with some aspect of another tool. One tool, for example, might do a good job in reading a specific lock file format, but lacks customizability for building. Another tool might come with a good customization interface, but is unable to parse the lock file format. Some tools are restricted to use IFD or FOD, while others enforce code generation.

The idea of this project is therefore to create a standardized, generic, modular framework for 2nix solutions, aiming for better flexibility, maintainability and usability.

### Modularity:
Individual phases like:
  - parsing requirements
  - resolving/locking dependencies
  - fetching sources
  - building/installing packages

... should be separated from each other with well defined interfaces.  
This will allow a free compsition of different approaches for these phases.
Examples:
  - Often more than one requirements / lock-file format exists within an ecosystem. Switching between these formats, or adding support for a new one should be easy.
  - Different resolving/fetching strategies: Some users might prefer a more automated approach via IFD, while others are focusing on upstreaming stuff to nixpkgs, where generating intermediary code or lock-files might be the only option.
  - Fetching a list of sources in theory should be a standard process. Yet, in practice, many 2nix tools struggle fetching sources from git or including local source trees. A generic fetching layer can reduce effort for maintainers.

### Customizability
Every Phase mentioned in the previous section should be customizable at a high degree via override functions. Practical examples:
  - Inject extra requirements/dependencies
  - fetch sources from alternative locations
  - replace or modify sources
  - customize the build/installation procedure


### Maintainability
Due to the modular architecture with well defined interfaces, contributers can add support for new lock-file formats or new strategies for fetching, building, installing more easily.


### Compatibility
Depending on where the nix code is used, different approaches are desired or discouraged. While IFD might be desired for some out of tree projects to achieve simplified UX, it is strictly prohibited in nixpkgs due to nix/hydra limitations.
All solutions which follow the dream2nix specification will be compatible with both approaches without having to re-invent the tool.

### Code de-duplication
Common problems that apply to many 2nix solutions can be solved once:
  - handling cyclic dependencies
  - handling sources from various origins (http, git, local, ...)
  - generate nixpkgs/hydra friendly output (no IFD)
  - good user interface

### Common UI across 2nix tools
2nix solutions which follow the dream2nix framework will have a unified UI for workflows like project initialization or gode generation. This will allow quicker onboarding of new users by providing familiar workflows across different build systems.

### Reduced effort to develop new 2nix solutions
Since the framework already solves common problems and provides interfaces for integrating new build systems, developers will have an easier time creating their next 2nix solution.

### Architecture
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
                     └─────────┬──┘
 impure/pure                   │   ┌────────┐
 online/offline                ├──►│Fetcher │◄── Same across all
 IFD/external                  │   └────────┘    languages/frameworks
                               │       ▼
                               │   ┌────────┐
                               └──►│Builder │◄── Reads extra metadata
                                   └────────┘    from generic lock
```

Input:
  - requirement contsraints
  - requirement files
  - lock-files

Translator:
  - read input and generate generic lock format containing URLs + hashes for sources and metadata required for the build
  - different strategies can be used to generate the generic lock:
    - pure-nix: translate input by using the nix language only
    - IFD/recursive: translate using a nix build
    - external: translate using external tool to resolve against online package index
  - for more information about translators check [docs/translators.md](/docs/translators.md)

Generic Lock (standardized format):
  - Produced by `Translator`. Contains URLs + hashes for sources and metadata relevant for building.
  - The basic format is standardized and equivalent across all languages/frameworks, so that fetching works always the same.
  - The metadata allows different attributes for different languages/frameworks as those require individual approaches for building. A specific builder for every framework will later read this metadata and transform it into build instructions.
  - It is not relevant which steps/strategies have been taken to create this lock. From this point on, there are no impurities. This format will contain everything necessary for a fully reproducible build.
  - This format can always be put into nixpkgs, not requiring any IFD (given the nix code for the builder exists within nixpkgs).
  - In case of a pure-nix translator, dumping the generic lock to JSON can be omitted and instead the data be passed directly to the builder, preventing unnecessary IFD usage.

Fetcher:
  - Since a generic lock was produced in the previous step, the fetching layer can be the same across all languages and frameworks.

Builder:
  - Receives sources from fetcher and metadata produced by the translator.
  - The builder transforms the metadata into build instructions.
  - Strictly separating the builder from previous phases allows:
    - switching between different build strategies or upgrading the builder without having to re-run the translator each time.
    - reducing code duplication if a project contains multiple packages built via dream2nix.

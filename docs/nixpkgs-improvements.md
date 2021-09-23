## List of problems which currently exist in nixpkgs

### Generated Code Size/Duplication:
- large .nix files containing auto generated code for fetching sources (example: nodejs)
- many duplicated .nix files containing build logic

### Update Scripts Duplicaiton/Complexity:
- update scripts are largely duplicated
- update scripts are complex

### Fetching / Caching issues (large FODs):
- non-reproducible large FOD fetchers (example: rust)
- updating FODs is not risk free (forget to update hash)
- bad caching properties due to large FODs

### Update Workflows:
- package update workflows can be complicated
- package update workflows vary significantly depending on the language/fragmework

### Merge Conflicts for shared dependencies:
- Due to badly organized shared dependencies, merge conflicts are likely (example: global node-packages.nix)

### Customizability / Overriding:
- Capabilities vary depending on the underlying solution.
- UI is different depending on the underlying solution.

### Inefficient/Slow Innovation
- Design issues (FOD-impurity, Merge Conflicts, etc.) cannot be fixed easily and lead to long term suffering of maintainers.
- Innovation often happens on individual solutions and are not adapted ecosystem wide
- New nix features will not be easily adapted as this will require updating many individual solutions.

---


## How dream2nix intends to fix these issues

### Generated Code Size/Duplication:
- dream2nix minimizes the amount of generated nix code, as all the fetch/build logic resides in the framework and therefore is not duplicated across packages.

- If the upstream lock file format can be interpreted with pure nix, then generating any intermediary code can be ommited if the upstream lock file is stored instead.

- Once any kind of recursive nix (IFD, recursive-nix, RFC-92) is enabled in nixpkgs, dream2nix will utilize it and eliminate the requirement of generating nix code or storing upsteam lock files

### Update Scripts Duplicaiton/Complexity:
- storing `update.sh` scripts alongside packages will not be necessary anymore. dream2nix can generate update procedures on the fly by reading the package declaration.
- The UI for updating packages is the same across all languages/frameworks

### Fetching / Caching issues:
- dream2nix' upstream metadata translators and always produce a clear list of URLs to fetch
- large-FOD fetching is not necessary and never enforced
- large-FOD fetching can be used optionally (to reduce amount of hashes to be stored)
- even if large-FOD fetching is used, it won't have any of the known reproducibility issues, since dream2nix does never make use of upstream toolchain for fetching and potentially impure operations like dependency resolution are never done inside an FOD.
- updating hashes of FODs is done via dream2nix CLI, which ensures that the correct hashes are in place
- As the use of large-FOD fetching is not necessary and therefore minimized, dependencies are cached on an individual basis and shared between packages.


### Update Workflows:
the workflow for updating packages will be unified and largely independenct of the underlying language/framework.

### Merge Conflicts for shared dependencies:
- Having a central set of shared dependencies can make sense to reduce the code size of nixpkgs and load on the cache.
- To eliminate merge conflicts, the globabl package set can be maintained via a two stage process. Individual package maintainers can manage their dependencies independently. Once every staging cycle, common dependencies can be found via graph analysis and moved into a global package set.
- The total amount of dependency versions used can also be minimized by re-running the resolver on individual packages, prioritizing dependencies from the global set of common packages.

### Customizability / Overriding:
dream2nix provides good interfaces for customizability which are unified as much as possible independently from the underlying buildsystems.

### Inefficient/Slow Innovation
- Since dream2nix centrally handles many core elements of packaging like different strategies for fetching and building, it is much easier to fix problems at large scale and apply  new innovations to all underlysing buildsystems at once.
- Experimenting with and adding support for new nix features will be easier as the framework offers better abstractions than existing 2nix converters and allows adding/modifying strategies more easily.

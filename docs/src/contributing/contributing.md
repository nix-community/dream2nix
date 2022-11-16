# dream2nix contributors guide
This guide is for you if you plan to implement support for a new subsystem in dream2nix, like for example for a new programming language.

If the ecosystem you are interested in is already supported by dream2nix, but you want to add support for a new type of lock-file format, this guide is still an interesting read in order to better understand the parts a dream2nix subsystem consists of.

## Breakdown of a subsystem
A new subsystem in dream2nix is initialized by adding 3 files:

- one translator module
- one builder module
- one example flake.nix for testing the subsystem

It's also highly recommended to implement a discoverer module, so that projects of that subsystem can be detected automatically by dream2nix. This simplifies the UX. It won't be necessary anymore for the user to understand which ecosystem and which translator must be used in order to build packages from a certain source tree.

## Translator Notes

The task of a translator is to inspect a given source tree, parse some of the files, and extract information about a projects dependencies and how it must be built.

In general there are 3 different types of translators.
No matter which type, all translators always produce the same output structure which is called `dream-lock`.  
An example of this structure can be found [here](https://github.com/nix-community/dream2nix/blob/main/src/specifications/dream-lock-example.json).  
There is also a [jsonschema specification](https://github.com/nix-community/dream2nix/blob/main/src/specifications/dream-lock-schema.json) for it.

## Translator types
The different types of translators have the following properties:

1. pure translator

   - returns the dream-lock as a nix attribute set
   - translation logic is implemented in nix language only
   - parsing of files and data extraction is all done during eval time
   - does not invoke a build or read from any build output

2. pure translator utilizing IFD (import from derivation)

   - returns the dream-lock as a nix attribute set
   - a nix build is used in order to parse files and extract data
   - translation logic can be implemented in arbitrary language
   - the result is parsed back into nix from the build output
   - downside: performance impact on evaluation time

3. impure translator

   - returns the dream-lock by dumping a dream-lock.json file
   - translator can be any executable program running independent of nix
   - not constrained in any way (can do arbitrary network access etc.)
   - downside: requires the user to run a command whenever dependencies got updated

## Which translator type to start with?
When adding support for a new ecosystem/language, the following strategy usually works out:

If there exists tooling within that ecosystem that can create some kind of lock file (with URLs + checksums), implement a pure translator for that lock file format first.

After that, we might still need an impure translator for all the projects within that ecosystem that don't ship a lock-file. But given the fact that we already have one pure translator, all the impure translator needs to do is to run the tooling that creates the lock file and call out to the pure translator via `nix eval`.

If the ecosystem does not have any kind of lock file format, then only an impure translator is needed. In this case it needs to be more complex and implement some kind of routine for retrieving all URL's and hashes of the dependencies, by, for example, downloading them all and hashing them.

## Initializing the subsystm
To initialize a new subsystem, we will:

- declare a few shell variables
- initialize a translator and a builder from templates
- initialize an example flake.nix to test the implementation

### declare env variables
Navigate to your dream2nix checkout and execute:
```bash
{{#include ./00-declare-variables.sh}}
```

### initialize templates

```bash
{{#include ./01-initialize-templates.sh}}
```

### initialize example flake.nix

Initialize the flake from a template and edit it to reference the names of your subsystem correctly.
```bash
{{#include ./02-initialize-example-flake.sh}}
```
Now edit the flake and ensure that `my-subsystem`, `my-pure-translator`, are replaced with the names defined earlier.

### add new files to git
This is required, otherwise nix flakes won't see the new files.
```bash
{{#include ./03-add-files-to-git.sh}}
```

### test example flake
Always pass `--override-input dream2nix $dream2nix` in order to evaluate the example flake against your local checkout of dream2nix.

In the following bash snippet, arguments containing a '`#`' symbol are wrongfully highlighted as comment but are in fact required parameters.

Run all of the following commands now to ensure that all templates have been initialized correctly
```bash
{{#include ./04-test-example-flake.sh}}
```


## Iterate on the subsystem
By default the templates implement a subsystem for `niv`. It reads niv's `./nix/sources.json` and builds a package for it containing the niv inputs.

The output of this is not useful, but demonstrates how a dream2nix translator/builder works.

You can now start modifying the builder/translator to implement the logic required by your subsystem.

You can test your implementation by executing the `nix flake show`, `nix build`, `nix run` commands from the last step above.

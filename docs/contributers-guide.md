# dream2nix contributers guide

## Contribute Translator

In general there are 3 different types of translators

1. pure translator

   - translation logic is implemented in nix lang only
   - does not invoke build or read from any build output

2. IFD translator

   - part of the logic is integrated as a nix build
   - nix code is used to invoke a nix build and parse its results
   - same interface as pure translator

3. impure

   - translator can be any executable program running outside of a nix build
   - not constrained in any way (can do arbitrary network access etc.)

### Add a new translator

To add a new translator, execute the flakes app `contribute` which will generate a template for you. Then open the new `default.nix` file in an edtior

The nix file must declare the following attributes:

In case of a `pure` or `IFD` translator:

```nix
{
  # function which receives source files and returns an attribute set
  # which follows the dream lock format
  translate = ...;

  # function which receives source files and returns either true or false
  # indicating if the current translator is capable of translating these files
  compatiblePaths = ;

  # optionally specify additional arguments that the user can provide to the
  # translator to customize its behavior
  specialArgs = ...;
}
```

In case of an `impure` translator:

```nix
{
  # A derivation which outputs an executable at `/bin/translate`.
  # The executable will be called by dream2nix for translation
  #
  # The first arg `$1` will be a json file containing the input parameters
  # like defined in /specifications/translator-call-example.json and the
  # additional arguments required according to specialArgs
  #
  # The program is expected to create a file at the location specified
  # by the input parameter `outFile`.
  # The output file must contain the dream lock data encoded as json.
  translateBin = ...;

  # A function which receives source files and returns either true or false
  # indicating if the current translator is capable of translating these files
  compatiblePaths = ;

  # optionally specify additional arguments that the user can provide to the
  # translator to customize its behavior
  specialArgs = ...;
}
```

Ways of debugging your translator:

- run the dream2nix flake app and use the new translator
- temporarily expose internal functions of your translator, then use nix repl `nix repl ./.` and invoke a function via `translators.translators.{subsystem}.{type}.{translator-name}.some_function`

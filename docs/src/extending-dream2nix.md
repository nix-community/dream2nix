# Extending dream2nix with external translators, builders etc.

`dream2nix` uses the NixOS module system for it's internal components.
This means you can extend it using the module system.
This can be done while the framework is being `init`ialized.
To do this, you need to utilize the `config.modules` option of the dream2nix config.

## Declaring `modules`

`config.modules` is a configuration option that expects paths to module files.

```nix
dream2nix.lib.init {
  config.modules = [./nix/d2n/extras.nix];
}
```
this file can look like this:
```nix
{ config, ... }:
let
  inherit (config) pkgs lib dlib;
in
{
  translators.example-translator = {/* translator attrs */};
  # you can declare modules using functions here
  fetchers.ipfs = {/* fetcher attrs */};
}
```

See the [`d2n-extended` example](https://github.com/nix-community/dream2nix/tree/main/examples/_d2n-extended) for an example on how to extend existing subsystems.
See the [`d2n-extended-new-subsystem` example](https://github.com/nix-community/dream2nix/tree/main/examples/_d2n-extended-new-subsystem) for an example on how to implement a new subsystem.

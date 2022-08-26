## Define target platform(s)
We have the flake setup, now we need to define the supported systems,
this is necessary because nix can do multi platform and cross-platform
builds so we need to tell it what can be built and where.

There are 2 ways to do this, either with a `nix_systems` file,
or we can write the target platforms inline to our `flake.nix`.

### nix_systems
We can create a `nix_systems` file with the current system:

```command
> nix eval --impure --raw --expr 'builtins.currentSystem' > ./nix_systems
> git add ./nix_systems
```

The `nix_systems` file is simply a list of the supported systems, for example:
```
x86_64-linux
```

Remember to add the file `./nix_systems` to git, or it won't be picked up by nix.
If you want to support more platforms later, just add more lines to that file.

### inline
Alternatively, we can define the targets in the `flake.nix` like so:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      systems = ["x86_64-linux"];         # <- This line.
      config.projectRoot = ./.;
      source = ./.;
    };
}
```

This has the advantage of keeping all the configuration in a single file.

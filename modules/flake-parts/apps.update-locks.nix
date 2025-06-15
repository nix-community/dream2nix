# custom app to update the lock file of each exported package.
{
  self,
  lib,
  inputs,
  ...
}: {
  imports = [
    ./writers.nix
  ];
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    system,
    ...
  }: let
    l = lib // builtins;

    packages = lib.filterAttrs (name: _: lib.hasPrefix "example-" name) self'.checks;

    packagesWithLocks = l.filterAttrs (name: pkg: pkg.config.lock.fields != {}) packages;

    # Generate bash case statements for each package
    packageCases = l.concatStringsSep "\n" (l.mapAttrsToList
      (name: pkg: let
        scriptPath = "${pkg.config.lock.refresh}/bin/refresh";
        packagePath = "./examples/packages/languages/${l.removePrefix "example-" name}";
      in ''
        "${name}")
          echo "Updating lock file for: ${name}"
          pushd "${packagePath}" > /dev/null
          "${scriptPath}"
          popd > /dev/null
          ;;'')
      packagesWithLocks);

    update-locks =
      config.writers.writePureShellScript
      (with pkgs; [
        coreutils
        git
        nix
      ])
      ''
        set -euo pipefail

        # Function to check if package name contains any of the filter terms
        package_matches_filter() {
          local package_name="$1"
          shift
          local filters=("$@")

          # If no filters provided, match all packages
          if [ ''${#filters[@]} -eq 0 ]; then
            return 0
          fi

          # Check if package name contains any filter term
          for filter in "''${filters[@]}"; do
            if [[ "$package_name" == *"$filter"* ]]; then
              return 0
            fi
          done

          return 1
        }

        # Parse command line arguments as filters
        filters=("$@")

        echo "Updating lock files with filters: ''${filters[*]:-none}"

        # Process each package
        for package_name in ${l.concatStringsSep " " (l.attrNames packagesWithLocks)}; do
          if package_matches_filter "$package_name" "''${filters[@]}"; then
            case "$package_name" in
              ${packageCases}
              *)
                echo "Unknown package: $package_name"
                exit 1
                ;;
            esac
          else
            echo "Skipping $package_name (doesn't match filters)"
          fi
        done

        echo "Lock file updates completed"
      '';

    toApp = script: {
      type = "app";
      program = "${script}";
    };
  in {
    apps = l.mapAttrs (_: toApp) {
      inherit
        update-locks
        ;
    };
  };
}

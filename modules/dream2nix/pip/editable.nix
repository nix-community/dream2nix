{
  lib,
  findRoot,
  unzip,
  pyEnv,
  editables,
  drvs,
}: let
  # We add editables using a sitecustomize.py and site.addsitedir().
  # The latter only supports appending to pythons path, not prepending.
  # This means that the normal, non-editable instannce of a given package
  # would end up in pythons bath *before* our editable, effectively overriding
  # it. To avoid this, we build a python environment without those packages.
  envWithoutEditables = pyEnv.override (old: {
    extraLibs = builtins.filter (drv: !(lib.elem drv.pname (lib.attrNames editables))) old.extraLibs;
  });

  mkEditable = name: path: let
    drv = drvs.${name};
  in ''
    name="${lib.replaceStrings ["-"] ["_"] name}"
    source="${
      if path != null
      then path
      else drv.mkDerivation.src
    }"
    editable_dir="$editables_dir/$name"
    # Realize the non-editable variant of this package,
    # if it's not in /nix/store already. We need its
    # .dist-info directory and might need it's unpackaged
    # source below.
    if [ ! -e "${drv.public.out}" ]
    then
      nix build "${drv.public.drvPath}^out"
    fi

    if [[ "$source" == /nix/store/*.whl ]]
    then
      echo "Extracting editable source from $source to $editable_dir" >/dev/stderr
      unzip -q -d "$editable_dir" "$source" "$name/*"
    elif [[ "$source" == /nix/store/* ]]
    then
      echo "Copying editable source from $source to $editable_dir" >/dev/stderr
      cp --recursive --remove-destination "$source/." "$editable_dir/"
      chmod -R u+w "$editable_dir"
    else
      echo "Linking editable source from $source to $editable_dir"
      ln -sf "$source" "$editable_dir"
    fi

    if [ -e "$editable_dir/src" ]
    then
      echo "$editable_dir/src" > "$site_dir/$name.pth"
    else
      # TODO this approach is risky as it puts everything inside
      # upstreams repo on $PYTHONPATH. Maybe we should try to
      # get packages from toplevel.txt first and if found,
      # create a dir with only them linked?
      echo "$editable_dir" > "$site_dir/$name.pth"
    fi

    # Create a .dist-info directory based on the non-editable install
    dist_info_installed="$(find ${drv.public.out}/${envWithoutEditables.sitePackages} -name '*.dist-info' -print -quit)"
    dist_info_name="$(basename "$dist_info_installed")"
    dist_info_editable="$site_dir/$dist_info_name"
    cp --recursive --remove-destination "$dist_info_installed/." "$dist_info_editable/"
    chmod -R u+w "$dist_info_editable"

    # Required by PEP-660
    rm -f "$dist_info_editable/RECORD"
    cat > "$dist_info_editable/direct_url.json" <<EOF
    {
      "url": "file://$editable_dir",
      "dir_info": { "editable": true }
    }
    EOF
  '';
in {
  shellHook = ''
    # TODO wrap console_scripts.

    # Ensure the python env is realized.
    nix build "${envWithoutEditables.drvPath}^out"

    dream2nix_dir="''$(${findRoot})/.dream2nix"
    editables_dir="$dream2nix_dir/editables"
    site_dir="$dream2nix_dir/site"
    mkdir -p "$editables_dir" "$site_dir"

    ${lib.concatStrings (lib.mapAttrsToList mkEditable editables)}
    cat > "$site_dir/sitecustomize.py" <<EOF
    import site
    site.addsitedir("$site_dir")
    EOF

    export PYTHONPATH="$site_dir:${envWithoutEditables}/${envWithoutEditables.sitePackages}:$PYTHONPATH"
    export PATH="${envWithoutEditables}/bin:$PATH"
  '';
}

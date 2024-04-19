{
  lib,
  pyEnv,
  editables,
}: let
  # TODO refactor
  envWithoutEditables = pyEnv.override (old: {
    extraLibs = builtins.filter (drv: !(lib.elem drv.pname (lib.attrNames editables))) old.extraLibs;
  });

  mkEditable = name: {
    path,
    drv,
  }: ''
    source="${
      if path != null
      then path
      else ""
    }"
    editable_dir="$editables_dir/${name}"
    mkdir -p "$editable_dir"

    # Realize the non-editable variant of this package,
    # if it's not in /nix/store already. We need its
    # .dist-info directory and might need it's unpackaged
    # source below.
    if [ ! -e "${drv.public.out}" ]
    then
      nix build "${drv.public.drvPath}^out"
    fi

    if [ -z "$source" ]
    then
      source="${drv.mkDerivation.src}"
      echo "Copying editable source from $source to $editable_dir" >/dev/stderr
      cp --recursive --remove-destination "$source/." "$editable_dir/"
      chmod -R u+w "$editable_dir"
    else
      echo "Linking editable source from $source to $editable_dir"
      ln -sf $source "$editable_dir"
    fi

    if [ -e "$editable_dir/src" ]
    then
         echo "$editable_dir/src" > "$site_dir/${name}.pth"
    else
         echo "$editable_dir" > "$site_dir/${name}.pth"
    fi

    # Create a .dist-info directory based on the non-editable install
    dist_info_installed="$(find ${drv.public.out}/${envWithoutEditables.sitePackages} -name '*.dist-info' -print -quit)"
    dist_info_name="$(basename "$dist_info_installed")"
    dist_info_editable="$site_dir/$dist_info_name"
    cp --recursive --remove-destination "$dist_info_installed/." "$dist_info_editable/"
    chmod -R u+w "$dist_info_editable"

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
    # TODO pre-build envWithoutEditables
    nix build "${envWithoutEditables.drvPath}^out"

    # TODO PWD might not be ideal, but PRJ_ROOT or such can't be assumed
    editables_dir="''${PWD}/.dream2nix/editables"
    site_dir="''${PWD}/.dream2nix/site"
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

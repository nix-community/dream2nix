import configparser
import importlib
import json
import os
import shutil
import subprocess
import sys
from contextlib import redirect_stdout
from pathlib import Path
from tempfile import TemporaryDirectory
from textwrap import dedent

import tomli


class Colors:
    ENDC = "\033[0m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    PURPLE = "\033[95m"
    BOLD = "\033[1m"
    WARNING = "\033[93m"


def run(args):
    try:
        proc = subprocess.run(
            args,
            check=True,
            capture_output=True,
            encoding="utf8",
        )
        return proc.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error while calling {' '.join(args)}", file=sys.stderr)
        print(e.output, file=sys.stderr)
        sys.exit(1)


def make_editable(
    python_environment,
    bin_dir,
    site_dir,
    name,
    path,
):
    normalized_name = name.replace("-", "_")
    full_path = path if path.is_absolute() else root_dir / path
    if not full_path.exists():
        print(
            f"Error: The python dependency {name} of {root_name} is configured to be installed in editable mode, but the provided source location {full_path} does not exist.\n"
            f"Please provide a path to a local copy of the source code of {name}.",
            file=sys.stderr,
        )
        exit(1)
    # Check if source uses a "src"-layout or a flat-layout and
    # write the .pth file
    if (full_path / "src").exists():
        editable_dir = full_path / "src"
    else:
        # TODO this approach is risky as it puts everything inside
        # upstreams repo on $PYTHONPATH. Maybe we should try to
        # get packages from toplevel.txt first and if found,
        # create a dir with only them linked?
        editable_dir = full_path

    make_pth(site_dir, editable_dir, normalized_name)
    editable_dist_info = make_dist_info(site_dir, full_path)
    make_entrypoints(python_environment, bin_dir, editable_dist_info)
    return editable_dir


def make_pth(site_dir, editable_dir, normalized_name):
    with open((site_dir / normalized_name).with_suffix(".pth"), "w") as f:
        f.write(f"{editable_dir}\n")


# create a packages .dist-info by calling its build backend
def make_dist_info(site_dir, editable_dir):
    os.chdir(editable_dir)
    pyproject_file = editable_dir / "pyproject.toml"
    if pyproject_file.exists():
        with open(pyproject_file, "rb") as f:
            pyproject = tomli.load(f)
        build_system = (
            pyproject["build-system"] if "build-system" in pyproject else "setuptools"
        )
        build_backend = (
            build_system["build-backend"]
            if "build-backend" in build_system
            else "setuptools.build_meta.__legacy__"
        )
        build_system_import = (
            build_backend
            if build_backend != "setuptools.build_meta.__legacy__"
            else "setuptools.build_meta"
        )
    else:
        build_system_import = "setuptools.build_meta"
    backend = importlib.import_module(build_system_import)
    with redirect_stdout(open(os.devnull, "w")), TemporaryDirectory() as tmp_dir:
        if hasattr(backend, "prepare_metadata_for_build_editable"):
            # redirect stdout to stderr to avoid leaking the metadata to the user
            dist_info_name = backend.prepare_metadata_for_build_editable(tmp_dir)
        else:
            dist_info_name = backend.prepare_metadata_for_build_wheel(tmp_dir)
        # copy the dist-info to the site-packages
        shutil.copytree(Path(tmp_dir) / dist_info_name, site_dir / dist_info_name)
    dist_info_path = site_dir / dist_info_name
    for egg_info in site_dir.glob("*.egg-info"):
        shutil.rmtree(egg_info)
    write_direct_url_json(dist_info_path, editable_dir)
    return dist_info_path


def write_direct_url_json(dist_info_path, editable_dir):
    with open(dist_info_path / "direct_url.json", "w") as f:
        json.dump(
            {"url": f"file://{editable_dir}", "dir_info": {"editable": True}},
            f,
            indent=2,
        )


def make_entrypoints(python_environment, bin_dir, dist_info):
    entry_points_file = dist_info / "entry_points.txt"
    if not entry_points_file.exists():
        return
    entry_points = configparser.ConfigParser()
    entry_points.read(entry_points_file)
    if "console_scripts" not in entry_points:
        return
    for name, spec in entry_points["console_scripts"].items():
        # https://setuptools.pypa.io/en/latest/userguide/entry_point.html#entry-points-syntax
        package, obj_attrs = spec.split(":", 1) if ":" in spec else (spec, None)
        obj, attrs = (
            obj_attrs.split(".", 1)
            if obj_attrs and "." in obj_attrs
            else (obj_attrs, None)
        )
        script = (
            f"#!{python_environment}/bin/python\n"
            + dedent(
                f"""
                from {package} import {obj}
                {obj}{f".{attrs}" if attrs else ""}()
            """
                if obj
                else f"""
                import {package}
                {package}()
            """
            ).strip()
        )
        with open(bin_dir / name, "w") as f:
            f.write(script)
        os.chmod(bin_dir / name, 0o755)


def needs_update(args, dream2nix_python_dir):
    if not (dream2nix_python_dir / "editable-args.json").exists():
        return True
    with open(dream2nix_python_dir / "editable-args.json", "r") as f:
        old_args = json.load(f)
    return old_args != args


def export_environment_vars(python_environment, bin_dir, site_dir, site_packages):
    print(
        f"""
    export PYTHONPATH="{site_dir}:{python_environment / site_packages}:$PYTHONPATH"
    export PATH="{bin_dir}:${python_environment}/bin:$PATH"
        """
    )


def pretty_print_editables(editables, root_name):
    if os.environ.get("D2N_QUIET"):
        return
    C = Colors
    print(
        f"{C.WARNING}Some python dependencies of {C.GREEN}{C.BOLD}{root_name}{C.ENDC}{C.WARNING} are installed in editable mode",
        file=sys.stderr,
    )
    for name, path in editables.items():
        if name == root_name:
            continue
        print(
            f"  {C.BOLD}{C.CYAN}{name}{C.ENDC}{C.ENDC}\n"
            f"    installed at: {C.PURPLE}{path}{C.ENDC}\n",
            file=sys.stderr,
        )
    print(
        f"{C.WARNING}To disable editable mode for a package, remove the corresponding entry from the 'editables' field in the dream2nix configuration file.{C.ENDC}",
        file=sys.stderr,
    )


if __name__ == "__main__":
    with open(sys.argv[1], "r") as f:
        args = json.load(f)
    # print(json.dumps(args, indent=2), file=sys.stderr)
    unzip = args["unzip"]
    find_root = args["findRoot"]
    python_environment = Path(args["pyEnv"])
    root_name = args["rootName"]
    site_packages = args["sitePackages"]
    editables = {k: Path(v) for k, v in args["editables"].items()}

    # directories to use
    root_dir = Path(run([find_root]))
    dream2nix_python_dir = root_dir / ".dream2nix" / "python"
    bin_dir = dream2nix_python_dir / "bin"
    site_dir = dream2nix_python_dir / "site"

    # remove dream2nix python dir if args changed
    if needs_update(args, dream2nix_python_dir):
        if dream2nix_python_dir.exists():
            shutil.rmtree(dream2nix_python_dir)
    else:
        export_environment_vars(python_environment, bin_dir, site_dir, site_packages)
        pretty_print_editables(editables, root_dir)
        exit(0)

    bin_dir.mkdir(parents=True, exist_ok=True)
    site_dir.mkdir(parents=True, exist_ok=True)

    editable_dirs = []
    for name, path in editables.items():
        editable_dir = make_editable(
            python_environment,
            bin_dir,
            site_dir,
            name,
            path,
        )
        editable_dirs.append(str(editable_dir.absolute()))
    with open(site_dir / "sitecustomize.py", "w") as f:
        f.write(
            f"""import sys
import site

try:
  import _sitecustomize
except ImportError:
  pass

site.addsitedir("{site_dir}")

# addsitedir only supports appending to the path, not prepending.
# As we already include a non-editable instance of each package
# in our pyEnv, those would shadow the editables. So we move
# the editables to the front of sys.path.
for index, path in enumerate(sys.path):
  if path in {editable_dirs}:
    sys.path.insert(0, sys.path.pop(index))
        """
        )

    with open(dream2nix_python_dir / "editable-args.json", "w") as f:
        json.dump(args, f, indent=2)

    export_environment_vars(python_environment, bin_dir, site_dir, site_packages)
    pretty_print_editables(editables, root_dir)

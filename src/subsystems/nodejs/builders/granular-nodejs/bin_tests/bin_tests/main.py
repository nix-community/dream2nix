import os

# import sys
from .lib.module import get_out_path, get_env
from .lib.console import Colors
from pathlib import Path
import subprocess


def check():
    """
    Tests all binaries in the .bin folder if it exists
    at least one of the following args must succeed
    [--help, --version, index.js, index.ts]
    e.g. "tsc --help"
    while index.js and index.ts are empty files
    """

    bin_dir = get_out_path() / Path("lib/node_modules/.bin")
    sandbox = Path("/build/bin_tests")
    args = ["--help", "--version", "index.js", "index.ts", "-h", "-v"]
    excluded_bins = get_env().get("installCheckExcludes", "").split(" ")

    sandbox.mkdir(parents=True, exist_ok=True)

    old_cwd = os.getcwd()
    os.chdir(sandbox)

    failed: list[Path] = []
    if bin_dir.exists():
        print(
            f"{Colors.HEADER}Running binary tests {Colors.ENDC}\n",
            f"{Colors.HEADER}└──for all files in: {bin_dir}  {Colors.ENDC}",
        )
        for maybe_binary in bin_dir.iterdir():
            if is_broken_symlink(maybe_binary):
                print(
                    f"{Colors.FAIL}🔴 failed: {maybe_binary.name} \t broken symlink: {maybe_binary} -> {maybe_binary.resolve()} {Colors.ENDC}"
                )
                failed.append(maybe_binary)

            if is_binary(maybe_binary):
                binary = maybe_binary
                if binary.name in excluded_bins:
                    print(f"{Colors.GREY}ℹ️ skipping: {binary.name}{Colors.ENDC}")
                    continue

                # re-create empty files on every testcase
                # to avoid leaking state from previous exectuables
                open(sandbox / Path("index.js"), "w").close()
                open(sandbox / Path("index.ts"), "w").close()

                success = try_args(args, binary)
                if not success:
                    print(
                        f"{Colors.FAIL}🔴 failed: {binary.name} \t could not run executable {Colors.ENDC}"
                    )
                    failed.append(binary)
                else:
                    print(f"{Colors.OKGREEN}✅ passed: {binary.name} {Colors.ENDC}")

    os.chdir(old_cwd)

    if failed:
        exit(1)


def is_broken_symlink(f: Path) -> bool:
    return f.is_symlink() and not f.exists()


def is_binary(f: Path) -> bool:
    return f.is_file() and os.access(f, os.X_OK)


def try_args(args: list[str], binary: Path) -> bool:
    success = False
    out = []
    for arg in args:
        try:
            completed_process = subprocess.run(
                f"{binary} {arg}".split(" "),
                timeout=10,
                capture_output=True,
            )
            if completed_process.returncode == 0:
                success = True
                break
            else:
                out.append(completed_process.stdout.decode())
                out.append(completed_process.stderr.decode())

        except subprocess.SubprocessError as e:
            print(e)
    if not success:
        print("\n".join(out))
    return success

import pytest
import subprocess as sp
from pathlib import Path
from tempfile import TemporaryDirectory


@pytest.fixture(scope="module")
def git_repo_path():
    repo = TemporaryDirectory()
    sp.run(["git", "init"], cwd=repo.name)
    path = Path(repo.name).absolute()
    return path


@pytest.fixture(scope="module")
def fod_store_path():
    nixexpr = """
        derivation {
            name = "test";
            system = builtins.currentSystem;
            builder = "/bin/sh";
            args = ["-c" "echo test > $out"];
            urls = "https://example.com";
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = "3a3f9b030dcb0974ef85969c37f570349df9d74fb8abf34ed86fc5aae0bef42b";
        }
    """
    proc = sp.run(
        ["nix", "build", "--impure", "--print-out-paths", "--expr", nixexpr],
        capture_output=True,
    )
    print(proc.stderr)
    assert proc.returncode == 0
    return proc.stdout.decode().strip()

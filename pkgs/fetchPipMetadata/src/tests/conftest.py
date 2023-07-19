from os import environ
import pytest
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory


@pytest.fixture()
def git_repo_path(tmp_path):
    subprocess.run(["git", "init"], cwd=tmp_path)
    return tmp_path

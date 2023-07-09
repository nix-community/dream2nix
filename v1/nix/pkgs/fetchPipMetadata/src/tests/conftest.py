from os import environ
import pytest
import subprocess as sp
from pathlib import Path
from tempfile import TemporaryDirectory


@pytest.fixture()
def git_repo_path(tmp_path):
    sp.run(["git", "init"], cwd=tmp_path)
    return tmp_path

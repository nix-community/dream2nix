"""
Check invariants on our flake interface, i.e. that
nix flake show --json works as expected
"""
import os
import pytest


@pytest.mark.timeout(5)
def test_flake_output(nix_eval):
    assert nix_eval(":lf .") == "Added 23 variables."
    assert nix_eval("3+7") == "10"
    ansible = nix_eval("packages.x86_64-linux.ansible")
    assert ansible.startswith("«derivation /nix/store/")
    assert ansible.endswith("-python3.9-ansible-2.7.1.drv»")

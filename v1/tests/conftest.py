import re
import signal
import pytest
import pexpect
import pexpect.replwrap


def pytest_collection_modifyitems(session, config, items):
    for item in items:
        if not any(m.name in ["timeout", "slow"] for m in item.iter_markers()):
            item.add_marker(pytest.mark.timeout(3))


# https://stackoverflow.com/questions/14693701/how-can-i-remove-the-ansi-escape-sequences-from-a-string-in-python
ANSI_ESCAPE_RE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")


@pytest.fixture
def nix_eval():
    # TODO add only nix and git to PATH
    env = {"PATH": "/run/current-system/sw/bin/"}

    proc = pexpect.spawnu("nix repl", env=env)

    assert proc.expect("Welcome to Nix.*\r\n") == 0
    assert proc.before == ""

    repl = pexpect.replwrap.REPLWrapper(proc, "nix-repl> ", None)

    def _eval(command):
        output = repl.run_command(command).removeprefix(f"{command}\r\r\n").strip()
        return ANSI_ESCAPE_RE.sub("", output)

    yield _eval

    proc.kill(signal.SIGTERM)

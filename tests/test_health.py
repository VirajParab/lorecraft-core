"""Basic health tests."""

import pytest

from lorecraft_core import __version__


def test_version():
    assert __version__ == "0.1.0"

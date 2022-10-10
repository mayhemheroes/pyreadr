#! /usr/bin/python3
import logging
import sys
import tempfile

import atheris
from pyreadr import PyreadrError, LibrdataError

logging.disable(logging.CRITICAL)

with atheris.instrument_imports():
    import pyreadr


@atheris.instrument_func
def TestOneInput(data):
    try:
        with tempfile.NamedTemporaryFile() as f:
            f.write(data)
            f.flush()
            pyreadr.read_r(f.name)
    except (PyreadrError, LibrdataError):
        pass

def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()

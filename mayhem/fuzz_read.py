#! /usr/bin/python3
import logging
import sys
import tempfile

import atheris
from pyreadr import PyreadrError, LibrdataError

logging.disable(logging.CRITICAL)

with atheris.instrument_imports():
    import pyreadr

f = tempfile.NamedTemporaryFile()

@atheris.instrument_func
def TestOneInput(data):
    f.write(data)
    f.flush()
    try:
        pyreadr.read_r(f.name)
    except (PyreadrError, LibrdataError):
        pass
    f.seek(0)
    f.truncate()

def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()

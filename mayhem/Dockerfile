FROM fuzzers/atheris:2.0.7-python3.9

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang zlib1g-dev libbz2-dev liblzma-dev
RUN apt-get remove gcc-x86-64-linux-gnu && apt autoclean && apt autoremove
ADD . /src
WORKDIR /src

RUN CC="/usr/bin/clang" CFLAGS="-fsanitize=fuzzer-no-link" CXX="/usr/bin/clang++" CXXFLAGS="-fsanitize=fuzzer-no-link" python3 -m pip install .

ENV LD_PRELOAD="$LD_PRELOAD:/usr/local/lib/python3.9/dist-packages/asan_with_fuzzer.so"
CMD ["/src/mayhem/fuzz_read.py"]

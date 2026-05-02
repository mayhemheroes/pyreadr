FROM fuzzers/atheris:2.0.7-python3.9

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang zlib1g-dev libbz2-dev liblzma-dev
ADD . /src
WORKDIR /src

RUN CC="/usr/bin/clang" CFLAGS="-fsanitize=address,fuzzer-no-link" CXX="/usr/bin/clang++" CXXFLAGS="-fsanitize=address,fuzzer-no-link" python3 -m pip install .

ENV LD_PRELOAD="$LD_PRELOAD:/usr/local/lib/python3.9/dist-packages/asan_with_fuzzer.so"
ENV ASAN_OPTIONS="detect_leaks=0 allocator_may_return_null=1"
CMD ["/src/mayhem/fuzz_read.py"]

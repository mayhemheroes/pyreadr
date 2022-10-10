FROM fuzzers/atheris:2.0.7-python3.9

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang zlib1g-dev libbz2-dev liblzma-dev
RUN apt-get remove gcc-x86-64-linux-gnu && apt autoclean && apt autoremove
ADD . /src
WORKDIR /src

ENV CC="/usr/bin/clang"
ENV CFLAGS="-fsanitize=address,fuzzer-no-link"
ENV CXX="/usr/bin/clang++"
ENV CXXFLAGS="-fsanitize=address,fuzzer-no-link"
RUN python3 -m pip install Cython
RUN CC="/usr/bin/clang" python3 setup.py install

ADD ./mayhem/fuzz_read.py /fuzz_read.py

CMD ["/src/mayhem/fuzz_read.py"]

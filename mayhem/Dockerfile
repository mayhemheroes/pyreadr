FROM fuzzers/atheris:2.0.7-python3.9

RUN python3 -m pip install pyreadr

ADD ./mayhem/fuzz_read.py /fuzz_read.py

CMD ["/fuzz_read.py"]

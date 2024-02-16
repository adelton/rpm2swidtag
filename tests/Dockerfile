FROM registry.fedoraproject.org/fedora
RUN dnf install -y make 'dnf-command(builddep)'
COPY . /src/
WORKDIR /src
RUN tests/build.sh

FROM registry.fedoraproject.org/fedora:39
RUN mkdir dir
RUN tar cvf test.tar dir
RUN rm -rf dir
RUN tar xvf test.tar

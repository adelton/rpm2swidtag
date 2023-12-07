FROM registry.fedoraproject.org/fedora:rawhide
RUN mkdir dir
RUN touch test dir/test
RUN tar cvf test.tar test dir
RUN rm -rf test dir
RUN tar xvf test.tar

FROM alpine:edge

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="e.g. Docker 4 C.H.I.P" \
      org.label-schema.description="Docker image for C.H.I.P" \
      org.label-schema.url="e.g. https://www.sankhe.com/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="e.g. https://github.com/vinayski/chip" \
      org.label-schema.vendor="e.g. Sankhe" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"
MAINTAINER vinayski@gmail.com

RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  apk update

RUN apk add bash \
  wget \
  curl \
  unzip \
  git \
  make \
  libc-dev \
  gcc \
  linux-headers \
  util-linux-dev \
  dpkg-dev \
  acl-dev \
  zlib-dev \
  lzo-dev \
  libusb-dev \
  ppp \
  android-tools@testing \
  uboot-tools@testing

WORKDIR /root

RUN git clone \
  --single-branch --depth 1 --branch master \
  http://github.com/vinayski/chip && \
  cd chip/sunxi-tools && \
     make && \
     make misc && \
     make install && \
     make install-misc && \
     cd ..

ARG MTD_BRANCH=by/1.5.2/next-mlc-debian

#RUN git clone \
#  --single-branch --depth 1 --branch ${MTD_BRANCH} \
#  http://github.com/nextthingco/chip-mtd-utils && \
RUN  cd chip/CHIP-mtd-utils && make 
RUN  cd chip/CHIP-mtd-utils && make install && cd .. 

ARG TOOLS_BRANCH=chip/stable-busybox

#RUN git clone \
#  --single-branch --depth 1 --branch ${TOOLS_BRANCH} \
#  https://github.com/rhodey/CHIP-tools && \
RUN  cd chip/CHIP-tools && \
     cd ..

ARG BLD_ROOT_BRANCH=chip/stable

#RUN git clone \
#  --single-branch --depth 1 --branch ${BLD_ROOT_BRANCH} \
#  https://github.com/NextThingCo/CHIP-buildroot

RUN mv /usr/local/bin/sunxi-fel /usr/local/bin/sunxi-fel.orig && \
  mv /usr/bin/fastboot /usr/bin/fastboot.orig

ADD sunxi-fel-mdev.sh /usr/local/bin/sunxi-fel
ADD fastboot-mdev.sh /usr/bin/fastboot

WORKDIR /root/CHIP-tools

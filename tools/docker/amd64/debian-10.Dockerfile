# ref: https://hub.docker.com/_/debian
FROM debian:10 AS env

#############
##  SETUP  ##
#############
RUN apt-get update -qq \
&& apt-get install -qq \
 git pkg-config wget make autoconf libtool zlib1g-dev gawk g++ curl subversion \
 swig lsb-release \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/usr/bin/bash"]

# Install CMake 3.21.1
RUN wget -q "https://cmake.org/files/v3.21/cmake-3.21.1-linux-x86_64.sh" \
&& chmod a+x cmake-3.21.1-linux-x86_64.sh \
&& ./cmake-3.21.1-linux-x86_64.sh --prefix=/usr/local/ --skip-license \
&& rm cmake-3.21.1-linux-x86_64.sh

# Java Install
RUN apt-get update -qq \
&& apt-get install -qq default-jdk maven \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Dotnet Install
# see https://docs.microsoft.com/en-us/dotnet/core/install/linux-debian#debian-10-
RUN apt-get update -qq \
&& apt-get install -qq gpg apt-transport-https \
&& wget -q "https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb \
&& dpkg -i packages-microsoft-prod.deb \
&& rm packages-microsoft-prod.deb \
&& apt-get update -qq \
&& apt-get install -qq dotnet-sdk-3.1 dotnet-sdk-6.0 \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Trigger first run experience by running arbitrary cmd
RUN dotnet --info

ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

################
##  OR-TOOLS  ##
################
FROM env AS devel
# Copy the snk key
COPY or-tools.snk /root/or-tools.snk
ENV DOTNET_SNK=/root/or-tools.snk

ARG SRC_GIT_BRANCH
ENV SRC_GIT_BRANCH ${SRC_GIT_BRANCH:-master}
ARG SRC_GIT_SHA1
ENV SRC_GIT_SHA1 ${SRC_GIT_SHA1:-unknown}

# Download sources
# use SRC_GIT_SHA1 to modify the command
# i.e. avoid docker reusing the cache when new commit is pushed
WORKDIR /root
RUN git clone -b "${SRC_GIT_BRANCH}" --single-branch https://github.com/google/or-tools \
&& echo "sha1: $(cd or-tools && git rev-parse --verify HEAD)" \
&& echo "expected sha1: ${SRC_GIT_SHA1}"

# Build third parties
FROM devel AS third_party
WORKDIR /root/or-tools
RUN make detect && make third_party

# Build project
FROM third_party AS build
RUN make detect_cc && make cc
RUN make detect_java && make java
RUN make detect_dotnet && make dotnet

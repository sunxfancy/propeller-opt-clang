FROM ubuntu:focal


RUN apt-get update \
# Install pre-reqs
  && apt-get install -y git ca-certificates \
# Install compilers
  && apt-get install -y build-essential \
  && apt-get install -y flex bison ninja-build \
  && apt-get install -y libtool autoconf automake \
# Install debuggers
  && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gdb gdbserver \
# Install utils
  && apt-get install -y wget openssh-server \
# Clean up
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


RUN mkdir /tmp/cmake \
  && cd /tmp/cmake  \
  && wget https://github.com/Kitware/CMake/releases/download/v3.21.0/cmake-3.21.0-linux-x86_64.tar.gz \
  && tar xf cmake-3.21.0-linux-x86_64.tar.gz \
  && rm -rf /usr/local/man \
  && cp -rf cmake-3.21.0-linux-x86_64/* /usr/local \
  && rm -r *

RUN useradd -ms /bin/bash propeller

# configure SSH for communication with Visual Studio Code
# RUN mkdir -p /var/run/sshd

# RUN echo 'propeller:propeller' | chpasswd \
#     && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
#     && sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

RUN apt-get update && apt-get install -y libelf-dev libssl-dev libtinfo-dev pkg-config

USER propeller
WORKDIR /home/propeller
EXPOSE 22


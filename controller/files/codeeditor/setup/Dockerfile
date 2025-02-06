FROM debian:trixie

ARG DEBIAN_FRONTEND=noninteractive

# install python + dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-requests bash-completion nano sudo htop curl git ansible && \
    apt-get clean

# install Coder server
RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN groupadd --gid 1200 saarctf && useradd --create-home --uid 1200 --gid 1200 saarctf

USER saarctf

ENTRYPOINT ["code-server"]

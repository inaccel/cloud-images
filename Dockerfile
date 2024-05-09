FROM debian

RUN apt update \
 && apt install --yes \
        guestfs-tools \
        make \
        sudo \
        unzip \
        xorriso\
 && rm --force --recursive /var/lib/apt/lists/*

ARG PACKER_VERSION=1.8.7
RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
 && unzip -d /bin packer_${PACKER_VERSION}_linux_amd64.zip \
 && rm --force packer_${PACKER_VERSION}_linux_amd64.zip

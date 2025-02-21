FROM archlinux

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    git \
    curl \
    wget \
    tar \
    rsync \
    rust \
    vim

RUN mkdir -p /usr/src/kite-tools
ADD ./scripts /usr/src/kite-tools/

RUN useradd -ms /bin/bash devel
USER devel

WORKDIR /home/tools

CMD ["/bin/bash"]
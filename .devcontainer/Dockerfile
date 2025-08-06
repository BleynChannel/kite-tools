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

RUN useradd -ms /bin/bash devel && \
    echo 'devel:1234' | chpasswd

# RUN echo "devel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/devel && \
RUN echo "devel ALL=(ALL) ALL" >> /etc/sudoers.d/devel && \
    chmod 0440 /etc/sudoers.d/devel

USER devel
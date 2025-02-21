FROM archlinux

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    git \
    # curl \
    # wget \
    # tar \
    # rsync \
    # rust \
    vim

# RUN mkdir -p /usr/src/kite-tools
# ADD ./scripts /usr/src/kite-tools/

RUN useradd -ms /bin/bash devel && \
    echo "devel ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/devel && \
    chmod 0440 /etc/sudoers.d/devel
USER devel

WORKDIR /home/devel/tools

CMD ["BUILDDIR=/tmp/makepkg makepkg -si --noconfirm"]
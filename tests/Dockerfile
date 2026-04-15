FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bat \
    curl \
    fd-find \
    fontconfig \
    fish \
    git \
    ripgrep \
    sudo \
    zsh \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser && \
    chmod 0440 /etc/sudoers.d/testuser

USER testuser
WORKDIR /home/testuser

RUN curl -sfL https://get.chezmoi.io | sh
RUN curl -fsSL https://mise.run | sh

ENV PATH="/home/testuser/.local/bin:/home/testuser/bin:${PATH}"

CMD ["/bin/bash"]

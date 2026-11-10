FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bat \
    ca-certificates \
    curl \
    fd-find \
    fish \
    fzf \
    git \
    python3-pip \
    ripgrep \
    tmux \
    vim \
    zoxide \
    zsh \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN useradd -m -s /bin/bash testuser

USER testuser
WORKDIR /home/testuser

ARG CHEZMOI_INSTALLER_CACHE_BUST=manual-build
RUN test -n "$CHEZMOI_INSTALLER_CACHE_BUST" && \
    curl --proto '=https' --tlsv1.2 -fsSL \
        -o /tmp/get-chezmoi.sh https://get.chezmoi.io && \
    sh /tmp/get-chezmoi.sh -b /home/testuser/.local/bin && \
    rm -f /tmp/get-chezmoi.sh

# rc.xsh warns when the catppuccin-mocha style is missing
# Install ptk and the catppuccin theme for rc.xsh
RUN python3 -m pip install --user --break-system-packages \
    'xonsh[ptk]' \
    'catppuccin[pygments]'

ENV PATH="/home/testuser/.local/bin:/home/testuser/bin:${PATH}"

CMD ["/bin/bash"]

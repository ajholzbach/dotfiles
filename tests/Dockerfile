FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser && \
    chmod 0440 /etc/sudoers.d/testuser

USER testuser
WORKDIR /home/testuser

RUN curl -sfL https://get.chezmoi.io | sh

ENV PATH="/home/testuser/bin:${PATH}"

CMD ["/bin/bash"]

FROM jenkins/jenkins:2.568.2-jdk21

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 986 docker \
    && usermod -aG docker jenkins

USER jenkins
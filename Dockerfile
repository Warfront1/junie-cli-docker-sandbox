FROM docker/sandbox-templates:shell

USER root

RUN apt-get update && apt-get install -y curl proxychains4 openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Download GOST for Linux
RUN curl -fsSL https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz -o /tmp/gost.gz && \
    gunzip /tmp/gost.gz && \
    mv /tmp/gost /usr/local/bin/gost && \
    chmod +x /usr/local/bin/gost

RUN curl -fsSL https://junie.jetbrains.com/install.sh | bash && \
    mv /root/.local/bin/junie /usr/local/bin/junie && \
    mv /root/.local/share/junie /usr/local/share/junie && \
    chmod +x /usr/local/bin/junie

ENV JUNIE_DATA=/usr/local/share/junie

COPY run-junie.sh /usr/local/bin/run-junie.sh
RUN chmod +x /usr/local/bin/run-junie.sh

USER agent

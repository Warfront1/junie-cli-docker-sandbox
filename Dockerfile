FROM docker/sandbox-templates:shell

USER root

RUN apt-get update && apt-get install -y curl openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://junie.jetbrains.com/install.sh | bash && \
    mv /root/.local/bin/junie /usr/local/bin/junie && \
    mv /root/.local/share/junie /usr/local/share/junie && \
    chmod +x /usr/local/bin/junie

ENV JUNIE_DATA=/usr/local/share/junie
ENV JAVA_TOOL_OPTIONS="-Dhttps.proxyHost=host.docker.internal -Dhttps.proxyPort=3128 -Dhttp.proxyHost=host.docker.internal -Dhttp.proxyPort=3128"

COPY import-ca.sh /usr/local/bin/import-ca.sh
RUN chmod +x /usr/local/bin/import-ca.sh

USER agent

RUN echo '/usr/local/bin/import-ca.sh && junie' >> /home/agent/.bashrc

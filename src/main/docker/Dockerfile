FROM ubuntu:20.04

# Install dependencies
RUN apt-get update -y && \
    apt-get install -y dos2unix wget libgomp1 dumb-init unzip ca-certificates \
                       libfontconfig1 libfreetype6 libfluidsynth2 libicu-dev \
                       libpng16-16 liblzma-dev liblzo2-2 libsdl1.2debian libsdl2-2.0-0 xz-utils curl jq

# Java 17 installation
ENV JVM_DIR=/usr/lib/jvm
RUN mkdir -p "$JVM_DIR" /tmp/downloads
ENV JDK_DOWNLOAD=https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_linux-x64_bin.tar.gz
RUN wget -q -O /tmp/downloads/openjdk.tar.gz "$JDK_DOWNLOAD" \
 && tar -xzf /tmp/downloads/openjdk.tar.gz -C "$JVM_DIR" \
 && mv "$JVM_DIR/jdk-17.0.2" "$JVM_DIR/java-17" \
 && ln -s "$JVM_DIR/java-17" "$JVM_DIR/default"

ENV JAVA_HOME="$JVM_DIR/default"
ENV PATH="$PATH:$JAVA_HOME/bin"

# Scripts
COPY src/main/docker/cleanup.sh /tmp/cleanup.sh
COPY src/main/docker/buildconfig /tmp/buildconfig
COPY --chown=1000:1000 src/main/docker/openttd.sh /openttd.sh
RUN dos2unix /tmp/cleanup.sh /tmp/buildconfig /openttd.sh \
 && chmod +x /tmp/cleanup.sh /openttd.sh

# User
RUN adduser --uid 1000 --shell /bin/bash --gecos "" openttd \
    && addgroup openttd users \
    && passwd -d openttd
USER 1000
WORKDIR /home/openttd

# Create persistent directories
USER root
RUN mkdir -p /home/openttd/server/save /home/openttd/server/config \
 && chown -R 1000:1000 /home/openttd/server
VOLUME /home/openttd/server

# Quarkus management app
COPY --chown=1000 target/quarkus-app/lib/ /deployments/lib/
COPY --chown=1000 target/quarkus-app/*.jar /deployments/
COPY --chown=1000 target/quarkus-app/app/ /deployments/app/
COPY --chown=1000 target/quarkus-app/quarkus/ /deployments/quarkus/

# Environment variables for management UI
ENV start-server.command="/openttd.sh"
ENV openttd.save.dir=/home/openttd/server/save
ENV openttd.config.dir=/home/openttd/server/config
ENV server.config.dir=/home/openttd/server

# Expose ports
EXPOSE 8080
EXPOSE 3900-3999/tcp
EXPOSE 3900-3999/udp

# Default command
CMD ["java", "-jar", "/deployments/quarkus-run.jar"]

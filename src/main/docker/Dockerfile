FROM ubuntu:20.04

ARG PATCH_VERSION
ARG OPENGFX_VERSION

###############################################################
# Install dependencies
###############################################################
RUN apt-get update && apt-get install -y \
    dos2unix wget libgomp1 unzip ca-certificates xz-utils dumb-init jq \
    libfontconfig1 libfreetype6 libfluidsynth2 libicu-dev \
    libpng16-16 liblzma-dev liblzo2-2 libsdl1.2debian libsdl2-2.0-0 \
 && rm -rf /var/lib/apt/lists/*

###############################################################
# Install Java 17
###############################################################
ENV JVM_DIR=/usr/lib/jvm
RUN mkdir -p "$JVM_DIR" /tmp/downloads

ENV JDK_DOWNLOAD=https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_linux-x64_bin.tar.gz

RUN wget -q -O /tmp/downloads/openjdk.tar.gz "$JDK_DOWNLOAD" \
 && tar -xzf /tmp/downloads/openjdk.tar.gz -C "$JVM_DIR" \
 && mv "$JVM_DIR/jdk-17.0.2" "$JVM_DIR/java-17" \
 && ln -s "$JVM_DIR/java-17" "$JVM_DIR/default"

ENV JAVA_HOME="$JVM_DIR/default"
ENV PATH="$PATH:$JAVA_HOME/bin"

###############################################################
# Add scripts
###############################################################
COPY src/main/docker/cleanup.sh /tmp/cleanup.sh
COPY src/main/docker/buildconfig /tmp/buildconfig
COPY --chown=1000:1000 src/main/docker/openttd.sh /openttd.sh

RUN dos2unix /tmp/cleanup.sh /tmp/buildconfig /openttd.sh \
 && chmod +x /tmp/cleanup.sh /openttd.sh

###############################################################
# Create openttd user
###############################################################
RUN adduser --uid 1000 --shell /bin/bash --gecos "" openttd \
 && addgroup openttd users \
 && passwd -d openttd

USER openttd
WORKDIR /home/openttd

###############################################################
# Determine latest JGRPP patch if not specified
###############################################################
RUN if [ -z "$PATCH_VERSION" ]; then \
      PATCH_VERSION=$(curl -s https://api.github.com/repos/JGRennison/OpenTTD-patches/releases/latest | jq -r '.tag_name | ltrimstr("jgrpp-")'); \
    fi && echo "Using JGRPP patch version $PATCH_VERSION"

###############################################################
# Determine latest OpenGFX version if not specified
###############################################################
RUN if [ -z "$OPENGFX_VERSION" ]; then \
      OPENGFX_VERSION=$(curl -s https://cdn.openttd.org/opengfx-releases/latest-linux.txt); \
    fi && echo "Using OpenGFX version $OPENGFX_VERSION"

###############################################################
# Install JGRPP and OpenGFX
###############################################################
RUN wget https://github.com/JGRennison/OpenTTD-patches/releases/download/jgrpp-${PATCH_VERSION}/openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64.tar.xz \
 && wget https://cdn.openttd.org/opengfx-releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}-all.zip

RUN tar -xf openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64.tar.xz

RUN mkdir openttd-jgrpp
RUN cp -a openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64/. openttd-jgrpp/

RUN unzip opengfx-${OPENGFX_VERSION}-all.zip \
 && tar -xf opengfx-${OPENGFX_VERSION}.tar -C openttd-jgrpp/baseset/

# Clean up safely
RUN rm -rf *.tar *.zip openttd-jgrpp-${PATCH_VERSION}*

###############################################################
# Return to root to finish install
###############################################################
USER root
RUN /tmp/cleanup.sh

RUN mkdir -p /home/openttd/server \
 && chown -R 1000:1000 /home/openttd/server

VOLUME /home/openttd

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en'

###############################################################
# Copy management app (unchanged)
###############################################################
COPY --chown=1000 target/quarkus-app/lib/ /deployments/lib/
COPY --chown=1000 target/quarkus-app/*.jar /deployments/
COPY --chown=1000 target/quarkus-app/app/ /deployments/app/
COPY --chown=1000 target/quarkus-app/quarkus/ /deployments/quarkus/

USER 1000

###############################################################
# Settings for manager compatibility
###############################################################
ENV start-server.command="/openttd.sh"
ENV openttd.save.dir=/home/openttd/server/save
ENV openttd.config.dir=/home/openttd/server/config
ENV server.config.dir=/home/openttd/server

CMD ["java", "-jar", "/deployments/quarkus-run.jar"]

EXPOSE 8080

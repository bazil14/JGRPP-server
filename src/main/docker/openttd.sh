#!/bin/sh

# Default environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}
PHOME=${PHOME:-"/home/openttd"}
USER=${USER:-"openttd"}

# Ensure home directory exists and is owned by openttd
if [ ! -d "${PHOME}" ]; then
    mkdir -p "${PHOME}"
    chown ${PUID}:${PGID} "${PHOME}"
fi

OPENTTD_CONFIG_DIR="${PHOME}/.openttd"

# Ensure config dir exists
if [ ! -d "$OPENTTD_CONFIG_DIR" ]; then
    mkdir -p "$OPENTTD_CONFIG_DIR"
    chown -R "$USER:$USER" "$OPENTTD_CONFIG_DIR"
fi

echo "
-----------------------------------
GID/UID
-----------------------------------
User uid:    $(id -u ${USER})
User gid:    $(id -g ${USER})
User Home:   ${PHOME}
-----------------------------------
"

# Build the command from script arguments
cmd=""
for var in "$@"; do
    cmd="$cmd '$var' "
done
# --- fix perms on important mounted folders (self-heal)
for d in "${PHOME}" "${PHOME}/server" "${PHOME}/server/save" "${PHOME}/server/config" "${PHOME}/.openttd"; do
  if [ -d "${d}" ]; then
    log "Ensuring ownership ${PUID}:${PGID} on ${d}"
    chown -R "${PUID}:${PGID}" "${d}" || true
  fi
done
# Ensure JGRPP and OpenGFX exist, fetch latest if missing
JGRPP_DIR="${PHOME}/openttd-jgrpp"
OPENGFX_DIR="${JGRPP_DIR}/baseset"

if [ ! -d "$JGRPP_DIR" ] || [ ! -f "$JGRPP_DIR/openttd" ]; then
    echo "Downloading latest JGRPP..."
    PATCH_VERSION=$(curl -s https://api.github.com/repos/JGRennison/OpenTTD-patches/releases/latest | jq -r '.tag_name | ltrimstr("jgrpp-")')
    wget -q -O /tmp/openttd-jgrpp.tar.xz "https://github.com/JGRennison/OpenTTD-patches/releases/download/jgrpp-${PATCH_VERSION}/openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64.tar.xz"
    tar -xf /tmp/openttd-jgrpp.tar.xz -C "${PHOME}"
    mkdir -p "${JGRPP_DIR}"
    cp -a "${PHOME}/openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64/." "${JGRPP_DIR}/"
    rm -rf "${PHOME}/openttd-jgrpp-${PATCH_VERSION}-linux-generic-amd64" /tmp/openttd-jgrpp.tar.xz
fi

if [ ! -d "$OPENGFX_DIR" ] || [ ! -f "$OPENGFX_DIR/readme.txt" ]; then
    echo "Downloading latest OpenGFX..."

    OPENGFX_VERSION=$(
        curl -s https://cdn.openttd.org/opengfx-releases/ \
        | grep -oP 'href="\K[0-9]+\.[0-9]+(?=/")' \
        | sort -V \
        | tail -1
    )

    echo "Latest OpenGFX version: $OPENGFX_VERSION"

    # Download the correct working file: opengfx-VERSION-all.zip
    wget -q -O /tmp/opengfx.zip \
        "https://cdn.openttd.org/opengfx-releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}-all.zip"

    # Extract
    unzip -qq /tmp/opengfx.zip -d /tmp/opengfx

    # Inside the zip there is a .tar containing the base set
    tar -xf /tmp/opengfx/opengfx-${OPENGFX_VERSION}.tar -C "${OPENGFX_DIR}"

    # Cleanup
    rm -rf /tmp/opengfx /tmp/opengfx.zip
fi


# Run OpenTTD as openttd user
exec su -l ${USER} -c "${JGRPP_DIR}/openttd -D ${cmd}"

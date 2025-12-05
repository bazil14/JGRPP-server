#!/bin/sh
set -e

PUID=${PUID:-911}
PGID=${PGID:-911}
PHOME=${PHOME:-"/home/openttd"}
USER=${USER:-"openttd"}

# Ensure UID/GID matches
if [ "$(id -u ${USER})" -ne "$PUID" ]; then usermod -o -u "$PUID" ${USER}; fi
if [ "$(id -g ${USER})" -ne "$PGID" ]; then groupmod -o -g "$PGID" ${USER}; fi

# Ensure home directory exists
if [ "$(grep ${USER} /etc/passwd | cut -d':' -f6)" != "$PHOME" ]; then
    mkdir -p "$PHOME"
    chown $USER:$USER "$PHOME"
    usermod -m -d "$PHOME" $USER
fi

echo "-----------------------------------"
echo "GID/UID"
echo "-----------------------------------"
echo "User uid:    $(id -u $USER)"
echo "User gid:    $(id -g $USER)"
echo "User Home:   $(grep $USER /etc/passwd | cut -d':' -f6)"
echo "-----------------------------------"

# Directories
OPENTTD_DIR="$PHOME/openttd-jgrpp"
mkdir -p "$OPENTTD_DIR"

# Fetch latest JGRPP
LATEST_JGRPP=$(curl -s https://api.github.com/repos/JGRennison/OpenTTD-patches/releases/latest \
    | jq -r '.tag_name | ltrimstr("jgrpp-")')
JGRPP_URL="https://github.com/JGRennison/OpenTTD-patches/releases/download/jgrpp-${LATEST_JGRPP}/openttd-jgrpp-${LATEST_JGRPP}-linux-generic-amd64.tar.xz"

echo "Downloading JGRPP $LATEST_JGRPP..."
wget -q -O /tmp/openttd-jgrpp.tar.xz "$JGRPP_URL"
tar -xf /tmp/openttd-jgrpp.tar.xz -C "$OPENTTD_DIR" --strip-components=1
rm /tmp/openttd-jgrpp.tar.xz

# Fetch latest OpenGFX
LATEST_OPENGFX=$(curl -s https://cdn.openttd.org/opengfx-releases/ \
    | grep -oP 'opengfx-\K[0-9]+\.[0-9]+(?=-all.zip)' | sort -V | tail -1)
OPENGFX_URL="https://cdn.openttd.org/opengfx-releases/opengfx-${LATEST_OPENGFX}-all.zip"

echo "Downloading OpenGFX $LATEST_OPENGFX..."
wget -q -O /tmp/opengfx.zip "$OPENGFX_URL"
unzip -o /tmp/opengfx.zip -d "$OPENTTD_DIR/baseset"
rm /tmp/opengfx.zip

# Run OpenTTD with arguments
cmd=""
for var in "$@"; do
  cmd="$cmd '$var'"
done

su -l $USER -c "$OPENTTD_DIR/openttd -D $cmd"
exit 0

#!/bin/sh
set -eu

# --- configuration (can be overridden via env) ----------------
PUID=${PUID:-1000}
PGID=${PGID:-1000}
PHOME=${PHOME:-"/home/openttd"}
USER=${USER:-"openttd"}

# Internal paths
JGRPP_DIR="${PHOME}/openttd-jgrpp"
OPENGFX_BASE="${PHOME}/.openttd"           # OpenTTD config root
OPENGFX_BASESET="${OPENGFX_BASE}/baseset"
TMPDIR="/tmp/openttd-downloads"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# --- ensure home and server directories exist and have correct ownership
mkdir -p "${PHOME}" "${PHOME}/server" "${PHOME}/server/save" "${PHOME}/server/config" "${OPENGFX_BASESET}"
chown -R "${PUID}:${PGID}" "${PHOME}"

log "GID/UID"
log "User uid:    $(id -u ${USER} 2>/dev/null || echo unknown)"
log "User gid:    $(id -g ${USER} 2>/dev/null || echo unknown)"
log "User Home:   ${PHOME}"

# --- helper: run a command as the target user in foreground with the right environment
run_as_user() {
  # arguments passed verbatim
  su -l "${USER}" -c "$*"
}

# --- helper: safe cleanup
cleanup_tmp() {
  rm -rf "${TMPDIR}" >/dev/null 2>&1 || true
}
trap cleanup_tmp EXIT

mkdir -p "${TMPDIR}"

# --- fix perms on important mounted folders (self-heal)
for d in "${PHOME}" "${PHOME}/server" "${PHOME}/server/save" "${PHOME}/server/config" "${OPENGFX_BASE}"; do
  if [ -d "${d}" ]; then
    log "Ensuring ownership ${PUID}:${PGID} on ${d}"
    chown -R "${PUID}:${PGID}" "${d}" || true
  fi
done

# --- Download JGRPP if missing or binary absent ----------------
if [ ! -x "${JGRPP_DIR}/openttd" ]; then
  log "JGRPP not found, attempting to download latest JGRPP..."
  # Use GitHub API to get the browser_download_url for linux tar.xz asset
  JGRPP_RELEASE_JSON=$(mktemp -p "${TMPDIR}" jgrpp.XXXX.json)
  curl -sSf "https://api.github.com/repos/JGRennison/OpenTTD-patches/releases/latest" -o "${JGRPP_RELEASE_JSON}"
  # pick the asset that looks like linux-generic-amd64.tar.xz OR linux-amd64.tar.xz etc.
  JGRPP_URL=$(grep -oP '"browser_download_url":\s*"\K[^"]+' "${JGRPP_RELEASE_JSON}" \
              | grep -E 'linux.*(amd64|x86_64).*\.tar(\.xz|\.gz)?$' \
              | head -n1 || true)

  if [ -z "${JGRPP_URL}" ]; then
    log "ERROR: Could not locate JGRPP linux asset in GitHub release JSON"
  else
    log "Found JGRPP URL: ${JGRPP_URL}"
    curl -L -o "${TMPDIR}/jgrpp.tar.xz" "${JGRPP_URL}"
    mkdir -p "${TMPDIR}/jgrpp"
    tar -xf "${TMPDIR}/jgrpp.tar.xz" -C "${TMPDIR}/jgrpp"
    # copy into place (preserve existing if present)
    mkdir -p "${JGRPP_DIR}"
    cp -a "${TMPDIR}/jgrpp"/* "${JGRPP_DIR}/" || true
    chmod +x "${JGRPP_DIR}/openttd" || true
    chown -R "${PUID}:${PGID}" "${JGRPP_DIR}"
    log "JGRPP installed to ${JGRPP_DIR}"
  fi
fi

# --- Download OpenGFX if missing --------------------------------
# Condition: require a recognizable file in baseset (readme.txt or some .png/.grf)
if [ -z "$(ls -A "${OPENGFX_BASESET}" 2>/dev/null || true)" ]; then
  log "OpenGFX baseset not found in ${OPENGFX_BASESET}, attempting to download latest OpenGFX..."

  # Determine latest version from the CDN directory listing
  OPENGFX_VERSION=$(curl -s "https://cdn.openttd.org/opengfx-releases/" \
                     | grep -oP 'href="\K[0-9]+\.[0-9]+(?=/")' \
                     | sort -V | tail -n1 || true)

  if [ -z "${OPENGFX_VERSION}" ]; then
    log "ERROR: Could not determine OpenGFX version from CDN listing"
  else
    log "Latest OpenGFX version: ${OPENGFX_VERSION}"
    # prefer the -all.zip (contains the tar), fall back to .tar if necessary
    OPENGFX_ZIP_URL="https://cdn.openttd.org/opengfx-releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}-all.zip"
    OPENGFX_TAR_URL="https://cdn.openttd.org/opengfx-releases/${OPENGFX_VERSION}/opengfx-${OPENGFX_VERSION}.tar"

    # try zip first (common)
    if curl -sIf "${OPENGFX_ZIP_URL}"; then
      log "Downloading ${OPENGFX_ZIP_URL}"
      curl -L -o "${TMPDIR}/opengfx.zip" "${OPENGFX_ZIP_URL}"
      mkdir -p "${TMPDIR}/opengfx"
      unzip -qq "${TMPDIR}/opengfx.zip" -d "${TMPDIR}/opengfx" || {
        log "ERROR: unzip failed for ${TMPDIR}/opengfx.zip"
      }
      # inside the zip there's usually a .tar (opengfx-<ver>.tar) — extract it if present
      if [ -f "${TMPDIR}/opengfx/opengfx-${OPENGFX_VERSION}.tar" ]; then
        mkdir -p "${OPENGFX_BASESET}"
        tar -xf "${TMPDIR}/opengfx/opengfx-${OPENGFX_VERSION}.tar" -C "${TMPDIR}/opengfx"
        # copy all relevant files into baseset
        mkdir -p "${OPENGFX_BASESET}"
        cp -a "${TMPDIR}/opengfx/opengfx-${OPENGFX_VERSION}/." "${OPENGFX_BASESET}/" || true
      else
        # some zips already contain files directly: copy any image/grf/obg files
        mkdir -p "${OPENGFX_BASESET}"
        cp -a "${TMPDIR}/opengfx"/opengfx-*/* "${OPENGFX_BASESET}/" 2>/dev/null || true
      fi
    elif curl -sIf "${OPENGFX_TAR_URL}"; then
      log "Downloading ${OPENGFX_TAR_URL}"
      curl -L -o "${TMPDIR}/opengfx.tar" "${OPENGFX_TAR_URL}"
      mkdir -p "${TMPDIR}/opengfx"
      tar -xf "${TMPDIR}/opengfx.tar" -C "${TMPDIR}/opengfx"
      mkdir -p "${OPENGFX_BASESET}"
      # copy contents
      cp -a "${TMPDIR}/opengfx"/opengfx-*/* "${OPENGFX_BASESET}/" || true
    else
      log "ERROR: Neither ${OPENGFX_ZIP_URL} nor ${OPENGFX_TAR_URL} appears to be available"
    fi

    # Fix ownership
    chown -R "${PUID}:${PGID}" "${OPENGFX_BASE}"
    log "OpenGFX installed to ${OPENGFX_BASESET}"
  fi
fi

# --- ensure OpenTTD config file exists (touch) -------------------
if [ ! -f "${OPENGFX_BASE}/openttd.cfg" ]; then
  log "Creating empty config ${OPENGFX_BASE}/openttd.cfg"
  touch "${OPENGFX_BASE}/openttd.cfg"
  chown "${PUID}:${PGID}" "${OPENGFX_BASE}/openttd.cfg"
fi

# --- final perm fix for server save/config (again) --------------
for d in "${PHOME}/server" "${PHOME}/server/save" "${PHOME}/server/config" "${OPENGFX_BASE}"; do
  if [ -d "$d" ]; then
    chown -R "${PUID}:${PGID}" "$d" || true
  fi
done

# --- Build the command string (pass through args) ----------------
cmd=""
for var in "$@"; do
  # escape single quotes in args
  escaped=$(printf "%s" "$var" | sed "s/'/'\"'\"'/g")
  cmd="$cmd '$escaped'"
done

# --- sanity checks before exec ----------------------------------
if [ ! -x "${JGRPP_DIR}/openttd" ]; then
  log "ERROR: OpenTTD binary not found at ${JGRPP_DIR}/openttd. Aborting."
  exit 1
fi

log "Starting OpenTTD as ${USER} (foreground)"
exec su -l "${USER}" -c "${JGRPP_DIR}/openttd -D ${cmd}"

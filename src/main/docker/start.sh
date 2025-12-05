#!/bin/bash
# If the mounted /home/openttd is empty, populate with defaults
if [ ! -f /home/openttd/openttd-jgrpp/openttd ]; then
  echo "Populating /home/openttd with default files..."
  cp -a /tmp/default_openttd/. /home/openttd/
  chown -R 1000:1000 /home/openttd
fi

# Execute the main CMD
exec "$@"
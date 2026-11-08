#!/bin/sh
if [ -n "${FLAG:-}" ]; then
    sed -i "s/CTF{test_123}/$FLAG/g" /usr/share/nginx/html/index.html 2>/dev/null || true
fi

if [ $# -eq 0 ]; then
    exec nginx -g "daemon off;"
else
    exec "$@"
fi


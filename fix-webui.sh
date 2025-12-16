#!/bin/bash
# Fix Open5GS WebUI to listen on all interfaces

echo "Fixing WebUI configuration..."
sed -i "s/'localhost'/'0.0.0.0'/" /usr/lib/node_modules/open5gs/server/index.js

echo "Restarting WebUI service..."
systemctl restart open5gs-webui

sleep 3

echo "Checking WebUI listening port..."
ss -tlnp | grep 9999

echo ""
echo "WebUI should now be accessible at http://$(curl -s ifconfig.me):9999"

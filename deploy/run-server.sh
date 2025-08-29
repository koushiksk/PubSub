#!/bin/bash -e

cd /opt/app

# CloudSQL Proxy
# cp /opt/app/deploy/supervisor_conf.d/cloud_sql_proxy.conf /etc/supervisor/conf.d/

# supervisord -c /etc/supervisor/supervisord.conf

echo "starting migrations"
/opt/release/endpoint_scan_backend/bin/start_server eval 'Elixir.Release.Tasks.migrate()'
echo "migrations finished"
echo "Starting server"
/opt/release/endpoint_scan_backend/bin/start_server start

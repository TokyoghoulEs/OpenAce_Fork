#!/bin/bash
set -e
set -x  # Muestra cada comando ejecutado para depuración

# Start cron daemon
cron

FORWARDED_PORT_FILE="/tmp/gluetun/forwarded_port"

echo "Looking for Gluetun port file: $FORWARDED_PORT_FILE"
for i in {1..20}; do
  if [[ -s "$FORWARDED_PORT_FILE" ]]; then
    PORT=$(cat "$FORWARDED_PORT_FILE")
    echo "Port successfully retrieved from Gluetun: $PORT"
    break
  fi
  echo "Gluetun hasn't provided a port yet, waiting... ($i/20)"
  sleep 1
done

if [[ -z "$PORT" ]]; then
  PORT=${ACESTREAM_PORT:-6878}
  echo "No forwarded port found, falling back to default: $PORT"
fi

# Verificar que el ejecutable exista
if [[ ! -x /openace/start-engine ]]; then
  echo "Error: /openace/start-engine no encontrado o no es ejecutable"
  exit 1
fi

echo "Starting AceStream on port $PORT..."
/openace/start-engine --client-console --port "$PORT" >> /var/log/openace/acestream.log 2>&1 &

# Esperar un poco para que el motor inicie
sleep 5

# Verificar que el motor AceStream esté escuchando en el puerto
if ! netstat -tuln | grep ":$PORT" > /dev/null; then
  echo "Error: AceStream no está escuchando en el puerto $PORT"
  exit 1
fi

export PYTHONPATH=/openace

echo "Starting proxy server..."
exec gunicorn --chdir /openace --worker-class gevent --bind 0.0.0.0:8888 --timeout 3600 server:app

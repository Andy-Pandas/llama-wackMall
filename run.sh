#!/usr/bin/env bash
# run.sh - start/stop llama-server with multi-model presets
# Usage: ./run.sh [start|stop|status]
# All model parameters are in models-presets.ini
# Pi-agent (pi-llama-server) handles model switching via /models API

set -euo pipefail

PROJECT_DIR="$HOME/exp/llama-wackMall"
SERVER="$PROJECT_DIR/build/bin/llama-server"
PRESET="$PROJECT_DIR/models-presets.ini"
PIDFILE="$PROJECT_DIR/llama.pid"
PORT="${PORT:-8080}"

start() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Server already running (PID $(cat "$PIDFILE"))"
        exit 0
    fi

    if [[ ! -x "$SERVER" ]]; then
        echo "Error: server binary not found: $SERVER"
        exit 1
    fi

    echo "Starting llama-server with presets: $PRESET"
    echo "  Port:   $PORT"
    echo "  URL:    http://127.0.0.1:$PORT"

    nohup "$SERVER" \
        --models-preset "$PRESET" \
        --host 127.0.0.1 \
        --port "$PORT" \
        > /dev/null 2>&1 &

    echo $! >"$PIDFILE"
    echo "Started (PID $(cat "$PIDFILE"))"
    echo "Wait ~10 sec, then check: $0 status"
}

stop() {
    if [[ ! -f "$PIDFILE" ]]; then
        echo "Server not running (no $PIDFILE)"
        exit 0
    fi

    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        sleep 2
        kill -9 "$PID" 2>/dev/null || true
        echo "Stopped (PID $PID)"
    else
        echo "Process $PID not found"
    fi
    rm -f "$PIDFILE"
}

status() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        PID=$(cat "$PIDFILE")
        echo "Running (PID $PID)"
        echo "  URL: http://127.0.0.1:$PORT"
    else
        echo "Not running"
    fi
}

case "${1:-start}" in
start) start ;;
stop) stop ;;
status) status ;;
*)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac

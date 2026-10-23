#!/usr/bin/env bash
# run.sh - start/stop Qwen3.6-35B-A3B server in background
# Usage: ./run.sh [start|stop|status|restart]

set -euo pipefail

PROJECT_DIR="$HOME/exp/llama-wackMall"
BUILD_DIR="$PROJECT_DIR/build"
MODEL="$PROJECT_DIR/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf"
SERVER="$BUILD_DIR/bin/llama-server"
LOG="$PROJECT_DIR/llama.log"
PIDFILE="$PROJECT_DIR/llama.pid"

PORT="${PORT:-8080}"
EXPERT_S="${LLAMA_EXPERT_S:-32}"
NGL="${NGL:-20}"
CTX="${CTX:-131072}"
THREADS="${THREADS:-8}"

start() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Server already running (PID $(cat "$PIDFILE"))"
        exit 0
    fi

    if [[ ! -f "$MODEL" ]]; then
        echo "Error: model not found: $MODEL"
        exit 1
    fi

    if [[ ! -x "$SERVER" ]]; then
        echo "Error: server binary not found: $SERVER"
        exit 1
    fi

    cd "$BUILD_DIR"

    echo "Starting Qwen3.6-35B-A3B..."
    echo "  Port:     $PORT"
    echo "  Experts:  $EXPERT_S"
    echo "  GPU layers: $NGL"
    echo "  Log:      $LOG"

    LLAMA_EXPERT_S="$EXPERT_S" nohup "$SERVER" \
        -m "$MODEL" \
        -c "$CTX" \
        --host 127.0.0.1 \
        --port "$PORT" \
        -ngl "$NGL" \
        -t "$THREADS" \
        -ctk q8_0 \
        -ctv q8_0 \
        >"$LOG" 2>&1 &

    echo $! >"$PIDFILE"
    echo "Started (PID $(cat "$PIDFILE"))"
    echo "Wait ~20 sec, then open: http://localhost:$PORT"
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
        echo "  URL: http://localhost:$PORT"
        echo "  Log: tail -f $LOG"
    else
        echo "Not running"
    fi
}

case "${1:-start}" in
start) start ;;
stop) stop ;;
status) status ;;
restart)
    stop
    sleep 1
    start
    ;;
log) tail -f "$LOG" ;;
*)
    echo "Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac

#!/usr/bin/env bash
# run.sh - start/stop Qwen3.6-35B-A3B server in background (single model, direct)
# Usage: ./run.sh [start|stop|status|log]
#
# Direct launch (no router). Optimized per bench b11540 for RTX 3070 8GB +
# Xeon E5-2680 v4. ~16 tok/s (up from 3.3). Tuned threads/ubatch.
# NOTE: UD-Q4_K_XL has NO MTP/draft layers, so draft-mtp is not used.
# Context stays 128k.
#   LLAMA_EXPERT_S  hot expert slots per layer (env, 32 by default)

set -euo pipefail

PROJECT_DIR="$HOME/exp/llama-wackMall"
SERVER="$PROJECT_DIR/build/bin/llama-server"
MODEL="$PROJECT_DIR/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf"
PIDFILE="$PROJECT_DIR/llama.pid"
LOG="$PROJECT_DIR/llama.log"
PORT="${PORT:-8080}"

EXPERT_S="${LLAMA_EXPERT_S:-32}"

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

    echo "Starting Qwen3.6-35B-A3B (single model, direct)..."
    echo "  Port:      $PORT"
    echo "  Experts:   $EXPERT_S"
    echo "  GPU layers:24 | CPU MoE: 28 | no-mmap | ctx 128k | -t 20 -ub 512"

    LLAMA_EXPERT_S="$EXPERT_S" nohup "$SERVER" \
        -m "$MODEL" \
        -c 131072 \
        --host 127.0.0.1 \
        --port "$PORT" \
        -ngl 24 \
        --n-cpu-moe 28 \
        --no-mmap \
        -ctk q8_0 \
        -ctv q8_0 \
        --flash-attn on \
        --reasoning off \
        -t 20 \
        -ub 512 \
        >"$LOG" 2>&1 &

    echo $! >"$PIDFILE"
    echo "Started (PID $(cat "$PIDFILE"))"
    echo "Log:  $LOG"
    echo "Open: http://localhost:$PORT"
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

log() {
    tail -f "$LOG"
}

case "${1:-start}" in
start) start ;;
stop) stop ;;
status) status ;;
log) log ;;
*)
    echo "Usage: $0 {start|stop|status|log}"
    exit 1
    ;;
esac

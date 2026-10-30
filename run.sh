#!/usr/bin/env bash
# run.sh - start/stop Qwen3.6-35B-A3B server in background
# Usage: ./run.sh [start|stop|status|restart|log|check]
#
# Edge-of-knife config for RTX 3070 8GB + Xeon E5-2680 v4 + DDR4-2133.
# Context stays at 128k. Experts are pushed to CPU (slow RAM) to free VRAM
# for more non-expert layers on GPU. Tune via env vars:
#   NGL=24 N_CPU_MOE=28 ./run.sh restart
#   UBATCH=1024 ./run.sh restart

set -euo pipefail

PROJECT_DIR="$HOME/exp/llama-wackMall"
BUILD_DIR="$PROJECT_DIR/build"
MODEL="$PROJECT_DIR/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf"
SERVER="$BUILD_DIR/bin/llama-server"
LOG="$PROJECT_DIR/llama.log"
PIDFILE="$PROJECT_DIR/llama.pid"

PORT="${PORT:-8080}"
EXPERT_S="${LLAMA_EXPERT_S:-32}"
NGL="${NGL:-24}"
CTX="${CTX:-131072}"
THREADS="${THREADS:-12}"

N_CPU_MOE="${N_CPU_MOE:-28}"
UBATCH="${UBATCH:-1024}"

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

    echo "Starting Qwen3.6-35B-A3B (edge-of-knife)..."
    echo "  Port:       $PORT"
    echo "  Experts:    $EXPERT_S"
    echo "  GPU layers: $NGL"
    echo "  CPU MoE:    $N_CPU_MOE"
    echo "  Context:    $CTX"
    echo "  Threads:    $THREADS"
    echo "  UBATCH:     $UBATCH"
    echo "  Log:        $LOG"

    LLAMA_EXPERT_S="$EXPERT_S" nohup "$SERVER" \
        -m "$MODEL" \
        -c "$CTX" \
        --host 127.0.0.1 \
        --port "$PORT" \
        -ngl "$NGL" \
        --n-cpu-moe "$N_CPU_MOE" \
        -t "$THREADS" \
        --ubatch-size "$UBATCH" \
        --flash-attn on \
        --no-mmap \
        -ctk q8_0 \
        -ctv q8_0 \
        --reasoning off \
        >"$LOG" 2>&1 &

    echo $! >"$PIDFILE"
    echo "Started (PID $(cat "$PIDFILE"))"
    echo "Wait ~20 sec, then check: ./run.sh check"
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
        echo "  URL: http://localhost:$PORT"
        echo "  Log: tail -f $LOG"
    else
        echo "Not running"
    fi
}

check() {
    echo "Checking log for startup failures..."
    if grep -qE "CUDA out of memory|failed to allocate|error loading model|unknown argument" "$LOG" 2>/dev/null; then
        echo ""
        echo "WARNING: possible startup failure detected."
        echo "Last 40 lines of log:"
        tail -n 40 "$LOG"
        echo ""
        echo "Fallback options:"
        echo "    NGL=20 N_CPU_MOE=32 ./run.sh restart"
        echo "    CTX=65536 ./run.sh restart   # if 128k does not fit"
    else
        echo "OK: no startup errors found in log."
        echo "Recent timing lines:"
        grep -E "eval time|prompt eval time|n_decoded" "$LOG" | tail -10 || true
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
check) check ;;
*)
    echo "Usage: $0 {start|stop|status|restart|log|check}"
    exit 1
    ;;
esac

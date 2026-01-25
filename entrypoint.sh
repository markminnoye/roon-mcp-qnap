#!/bin/bash
# ------------------------------------------------------------------------------
# Entrypoint script for RWAV Bridge + MCP container
# Starts both RWAV Bridge and RWAV Bridge MCP server
# ------------------------------------------------------------------------------

set -e

# Configuration
RWAV_BRIDGE_DIR="/opt/rwav-bridge"
RWAV_BRIDGE_PORT="${RWAV_BRIDGE_PORT:-3002}"
RWAV_BASE="${RWAV_BASE:-http://127.0.0.1:${RWAV_BRIDGE_PORT}}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-2}"

# PIDs for process management
BRIDGE_PID=""
MCP_PID=""

# Logging helpers
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Cleanup function for graceful shutdown
cleanup() {
    log "Received shutdown signal, stopping services..."
    
    if [ -n "$MCP_PID" ] && kill -0 "$MCP_PID" 2>/dev/null; then
        log "Stopping RWAV Bridge MCP (PID: $MCP_PID)..."
        kill -TERM "$MCP_PID" 2>/dev/null || true
        wait "$MCP_PID" 2>/dev/null || true
    fi
    
    if [ -n "$BRIDGE_PID" ] && kill -0 "$BRIDGE_PID" 2>/dev/null; then
        log "Stopping RWAV Bridge (PID: $BRIDGE_PID)..."
        kill -TERM "$BRIDGE_PID" 2>/dev/null || true
        wait "$BRIDGE_PID" 2>/dev/null || true
    fi
    
    log "Shutdown complete."
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Wait for RWAV Bridge to be ready
wait_for_bridge() {
    local elapsed=0
    log "Waiting for RWAV Bridge to be ready on port ${RWAV_BRIDGE_PORT}..."
    
    while [ $elapsed -lt $HEALTH_CHECK_TIMEOUT ]; do
        if curl -sf "http://127.0.0.1:${RWAV_BRIDGE_PORT}/version" > /dev/null 2>&1; then
            log "RWAV Bridge is ready!"
            return 0
        fi
        sleep $HEALTH_CHECK_INTERVAL
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done
    
    log_error "RWAV Bridge failed to start within ${HEALTH_CHECK_TIMEOUT} seconds"
    return 1
}

# Start RWAV Bridge
start_bridge() {
    log "Starting RWAV Bridge..."
    cd "$RWAV_BRIDGE_DIR"
    # Use bundled Node.js with dist/server.js
    ./node dist/server.js &
    BRIDGE_PID=$!
    log "RWAV Bridge started (PID: $BRIDGE_PID)"
}

# Start RWAV Bridge MCP
start_mcp() {
    log "Starting RWAV Bridge MCP with RWAV_BASE=${RWAV_BASE}..."
    export RWAV_BASE
    
    # Run MCP in foreground (for stdio transport) or background based on mode
    if [ "${MCP_MODE:-stdio}" = "stdio" ]; then
        # For stdio mode, run in foreground so container stays alive
        rwav-bridge-mcp &
        MCP_PID=$!
        log "RWAV Bridge MCP started in stdio mode (PID: $MCP_PID)"
    else
        rwav-bridge-mcp &
        MCP_PID=$!
        log "RWAV Bridge MCP started (PID: $MCP_PID)"
    fi
}

# Main execution
main() {
    log "================================================"
    log "RWAV Bridge + MCP Container Starting"
    log "================================================"
    log "RWAV Bridge Version: $(cat ${RWAV_BRIDGE_DIR}/version.txt 2>/dev/null || echo 'unknown')"
    log "MCP Version: $(rwav-bridge-mcp --version 2>/dev/null || echo 'unknown')"
    log "RWAV_BASE: ${RWAV_BASE}"
    log "================================================"
    
    # Start RWAV Bridge
    start_bridge
    
    # Wait for RWAV Bridge to be ready
    if ! wait_for_bridge; then
        log_error "Failed to start RWAV Bridge"
        cleanup
        exit 1
    fi
    
    # Start MCP server
    start_mcp
    
    log "All services started successfully"
    log "RWAV Bridge HTTP: http://localhost:${RWAV_BRIDGE_PORT}"
    log "MCP server ready for connections"
    
    # Wait for processes
    wait $MCP_PID $BRIDGE_PID
}

main "$@"

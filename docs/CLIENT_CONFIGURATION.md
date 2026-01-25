# MCP Client Configuration Guide

This guide explains all options for configuring MCP clients (BoltAI, Claude Desktop, Gemini CLI, Raycast) to connect to RWAV Bridge for Roon control.

---

## Deployment Scenarios Overview

| Scenario | Docker Location | MCP Server | Best For |
|----------|-----------------|------------|----------|
| **A** | Local (Mac) | In Docker | Local development |
| **B** | Remote (QNAP) | In Docker + SSH tunnel | Headless NAS |
| **C** | Remote (QNAP) | Local + HTTP to Bridge | Best performance |
| **D** | None | Local MCP + Local Bridge | Desktop with Roon Core nearby |

---

## Scenario A: Docker on Local Machine

Docker container runs on your Mac. MCP clients connect via `docker exec`.

```
┌─────────────────────────────────────────────────┐
│                     Mac                         │
│  ┌──────────┐    docker exec    ┌────────────┐ │
│  │MCP Client│ ◄───────────────► │  Docker    │ │
│  └──────────┘                   │  Container │ │
│                                 └──────┬─────┘ │
└────────────────────────────────────────┼───────┘
                                         │ Roon API
                                   ┌─────▼─────┐
                                   │ Roon Core │
                                   └───────────┘
```

### Configuration

```json
{
  "mcpServers": {
    "roon": {
      "command": "docker",
      "args": ["exec", "-i", "roon-mcp", "rwav-bridge-mcp"]
    }
  }
}
```

### Setup

```bash
# Start container
docker run -d --network host --name roon-mcp roon-mcp-qnap:latest

# Verify
docker exec roon-mcp curl -s http://localhost:3002/version
```

---

## Scenario B: Docker on Remote Server (SSH Tunnel)

Docker container runs on QNAP NAS. MCP clients connect via SSH tunnel to `docker exec`.

```
┌─────────────┐                    ┌─────────────────────────┐
│    Mac      │                    │       QNAP NAS          │
│ ┌─────────┐ │    SSH tunnel      │  ┌──────────────────┐  │
│ │MCP      │ │ ─────────────────► │  │ Docker Container │  │
│ │Client   │ │                    │  │ ┌──────────────┐ │  │
│ └─────────┘ │                    │  │ │RWAV Bridge   │ │  │
└─────────────┘                    │  │ │MCP + Bridge  │ │  │
                                   │  │ └──────┬───────┘ │  │
                                   │  └────────┼─────────┘  │
                                   │           │ Roon API   │
                                   │     ┌─────▼─────┐      │
                                   │     │ Roon Core │      │
                                   │     └───────────┘      │
                                   └─────────────────────────┘
```

### Configuration

```json
{
  "mcpServers": {
    "roon": {
      "command": "ssh",
      "args": [
        "-o", "StrictHostKeyChecking=no",
        "admin@192.168.1.100",
        "docker", "exec", "-i", "roon-mcp", "rwav-bridge-mcp"
      ]
    }
  }
}
```

### Setup

```bash
# On QNAP: Start container
docker run -d --network host --name roon-mcp roon-mcp-qnap:latest

# On Mac: Setup SSH key authentication
ssh-copy-id admin@192.168.1.100

# Test connection
ssh admin@192.168.1.100 docker exec roon-mcp rwav-bridge-mcp --help
```

### Requirements

- SSH key authentication configured (no password prompts)
- Replace `admin@192.168.1.100` with your QNAP credentials

---

## Scenario C: Local MCP + Remote Bridge (Recommended)

Only RWAV Bridge runs in Docker on QNAP. MCP server runs locally on Mac and connects via HTTP.

```
┌─────────────────────────────┐            ┌─────────────────────────┐
│            Mac              │            │       QNAP NAS          │
│ ┌─────────┐   ┌───────────┐ │            │  ┌──────────────────┐  │
│ │MCP      │──►│Local RWAV │ │  HTTP      │  │ Docker Container │  │
│ │Client   │   │Bridge MCP │ │ ────────►  │  │ ┌──────────────┐ │  │
│ └─────────┘   └───────────┘ │  :3002     │  │ │RWAV Bridge   │ │  │
└─────────────────────────────┘            │  │ └──────┬───────┘ │  │
                                           │  └────────┼─────────┘  │
                                           │           │ Roon API   │
                                           │     ┌─────▼─────┐      │
                                           │     │ Roon Core │      │
                                           │     └───────────┘      │
                                           └─────────────────────────┘
```

### Configuration (Manual)

```json
{
  "mcpServers": {
    "roon": {
      "command": "rwav-bridge-mcp",
      "env": {
        "RWAV_BASE": "http://192.168.1.100:3002"
      }
    }
  }
}
```

### Configuration (Auto-Discovery) ✨ Recommended

Auto-discovery finds RWAV Bridge on your network automatically via mDNS/Bonjour:

```json
{
  "mcpServers": {
    "rwav": {
      "command": "rwav-bridge-mcp",
      "env": {
        "RWAV_BASE": "auto",
        "RWAV_DISCOVERY": "auto",
        "RWAV_TOOL_ALLOWLIST": "tools,history"
      }
    }
  }
}
```

#### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `RWAV_BASE` | `auto` | Auto-discover RWAV Bridge on network |
| `RWAV_DISCOVERY` | `auto` | Enable mDNS/Bonjour discovery |
| `RWAV_TOOL_ALLOWLIST` | `tools,history` | Limit available MCP tools (optional) |

### Setup

```bash
# On Mac: Install RWAV Bridge MCP locally
npm install -g @calibress/rwav-bridge-mcp
# Or via Homebrew:
brew install calibress/rwav/rwav-bridge-mcp

# On QNAP: Start container (Bridge runs on port 3002)
# Use Container Station UI or docker run

# Test discovery
RWAV_BASE=auto rwav-bridge-mcp --help
```

### Advantages

- ✅ Lowest latency (direct HTTP)
- ✅ No SSH dependency  
- ✅ Automatic network discovery
- ✅ Works with any MCP client

---

## Scenario D: No Docker (All Local)

Both RWAV Bridge and MCP server run locally on Mac. Best for development or when Roon Core is accessible from Mac.

```
┌─────────────────────────────────────┐
│               Mac                   │
│ ┌─────────┐   ┌─────────────────┐  │
│ │MCP      │──►│RWAV Bridge MCP  │  │
│ │Client   │   │+ RWAV Bridge    │  │
│ └─────────┘   └────────┬────────┘  │
└────────────────────────┼────────────┘
                         │ Roon API
                   ┌─────▼─────┐
                   │ Roon Core │
                   │(any host) │
                   └───────────┘
```

### Configuration

```json
{
  "mcpServers": {
    "roon": {
      "command": "rwav-bridge-mcp"
    }
  }
}
```

### Setup

```bash
# Install both via Homebrew
brew install calibress/rwav/rwav-bridge
brew install calibress/rwav/rwav-bridge-mcp

# Start Bridge (runs as background service)
# RWAV Bridge MCP will auto-discover it

# Test
rwav-bridge-mcp --help
```

---

## Configuration File Locations

| Client | Config File Path |
|--------|------------------|
| **Gemini CLI** | `~/.gemini/settings.json` |
| **Claude Desktop** | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| **BoltAI** | BoltAI Settings → MCP Servers |
| **Raycast** | Raycast Settings → Extensions → AI → MCP Servers |

---

## Quick Reference

| I want to... | Use Scenario |
|--------------|--------------|
| Test locally on Mac | A or D |
| Run on NAS, no local install | B |
| Best performance with NAS | C |
| Development without Docker | D |

---

## Troubleshooting

### "Connection refused" on :3002

- Check if container/Bridge is running
- Verify port 3002 is exposed
- Check firewall settings

### SSH tunnel hangs

- Verify SSH key authentication works: `ssh admin@NAS_IP echo test`
- Check Docker container is running: `ssh admin@NAS_IP docker ps`

### "rwav-bridge-mcp not found"

- Install via Homebrew: `brew install calibress/rwav/rwav-bridge-mcp`
- Check PATH includes Homebrew bin

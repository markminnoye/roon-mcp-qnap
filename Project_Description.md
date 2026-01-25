# roon-mcp-qnap

This project aims to create a **single Docker container** that hosts both **RWAV Bridge** and the **RWAV Bridge MCP server**, and deploy that container on a **QNAP TVS‑951X** NAS where **Roon Server QPKG** is already running as the Roon Core.

The goal is to control Roon via MCP from desktop AI clients such as **BoltAI**, **Claude Desktop**, and **Gemini CLI**.

---

## 1. Environment

- **NAS:** QNAP TVS‑951X (x86‑64), QTS 5.2.x, with **Container Station** available.  
- **Roon Core:** Official **Roon Server QPKG** installed and configured on the QNAP.  
- **Dev machine:** Apple Silicon Mac (48 GB RAM) using **VS Code** and **Antigravity**.  
- **LLM tools:** BoltAI, Claude Desktop, Gemini CLI (and Antigravity as the meta‑orchestrator).

Roon Core must remain as the QNAP app; we are not containerizing Roon itself.

---

## 2. Objectives

1. Build a **single Docker image** that:

   - Runs **RWAV Bridge** (Roon extension + HTTP API).
   - Runs the **RWAV Bridge MCP server** in the same container.
   - Connects to the existing Roon Core on the LAN.
   - Exposes an MCP server that can be used by BoltAI, Claude Desktop, and Gemini CLI.

2. Provide:

   - A clean **Git repo** with Dockerfile, entrypoint script, and optional `docker-compose.yml`.
   - Example **MCP configuration JSON** for:
     - BoltAI  
     - Claude Desktop  
     - Gemini CLI  
   - Documentation for deployment on QNAP and for local testing on the Mac.

3. Integrate with upstream:

   - The Docker build should pull RWAV Bridge and RWAV Bridge MCP from their **canonical repositories or packages**.
   - By default it should use the **latest stable** versions, but be easy to pin via build arguments or environment variables.

---

## 3. Architecture (Single Container)

### 3.1 Components

- **Roon Core (QPKG on QNAP)**  
  - Already running on the TVS‑951X.  
  - RWAV Bridge must discover and connect to this core over the LAN.

- **Combined “Roon MCP” Container**  
  - Base image: minimal x86‑64 Linux (e.g. Debian / Ubuntu slim).  
  - Contains:
    - RWAV Bridge (HTTP server, typically on port `3002`).  
    - RWAV Bridge MCP server (Node.js based, installed via npm or similar).
  - Internal wiring:
    - RWAV Bridge listens on `0.0.0.0:3002`.  
    - MCP server calls RWAV Bridge at `http://127.0.0.1:3002` (or `http://localhost:3002`).

- **MCP Clients (on Mac)**  
  - BoltAI  
  - Claude Desktop  
  - Gemini CLI  

All should connect to a single MCP server called `"roon"`.

### 3.2 Entrypoint and Processes

The container will use a single entrypoint script, for example `entrypoint.sh`, that:

1. Starts RWAV Bridge.  
2. Waits until port `3002` is reachable.  
3. Starts RWAV Bridge MCP server with environment variables such as:
   - `RWAV_BASE=http://127.0.0.1:3002`  
   - Or `RWAV_DISCOVERY=auto`, depending on RWAV recommendations.  

Both processes should log to stdout/stderr so they can be monitored easily.

### 3.3 External Interfaces

- RWAV Bridge’s HTTP port (`3002`) may or may not be published outside the container; the MCP server is the main interface for AI tools.  
- The MCP server must be exposed in a way that is compatible with MCP clients:
  - Either via **stdio** for local development (`docker run -it …`), or  
  - Via **TCP/HTTP** (e.g. a port on the NAS) for BoltAI, Claude Desktop, and Gemini CLI.  

The exact transport and port should be consistent across all client configuration examples.

---

## 4. Repository Structure

Create a Git repository (e.g. `roon-mcp-qnap`) with at least the following:

- `Dockerfile.roon-mcp`  
  - Installs OS dependencies (curl, ca‑certificates, Node.js if needed).  
  - Fetches and installs **RWAV Bridge** from its official download location.  
  - Fetches and installs **RWAV Bridge MCP server** from its official repo or package registry.  
  - Uses a mechanism that defaults to “latest stable” but allows version pinning (e.g. via `ARG BRIDGE_VERSION`, `ARG MCP_VERSION`).

- `entrypoint.sh`  
  - Starts RWAV Bridge.  
  - Waits until `localhost:3002` is responsive (simple loop).  
  - Starts RWAV MCP server, pointing to `http://127.0.0.1:3002`.  
  - Handles signals so that both processes shut down cleanly.

- `docker-compose.yml` (optional but useful)  
  - One service: `roon-mcp`.  
  - Builds from `Dockerfile.roon-mcp`.  
  - Defines environment variables:
    - Discovery vs `RWAV_BASE` (static URL for the bridge).  
    - Any additional RWAV/MCP options.  
  - Sets port mappings for MCP (and optionally for port 3002) as needed.

- `README.md`  
  - Overview and prerequisites.  
  - How to build and run locally (on the Mac).  
  - How to deploy on QNAP via Container Station or Docker CLI.  
  - Basic test procedures.

- `ARCHITECTURE.md`  
  - High‑level overview of Roon Core on QNAP, the combined container, and AI clients.  
  - Simple diagram or sequence description.

- `examples/`  
  - `examples/mcp-boltai.json`  
  - `examples/mcp-claude-desktop.json`  
  - `examples/mcp-gemini-cli.json`  

Each should define a `"roon"` MCP server pointing at this container, using the correct transport and endpoints for that client.

---

## 5. Integration with Upstream Repositories

Identify the **canonical sources**:

- RWAV Bridge  
- RWAV Bridge MCP server  

In the Dockerfile:

- Use installation commands that by default fetch the **latest stable** release (for example, `npm install -g rwav-bridge-mcp@latest` or a GitHub release URL).  
- Structure the Dockerfile with `ARG`s to allow explicit version pinning:

  - `ARG RWAV_BRIDGE_VERSION`  
  - `ARG RWAV_MCP_VERSION`  

Include in `README.md`:

- The upstream URLs.  
- How the current Dockerfile pulls the latest versions.  
- How to override/pin versions by setting build arguments.

---

## 6. Deployment Scenarios

Exact deployment tooling (CLI vs VS Code / Antigravity Docker integrations) can remain flexible, but document two main paths in `README.md`:

### 6.1 Local Build → Registry → QNAP

1. Build image on Mac:

   - `docker build -f Dockerfile.roon-mcp -t <your-registry>/roon-mcp-qnap:latest .`

2. Push to registry:

   - `docker push <your-registry>/roon-mcp-qnap:latest`

3. On QNAP (Container Station):

   - Pull the image.
   - Create a container/stack using that image.
   - Configure environment variables (e.g. `RWAV_BASE` with the QNAP IP if needed).
   - Run and check logs.

### 6.2 Build Directly on QNAP

1. Copy the repo or Dockerfile to the NAS.  
2. Use Docker CLI on QNAP to build:

   - `docker build -f Dockerfile.roon-mcp -t roon-mcp-qnap .`

3. Run via Container Station or CLI with appropriate environment variables and port mappings.

In both cases, document:

- Which ports on the NAS must be open for MCP clients.  
- How to confirm connectivity to Roon Core and RWAV Bridge via logs.

---

## 7. Client Configuration

Create clear examples for:

### 7.1 BoltAI

- JSON MCP config file (location and structure appropriate for BoltAI).  
- Defines a server named `"roon"` with fields like:
  - `name`, `description`
  - `transport` (e.g. `http` or `tcp` as required by MCP spec and BoltAI)
  - `host`/`port` if network‑based, or `command` if using stdio
  - optional `tools` / `resources` configuration if the client supports that

Provide:

- Where to save this config for BoltAI.  
- How to enable it in BoltAI.

### 7.2 Claude Desktop

- Similar JSON MCP config, adjusted to Claude Desktop’s expected structure and file location.  
- Again, define `"roon"` with the same endpoint details where possible.

### 7.3 Gemini CLI

- MCP configuration for Gemini CLI (JSON or YAML as required).  
- Shows how to define a `"roon"` MCP server pointing to the container.  
- Explain how to tell Gemini CLI to load this MCP config.  
- Include one or two example commands to test (e.g. list zones, inspect “now playing”).

All three examples should be conceptually aligned: same server name (`"roon"`), similar description, same host/port or command, differing only where the specific client requires a different wrapper or file path.

---

## 8. Testing and Troubleshooting

Add a testing section (in `README.md` or `TESTING.md`) that covers:

### 8.1 Inside the Container

- How to check RWAV Bridge logs to confirm it has discovered the Roon Core and lists zones.  
- How to check MCP server logs to confirm it can call RWAV Bridge successfully.

### 8.2 From Clients

- BoltAI:
  - Example prompt: “List Roon zones and show which one is currently active.”  
- Claude Desktop:
  - Same idea; verify that it uses MCP tools rather than hallucinating.  
- Gemini CLI:
  - Show how to directly call `"roon"` tools (e.g. “list zones” / “now playing”).

### 8.3 Troubleshooting Tips

- Roon Core not discovered:
  - Check Roon extension settings.  
  - Check network topology (NAS and container network mode).  
  - Disable or adjust firewalls as needed.

- MCP cannot talk to RWAV Bridge:
  - Verify `RWAV_BASE` or discovery settings.  
  - Confirm `localhost:3002` is reachable in the container.  

- QNAP‑specific issues:
  - Differences between host and bridge network modes.  
  - Port collisions on the NAS.  

---

## 9. Security

- Do not commit API keys or secrets to the repo.  
- Use environment variables or external secret stores where necessary.  
- The repo should be safe to publish publicly.

---

## 10. What the AI Assistant Should Do

Given this specification, the AI assistant (e.g. in Antigravity) should:

1. Refine the architecture where necessary while keeping the single‑container model.  
2. Implement:
   - `Dockerfile.roon-mcp`  
   - `entrypoint.sh`  
   - `docker-compose.yml` (optional)  
   - MCP client config examples for BoltAI, Claude Desktop, and Gemini CLI  
   - `README.md`, `ARCHITECTURE.md`, and test/troubleshooting docs

3. Wire the Docker build to the **canonical RWAV Bridge and RWAV Bridge MCP repositories** so that:
   - A rebuild pulls the latest stable versions by default.  
   - It’s easy to pin versions via build arguments or environment variables.

4. Provide clear, concrete examples of:
   - How to configure BoltAI, Claude Desktop, and Gemini CLI to use the `"roon"` MCP server.  
   - How to run quick end‑to‑end tests.


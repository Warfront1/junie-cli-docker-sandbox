# junie-cli-docker-sandbox

A secure way to run Junie CLI in a Docker Sandbox until official Docker support is added.

## Architecture

```mermaid
flowchart LR
    A[Junie CLI in Docker Sandbox] -->|proxychains| B[GOST Forward Proxy<br/>localhost:55432]
    B -->|proxies via| C[Docker Sandbox Proxy<br/>host.docker.internal:3128]
    C -->|connects to| D[JetBrains Servers<br/>junie.jetbrains.com/etc.]
    D -->|Response| C
    C -->|Response| B
    B -->|Response| A
```

## Prerequisites

1. **Docker Desktop 4.61 or later** with Docker Sandboxes enabled
2. **API Keys** for your preferred LLM provider(s):
   - `ANTHROPIC_API_KEY` - for Claude models
   - `OPENAI_API_KEY` - for GPT models
   - `GOOGLE_API_KEY` - for Gemini models
   - Or other supported providers

## Setup

### 1. Configure API Keys

Set your API keys in your shell configuration file:

```shell
# Add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_API_KEY=sk-ant-xxxxx
export OPENAI_API_KEY=sk-xxxxx
export GOOGLE_API_KEY=AIzaSyxxxxx
```

Apply the changes and restart Docker Desktop:

```shell
source ~/.bashrc  # or ~/.zshrc
```

> **Note:** Restart Docker Desktop so the daemon picks up the environment variables. The proxy reads credentials from your host environment and injects them into API requests automatically. Credentials are never stored inside the sandbox.

### 2. Build the Sandbox

```shell
docker build -t junie-cli-sandbox:v1 .
```

### 3. Run the Sandbox

```shell
# Navigate to the directory you wish to run Junie on
docker sandbox run -t junie-cli-sandbox:v1 --name junie-sandbox shell
```

### 4. Run Junie

```shell
docker sandbox exec junie-sandbox -- run-junie.sh
```

### Authentication Options

Inside the sandbox, you can authenticate using:

1. **JetBrains Account** - Log in with your JetBrains subscription
2. **JUNIE_API_KEY** - Usage-based billing (generate at junie.jetbrains.com/cli)
3. **Bring Your Own Key (BYOK)** - Use your own API keys from Anthropic, OpenAI, Google, etc.

## How It Works

The sandbox uses a multi-layer proxy approach:

1. **GOST Forward Proxy** - Runs inside the sandbox on `localhost:55432`
2. **Proxychains** - Forces Junie traffic through the local GOST proxy
3. **Docker Sandbox Proxy** - GOST forwards to the sandbox's built-in proxy at `host.docker.internal:3128`
4. **External Access** - The sandbox proxy connects to JetBrains servers

This approach bypasses the Docker sandbox network restrictions by routing all traffic through the sandbox's built-in proxy which already has proper certificate handling.

> **Why GOST + Proxychains?** Docker Sandboxes block direct connections to external IPs via network policies, and the `--allow-host`/`--bypass-host` options didn't work for JetBrains' dynamic cloud IPs. However, the sandbox's built-in proxy (`host.docker.internal:3128`) is designed to provide controlled outbound access. By routing Junie's traffic through GOST to this built-in proxy, we're using the intended outbound path rather than fighting the network restrictions.
>
> **How does this bypass the block?** The built-in proxy runs on the **host**, not inside the sandbox container. The sandbox network policy only restricts traffic originating from inside the container. When traffic goes through `host.docker.internal:3128`, the host makes the actual outbound connection on your behalf - and the host has full network access.
>
> ```
> ❌ Junie → direct to 34.54.111.18 → BLOCKED (container policy applies)
>
> ✅ Junie → GOST → host.docker.internal:3128 → 34.54.111.18 → ALLOWED (host makes the connection)
> ```

## JetBrains Endpoints

Junie connects to the following JetBrains endpoints. If you experience connectivity issues, check `docker sandbox network log` for blocked requests:

- `junie.jetbrains.com`
- `ingrazzio-cloud-prod.labs.jb.gg`
- `resources.jetbrains.com`
- `api.jetbrains.ai`

> **Note:** These domains may change. Use `docker sandbox network log` to discover blocked requests.

## Headless Mode (Non-interactive)

Run Junie CLI programmatically in CI/CD environments:

```shell
docker sandbox run -t junie-cli-sandbox:v1 --name junie-sandbox shell
docker sandbox exec junie-sandbox -- run-junie.sh --auth="$JUNIE_API_KEY" "Review and fix any code quality issues"
```

## Helpful Commands

### View Network Logs

Check for blocked requests:

```shell
docker sandbox network log
```

### View Junie Proxy Logs

Inside the sandbox:

```shell
cat /tmp/junie-proxy.log
cat /tmp/gost.log
```

### Cleanup ALL Sandboxes

```shell
docker sandbox reset
```

### Save as Custom Template

Save your configured sandbox as a reusable template:

```shell
docker sandbox save junie-sandbox my-junie-template:v1
```

## Resources

- [Junie CLI Documentation](https://junie.jetbrains.com/docs/junie-cli.html)
- [Docker Sandboxes Documentation](https://docs.docker.com/ai/sandbox-templates/)
- [Junie API Key](https://junie.jetbrains.com/cli)

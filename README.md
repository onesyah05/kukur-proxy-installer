# Kukur Gateway Installer

One-command installer for [Kukur Gateway](https://github.com/onesyah05/kukur) - AI Proxy for your local IDE.

## Quick Install

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/onesyah05/kukur-proxy-installer/main/install.ps1 | iex
```

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/onesyah05/kukur-proxy-installer/main/install.sh | bash
```

## Prerequisites

- **Node.js** v18+ ([nodejs.org](https://nodejs.org))
- **Git** ([git-scm.com](https://git-scm.com))
- **GitHub access** to the Kukur repository (ask admin for collaborator access)

## What it does

1. Checks prerequisites (Node.js, npm, Git)
2. Clones the Kukur Gateway repository
3. Installs dependencies
4. Sets up Python and Camoufox (for browser automation)
5. Configures environment and database
6. Creates the `kukur` CLI command

## After Installation

```
kukur start          # Start the gateway
kukur status         # Check if running
kukur update         # Update to latest
kukur reset-password # Reset admin password
```

## Default Login

- Email: `admin@unigateway.ai`
- Password: `password123`

> **Change this after first login!**

#!/usr/bin/env pwsh
# Kukur Gateway - Windows Installer
# Usage: irm https://raw.githubusercontent.com/onesyah05/kukur-proxy-installer/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$KUKUR_DIR = "$env:USERPROFILE\.kukur"
$REPO_URL = "https://github.com/onesyah05/kukur.git"

function Write-Step($msg) { Write-Host "`n[Kukur] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-OK($msg) { Write-Host "  ✓ " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Err($msg) { Write-Host "  ✗ " -ForegroundColor Red -NoNewline; Write-Host $msg }
function Write-Info($msg) { Write-Host "  → " -ForegroundColor DarkGray -NoNewline; Write-Host $msg }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     Kukur Gateway Installer v1.0     ║" -ForegroundColor Cyan
Write-Host "  ║     AI Proxy for your local IDE      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── 1. Check Prerequisites ───────────────────────────────────────────

Write-Step "Checking prerequisites..."

# Node.js
$nodeVersion = $null
try {
    $nodeVersion = (node --version 2>$null)
} catch {}

if (-not $nodeVersion) {
    Write-Err "Node.js not found!"
    Write-Host "    Install from: https://nodejs.org (v18 or higher)" -ForegroundColor Yellow
    Write-Host "    Or run: winget install OpenJS.NodeJS.LTS" -ForegroundColor Yellow
    exit 1
}

$nodeMajor = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
if ($nodeMajor -lt 18) {
    Write-Err "Node.js $nodeVersion is too old (need v18+)"
    Write-Host "    Update from: https://nodejs.org" -ForegroundColor Yellow
    exit 1
}
Write-OK "Node.js $nodeVersion"

# npm
$npmVersion = $null
try { $npmVersion = (npm --version 2>$null) } catch {}
if (-not $npmVersion) {
    Write-Err "npm not found! It should come with Node.js."
    exit 1
}
Write-OK "npm v$npmVersion"

# Git
$gitVersion = $null
try { $gitVersion = (git --version 2>$null) } catch {}
if (-not $gitVersion) {
    Write-Err "Git not found!"
    Write-Host "    Install from: https://git-scm.com" -ForegroundColor Yellow
    Write-Host "    Or run: winget install Git.Git" -ForegroundColor Yellow
    exit 1
}
Write-OK "$gitVersion"

# ─── 2. Clone or Update Repository ───────────────────────────────────

Write-Step "Setting up Kukur..."

if (Test-Path "$KUKUR_DIR\.git") {
    Write-Info "Existing installation found, updating..."
    Push-Location $KUKUR_DIR
    git pull --ff-only 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to update. Try: kukur update --force"
        Pop-Location
        exit 1
    }
    Pop-Location
    Write-OK "Updated to latest version"
} else {
    Write-Info "Cloning from GitHub (requires access)..."
    
    if (Test-Path $KUKUR_DIR) {
        Remove-Item -Recurse -Force $KUKUR_DIR
    }

    git clone $REPO_URL $KUKUR_DIR 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Clone failed! You may not have access to this repository."
        Write-Host ""
        Write-Host "    To get access, ask the admin to add your GitHub account" -ForegroundColor Yellow
        Write-Host "    as a collaborator at: $REPO_URL" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "    Make sure you're authenticated with GitHub:" -ForegroundColor Yellow
        Write-Host "    → gh auth login  (GitHub CLI)" -ForegroundColor Yellow
        Write-Host "    → Or add SSH key to your GitHub account" -ForegroundColor Yellow
        exit 1
    }
    Write-OK "Repository cloned"
}

# ─── 3. Install Dependencies ─────────────────────────────────────────

Write-Step "Installing dependencies..."
Push-Location $KUKUR_DIR
npm install --silent 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "npm install failed"
    Pop-Location
    exit 1
}
Write-OK "Dependencies installed"

# ─── 3b. Install 9router ─────────────────────────────────────────────

Write-Step "Checking 9router..."

$nineRouterVersion = $null
try { $nineRouterVersion = (npx 9router --version 2>$null) } catch {}

if (-not $nineRouterVersion) {
    Write-Info "9router not found, installing globally..."
    npm install -g 9router 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-OK "9router installed globally"
    } else {
        Write-Err "Failed to install 9router"
        Write-Host "    Run manually: npm install -g 9router" -ForegroundColor Yellow
    }
} else {
    Write-OK "9router $nineRouterVersion"
}

# ─── 3c. Check & Install Python ──────────────────────────────────────

Write-Step "Checking Python..."

$pythonCmd = $null
try { 
    $pyVer = python --version 2>$null
    if ($pyVer) { $pythonCmd = "python" }
} catch {}

if (-not $pythonCmd) {
    try {
        $pyVer = python3 --version 2>$null
        if ($pyVer) { $pythonCmd = "python3" }
    } catch {}
}

if (-not $pythonCmd) {
    Write-Info "Python not found, installing..."
    winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0) {
        # Refresh PATH for current session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $pythonCmd = "python"
        Write-OK "Python installed via winget"
    } else {
        Write-Err "Failed to install Python automatically"
        Write-Host "    Install manually from: https://www.python.org/downloads/" -ForegroundColor Yellow
        Write-Host "    Or run: winget install Python.Python.3.12" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-OK "$pyVer"
}

# ─── 3d. Install Camoufox ────────────────────────────────────────────

Write-Step "Checking Camoufox..."

$camoufoxFound = $false
$localAppData = $env:LOCALAPPDATA
$camoufoxPaths = @(
    "$localAppData\camoufox\camoufox\Cache\camoufox.exe",
    "$localAppData\camoufox\camoufox.exe",
    "$env:USERPROFILE\camoufox\camoufox.exe"
)

foreach ($p in $camoufoxPaths) {
    if (Test-Path $p) {
        $camoufoxFound = $true
        Write-OK "Camoufox found at: $p"
        break
    }
}

if (-not $camoufoxFound) {
    Write-Info "Camoufox not found, installing via pip..."
    
    & $pythonCmd -m pip install -U camoufox 2>$null
    if ($LASTEXITCODE -eq 0) {
        & $pythonCmd -m camoufox fetch 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Camoufox installed and browser fetched"
        } else {
            Write-Info "Camoufox package installed but browser fetch failed"
            Write-Host "    Run manually: $pythonCmd -m camoufox fetch" -ForegroundColor Yellow
        }
    } else {
        Write-Err "Failed to install Camoufox"
        Write-Host "    Run manually: $pythonCmd -m pip install -U camoufox" -ForegroundColor Yellow
        Write-Host "    Then: $pythonCmd -m camoufox fetch" -ForegroundColor Yellow
    }
}

# ─── 4. Setup Environment ────────────────────────────────────────────

Write-Step "Configuring environment..."

$envFile = "$KUKUR_DIR\.env"
if (-not (Test-Path $envFile)) {
    # Generate random AUTH_SECRET
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $secret = [Convert]::ToBase64String($bytes)
    
    @"
# Kukur Gateway Configuration (auto-generated)
AUTH_SECRET="$secret"
"@ | Set-Content $envFile -Encoding UTF8

    Write-OK "Environment configured (.env created)"
} else {
    Write-OK "Environment already configured"
}

# ─── 5. Setup Database ───────────────────────────────────────────────

Write-Step "Setting up database..."
npx prisma generate --quiet 2>$null
npx prisma db push --accept-data-loss --skip-generate 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Database setup failed"
    Pop-Location
    exit 1
}
Write-OK "Database ready (SQLite)"

# Seed default admin user
npx tsx prisma/seed.ts 2>$null
Write-OK "Default admin user created"

# ─── 6. Create CLI Command ───────────────────────────────────────────

Write-Step "Creating kukur command..."

$binDir = "$env:USERPROFILE\.kukur\bin"
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }

# Copy the CLI script
Copy-Item "$KUKUR_DIR\bin\kukur.ps1" "$binDir\kukur.ps1" -Force 2>$null

# Create batch wrapper for cmd.exe compatibility
@"
@echo off
powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.kukur\bin\kukur.ps1" %*
"@ | Set-Content "$binDir\kukur.cmd" -Encoding ASCII

# Add to PATH if not already there
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binDir", "User")
    $env:Path = "$env:Path;$binDir"
    Write-OK "Added kukur to PATH"
} else {
    Write-OK "kukur already in PATH"
}

Pop-Location

# ─── 7. Done! ────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║        Installation Complete!         ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Quick Start:" -ForegroundColor White
Write-Host "    kukur start          " -NoNewline -ForegroundColor Cyan; Write-Host "Start the gateway"
Write-Host "    kukur status         " -NoNewline -ForegroundColor Cyan; Write-Host "Check if running"
Write-Host "    kukur update         " -NoNewline -ForegroundColor Cyan; Write-Host "Update to latest"
Write-Host "    kukur reset-password " -NoNewline -ForegroundColor Cyan; Write-Host "Reset admin password"
Write-Host ""
Write-Host "  Default Login:" -ForegroundColor White
Write-Host "    Email:    admin@unigateway.ai" -ForegroundColor DarkGray
Write-Host "    Password: password123" -ForegroundColor DarkGray
Write-Host "    (Change this after first login!)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  NOTE: Restart your terminal for 'kukur' command to work." -ForegroundColor Yellow
Write-Host ""

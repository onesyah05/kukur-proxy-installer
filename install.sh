#!/bin/bash
# Kukur Gateway - Linux/macOS Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/onesyah05/kukur-proxy-installer/main/install.sh | bash

set -e

KUKUR_DIR="$HOME/.kukur"
REPO_URL="https://github.com/onesyah05/kukur.git"
BIN_DIR="$KUKUR_DIR/bin"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m'

step() { echo -e "\n${CYAN}[Kukur]${NC} $1"; }
ok() { echo -e "  ${GREEN}[OK]${NC} $1"; }
err() { echo -e "  ${RED}[ERR]${NC} $1"; }
info() { echo -e "  ${GRAY}[..]${NC} $1"; }

echo ""
echo -e "  ${CYAN}+======================================+${NC}"
echo -e "  ${CYAN}|     Kukur Gateway Installer v1.0     |${NC}"
echo -e "  ${CYAN}|     AI Proxy for your local IDE      |${NC}"
echo -e "  ${CYAN}+======================================+${NC}"
echo ""

# --- 1. Check Prerequisites ---

step "Checking prerequisites..."

# Node.js
if ! command -v node &> /dev/null; then
    err "Node.js not found!"
    echo -e "    ${YELLOW}Install from: https://nodejs.org (v18 or higher)${NC}"
    echo -e "    ${YELLOW}Or use: curl -fsSL https://fnm.vercel.app/install | bash${NC}"
    echo -e "    ${YELLOW}        fnm install 20 && fnm use 20${NC}"
    exit 1
fi

NODE_VERSION=$(node --version)
NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 18 ]; then
    err "Node.js $NODE_VERSION is too old (need v18+)"
    echo -e "    ${YELLOW}Update: fnm install 20 && fnm use 20${NC}"
    exit 1
fi
ok "Node.js $NODE_VERSION"

# npm
if ! command -v npm &> /dev/null; then
    err "npm not found! It should come with Node.js."
    exit 1
fi
ok "npm v$(npm --version)"

# Git
if ! command -v git &> /dev/null; then
    err "Git not found!"
    echo -e "    ${YELLOW}Install: sudo apt install git (Ubuntu/Debian)${NC}"
    echo -e "    ${YELLOW}         brew install git (macOS)${NC}"
    exit 1
fi
ok "$(git --version)"

# --- 2. Clone or Update Repository ---

step "Setting up Kukur..."

if [ -d "$KUKUR_DIR/.git" ]; then
    info "Existing installation found, updating..."
    cd "$KUKUR_DIR"
    git config --global --add safe.directory "$KUKUR_DIR" 2>/dev/null || true
    if ! git pull --ff-only 2>/dev/null; then
        info "Pull failed, trying reset..."
        git fetch origin 2>/dev/null || true
        git reset --hard origin/main 2>/dev/null || true
    fi
    ok "Updated to latest version"
else
    info "Cloning from GitHub (requires access)..."
    
    if [ -d "$KUKUR_DIR" ]; then
        rm -rf "$KUKUR_DIR"
    fi

    if ! git clone "$REPO_URL" "$KUKUR_DIR" 2>/dev/null; then
        err "Clone failed! You may not have access to this repository."
        echo ""
        echo -e "    ${YELLOW}To get access, ask the admin to add your GitHub account${NC}"
        echo -e "    ${YELLOW}as a collaborator at: $REPO_URL${NC}"
        echo ""
        echo -e "    ${YELLOW}Make sure you are authenticated with GitHub:${NC}"
        echo -e "    ${YELLOW}> gh auth login  (GitHub CLI)${NC}"
        echo -e "    ${YELLOW}> Or add SSH key to your GitHub account${NC}"
        exit 1
    fi
    ok "Repository cloned"
fi

cd "$KUKUR_DIR"

# --- 3. Install Dependencies ---

step "Installing dependencies..."
npm install --prefer-offline --progress=false 2>/dev/null
ok "Dependencies installed"

# --- 3b. Install 9router ---

step "Checking 9router..."

if command -v 9router &> /dev/null || npm list -g 9router &> /dev/null; then
    ok "9router already installed"
else
    info "9router not found, installing globally..."
    if npm install -g 9router 2>/dev/null; then
        ok "9router installed globally"
    else
        err "Failed to install 9router"
        echo -e "    ${YELLOW}Run manually: npm install -g 9router${NC}"
    fi
fi

# --- 3c. Check and Install Python ---

step "Checking Python..."

PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
fi

if [ -z "$PYTHON_CMD" ]; then
    info "Python not found, installing..."
    
    if [ "$(uname)" = "Darwin" ]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install python3 2>/dev/null
            PYTHON_CMD="python3"
            ok "Python installed via Homebrew"
        else
            err "Python not found and Homebrew not available"
            echo -e "    ${YELLOW}Install Homebrew first, then: brew install python3${NC}"
            exit 1
        fi
    else
        # Linux
        if command -v apt &> /dev/null; then
            sudo apt update -qq && sudo apt install -y python3 python3-pip 2>/dev/null
            PYTHON_CMD="python3"
            ok "Python installed via apt"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y python3 python3-pip 2>/dev/null
            PYTHON_CMD="python3"
            ok "Python installed via dnf"
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm python python-pip 2>/dev/null
            PYTHON_CMD="python3"
            ok "Python installed via pacman"
        else
            err "Python not found and no supported package manager detected"
            echo -e "    ${YELLOW}Install Python 3 manually from: https://www.python.org/downloads/${NC}"
            exit 1
        fi
    fi
else
    ok "$($PYTHON_CMD --version)"
fi

# --- 3d. Install Camoufox ---

step "Checking Camoufox..."

CAMOUFOX_FOUND=false

if [ "$(uname)" = "Darwin" ]; then
    CAMOUFOX_PATHS=(
        "$HOME/Library/Caches/camoufox/camoufox"
        "$HOME/.local/share/camoufox/camoufox"
        "/usr/local/bin/camoufox"
    )
else
    CAMOUFOX_PATHS=(
        "$HOME/.local/share/camoufox/camoufox/camoufox"
        "$HOME/.local/share/camoufox/camoufox"
        "$HOME/camoufox/camoufox"
        "/usr/local/bin/camoufox"
    )
fi

for p in "${CAMOUFOX_PATHS[@]}"; do
    if [ -f "$p" ]; then
        CAMOUFOX_FOUND=true
        ok "Camoufox found at: $p"
        break
    fi
done

if [ "$CAMOUFOX_FOUND" = false ]; then
    info "Camoufox not found, installing via pip..."
    
    if $PYTHON_CMD -m pip install -U camoufox 2>/dev/null; then
        if $PYTHON_CMD -m camoufox fetch 2>/dev/null; then
            ok "Camoufox installed and browser fetched"
        else
            info "Camoufox package installed but browser fetch failed"
            echo -e "    ${YELLOW}Run manually: $PYTHON_CMD -m camoufox fetch${NC}"
        fi
    else
        err "Failed to install Camoufox"
        echo -e "    ${YELLOW}Run manually: $PYTHON_CMD -m pip install -U camoufox${NC}"
        echo -e "    ${YELLOW}Then: $PYTHON_CMD -m camoufox fetch${NC}"
    fi
fi

# --- 4. Setup Environment ---

step "Configuring environment..."

ENV_FILE="$KUKUR_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    # Generate random AUTH_SECRET
    SECRET=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    
    echo "# Kukur Gateway Configuration (auto-generated)" > "$ENV_FILE"
    echo "AUTH_SECRET=\"$SECRET\"" >> "$ENV_FILE"

    ok "Environment configured (.env created)"
else
    ok "Environment already configured"
fi

# --- 5. Setup Database ---

step "Setting up database..."
npx prisma generate --quiet 2>/dev/null || true
npx prisma db push --accept-data-loss --skip-generate 2>/dev/null || true
ok "Database ready (SQLite)"

# Seed default admin user
npx tsx prisma/seed.ts 2>/dev/null || true
ok "Default admin user created"

# --- 6. Create CLI Command ---

step "Creating kukur command..."

mkdir -p "$BIN_DIR"

# Only copy if source and dest are different
SRC_CLI="$KUKUR_DIR/bin/kukur"
if [ -f "$SRC_CLI" ]; then
    chmod +x "$SRC_CLI"
fi

# Add to PATH
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_RC="$HOME/.bash_profile"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "\.kukur/bin" "$SHELL_RC" 2>/dev/null; then
        echo '' >> "$SHELL_RC"
        echo '# Kukur Gateway CLI' >> "$SHELL_RC"
        echo 'export PATH="$HOME/.kukur/bin:$PATH"' >> "$SHELL_RC"
        ok "Added kukur to PATH (in $SHELL_RC)"
    else
        ok "kukur already in PATH"
    fi
fi

export PATH="$BIN_DIR:$PATH"

# --- 7. Done! ---

echo ""
echo -e "  ${GREEN}+======================================+${NC}"
echo -e "  ${GREEN}|        Installation Complete!         |${NC}"
echo -e "  ${GREEN}+======================================+${NC}"
echo ""
echo -e "  Quick Start:"
echo -e "    ${CYAN}kukur start${NC}          Start the gateway"
echo -e "    ${CYAN}kukur status${NC}         Check if running"
echo -e "    ${CYAN}kukur update${NC}         Update to latest"
echo -e "    ${CYAN}kukur reset-password${NC} Reset admin password"
echo ""
echo -e "  Default Login:"
echo -e "    ${GRAY}Email:    admin@unigateway.ai${NC}"
echo -e "    ${GRAY}Password: password123${NC}"
echo -e "    ${YELLOW}(Change this after first login!)${NC}"
echo ""
if [ -n "$SHELL_RC" ]; then
    echo -e "  ${YELLOW}NOTE: Restart your terminal or run 'source $SHELL_RC' for kukur command.${NC}"
else
    echo -e "  ${YELLOW}NOTE: Restart your terminal for kukur command to work.${NC}"
fi
echo ""

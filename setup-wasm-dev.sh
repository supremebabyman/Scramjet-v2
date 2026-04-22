#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo " WASM DEV ENV SETUP (ROBUST) "
echo "=============================="

OS="$(uname -s)"
ARCH="$(uname -m)"

echo "Detected OS: $OS ($ARCH)"

#######################################
# Helper functions
#######################################
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

append_to_shell_rc() {
  local LINE="$1"
  if ! grep -qxF "$LINE" "$HOME/.bashrc" 2>/dev/null; then
    echo "$LINE" >> "$HOME/.bashrc"
  fi
}

#######################################
# Install base dependencies
#######################################
echo "=== Checking base dependencies ==="

if [[ "$OS" == "Linux" ]]; then
  if command_exists apt; then
    sudo apt update
    sudo apt install -y build-essential curl git cmake pkg-config clang
  elif command_exists pacman; then
    sudo pacman -Sy --needed base-devel git curl cmake clang
  fi
elif [[ "$OS" == "Darwin" ]]; then
  if ! command_exists brew; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install git cmake llvm
fi

#######################################
# NVM + Node
#######################################
echo "=== Installing Node.js (via nvm) ==="

if [ ! -d "$HOME/.nvm" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="/usr/local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
./setup-wasm-dev.sh: line 57: /home/codespace/.nvm/nvm.sh: No such file or directory


if ! command_exists node; then
  nvm install node
fi

nvm use node

#######################################
# pnpm
#######################################
echo "=== Installing pnpm ==="
if ! command_exists pnpm; then
  npm install -g pnpm
fi

#######################################
# Rust
#######################################
echo "=== Installing Rust (rustup) ==="

if ! command_exists rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

source "$HOME/.cargo/env"

rustup update
rustup target add wasm32-unknown-unknown

#######################################
# Cargo useful tools
#######################################
echo "=== Installing Rust WASM tools ==="

cargo install wasm-bindgen-cli --locked || true
cargo install wasm-pack --locked || true
cargo install cargo-generate --locked || true

#######################################
# Binaryen (wasm-opt)
#######################################
echo "=== Installing Binaryen ==="

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

if ! command_exists wasm-opt; then
  if [ ! -d "$HOME/binaryen" ]; then
    git clone https://github.com/WebAssembly/binaryen.git "$HOME/binaryen"
  fi

  cd "$HOME/binaryen"
  git pull || true

  mkdir -p build
  cd build

  cmake .. -DCMAKE_BUILD_TYPE=Release
  cmake --build . -- -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)

  cp bin/wasm-opt "$BIN_DIR/" || true
  cd ~
fi

append_to_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'
export PATH="$HOME/binaryen/build/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/binaryen/build/lib:$LD_LIBRARY_PATH"

#######################################
# wasm-snip (fork)
#######################################
echo "=== Installing wasm-snip (fork) ==="

if ! command_exists wasm-snip; then
  if [ ! -d "$HOME/wasm-snip" ]; then
    git clone https://github.com/r58Playz/wasm-snip.git "$HOME/wasm-snip"
  fi

  cd "$HOME/wasm-snip"
  git pull || true
  cargo install --path . --force
  cd ~
fi

#######################################
# Extra useful WASM tools
#######################################
echo "=== Installing extra WASM tools ==="

cargo install twiggy --locked || true
cargo install wasm-tools --locked || true

#######################################
# Verification
#######################################
echo ""
echo "=========== VERIFY ==========="

check() {
  printf "%-20s" "$1"
  if command_exists "$2"; then
    echo "OK ($($2 --version 2>/dev/null | head -n1))"
  else
    echo "MISSING"
  fi
}

check "node" node
check "pnpm" pnpm
check "rustc" rustc
check "cargo" cargo
check "wasm-bindgen" wasm-bindgen
check "wasm-pack" wasm-pack
check "wasm-opt" wasm-opt
check "wasm-snip" wasm-snip
check "twiggy" twiggy

echo "=============================="
echo " Setup complete."
echo " Restart your terminal if needed."
echo "=============================="
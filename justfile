install-dependencies:
    #!/bin/bash
    set -e

    # Source distro info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "Cannot detect OS."
        exit 1
    fi

    echo "Detected distro: ID=$ID, ID_LIKE=$ID_LIKE"

    # Normalize variables (in case ID_LIKE is a space-separated list)
    DISTRO="$ID $ID_LIKE"

    if echo "$DISTRO" | grep -qE 'debian|ubuntu'; then
        echo "Installing debian/ubuntu dependencies with apt..."
        sudo apt update && sudo apt install -y \
          build-essential \
          cargo \
          cmake \
           libxkbcommon-dev libudev1 libinput10 libcap2 libmtdev1 libevdev2 libwacom9 libgudev-1.0-0 \
           libglib2.0-dev libffi8 libpcre2-dev libxkbcommon-x11-dev libxcb-dev libxcb-xkb-dev libxau-dev \ 
           libstdc++-dev libx11-dev libxfixes-dev libegl-dev libgbm-dev libfontconfig1-dev libgl-dev \
           libdrm-dev libexpat1-dev libfreetype6-dev libxml2-dev zlib1g-dev libbz2-dev libpng-dev \ 
           libharfbuzz-dev libbrotli-dev liblzma-dev libraphite2-dev

    elif echo "$DISTRO" | grep -qE 'fedora'; then
        echo "Installing fedora dependencies with dnf..."
          # Install development tools group
          sudo dnf group install -y development-tools \
          # Install individual packages grouped by functionality
          sudo dnf install -y \
            cargo cmake \
            libxkbcommon-devel systemd-devel libinput-devel libcap-devel mtdev-devel libevdev-devel glib2-devel \
            libffi-devel pcre2-devel libxkbcommon-x11-devel libxcb-devel libXau-devel libstdc++-devel libx11-devel libxfixes-devel \
            mesa-libEGL-devel mesa-libgbm-devel fontconfig-devel libdrm-devel expat-devel freetype-devel libxml2-devel zlib-devel \
            bzip2-devel libpng-devel harfbuzz-devel brotli-devel xz-devel graphite2-devel

    elif echo "$DISTRO" | grep -q 'arch'; then
        echo "Installing arch dependencies with pacman..."
        sudo pacman -Sy --noconfirm \
          cargo \ 
          cmake \
          sudo pacman -Syu --needed \
          libxkbcommon systemd libinput libcap mtdev libevdev libwacom glib2 libffi pcre2 libxkbcommon-x11 \
          libxcb libxau libx11 libxfixes mesa fontconfig libdrm expat freetype2 libxml2 zlib bzip2 \ 
          libpng harfbuzz brotli xz graphite
    else
        echo "Unsupported distro: $ID"
        exit 1
    fi

# Build all crates with optional arguments
cargo-build-all *ARGS:
    #!/usr/bin/env bash
    shopt -s globstar
    CRATE_DIRS=()
    for dir in **/; do
        if [[ -f "$dir/Cargo.toml" ]]; then
            CRATE_DIRS+=("$dir")
        fi
    done

    for dir in "${CRATE_DIRS[@]}"; do
        echo "Building crate in $dir"
        (cd "$dir" && cargo build {{ ARGS }})
    done

    echo "Successfully built ${#CRATE_DIRS[@]} crates"


# install all repos into prefix folder
cargo-install-repos:
    #!/usr/bin/env bash
    PREFIX_DIR="./prefix"
    mkdir -p "$PREFIX_DIR"

    # Recursively find all Rust crates (must have both Cargo.toml AND src/)
    shopt -s globstar
    REPO_DIRS=()
    for dir in **/; do
        if [[ -f "$dir/Cargo.toml" && -d "$dir/src" ]]; then
            REPO_DIRS+=("$dir")
        fi
    done

    # Install all collected crates
    for dir in "${REPO_DIRS[@]}"; do
        echo "Installing from $dir to $PREFIX_DIR"
        cargo install --path "$dir" --root "$PREFIX_DIR" --bins --locked --force
    done

    echo "Successfully processed ${#REPO_DIRS[@]} crates"

        if [[ -d "$entry" ]]; then
            echo "$(basename "$entry")"
        fi
    done

# Install an XR environment
atmosphere-manual-installation:
  echo "Insert location of an env.kdl file:"
  read -r XR_ENV_LOCATION
  ./atmosphere/target/debug/atmosphere install XR_ENV_LOCATION

run-stardust-xr:
    ./server/target/debug/stardust-xr-server -e startup.sh

# Create a new client from template
new-client:
    #!/usr/bin/env bash
    echo "Enter new client name:"
    read -r CLIENT_NAME
    
    # Copy template
    if [ ! -d "client-template" ]; then
        echo "Error: client-template directory not found!"
        exit 1
    fi
    
    cp -r client-template "$CLIENT_NAME"
    
    # Rename crate in Cargo.toml
    sed -i "s/^name = \".*\"/name = \"$CLIENT_NAME\"/" "$CLIENT_NAME/Cargo.toml"
    
    # Install the client
    echo "Installing new client..."
    cargo install --path "$CLIENT_NAME" --root ./prefix --bins --locked --force
    echo "Client '$CLIENT_NAME' created and installed!"

# Update an existing client
cargo-reinstall-client:
    #!/usr/bin/env bash
    echo "Enter client name to update:"
    read -r CLIENT_NAME
    
    shopt -s globstar
    FOUND_DIR=""
    for dir in **/; do
        if [[ -f "$dir/Cargo.toml" && -d "$dir/src" ]]; then
            # Check for matching binary files
            if [[ -f "$dir/src/bin/$CLIENT_NAME.rs" || 
                  ( -f "$dir/src/main.rs" && $(grep -oP '^name = "\K[^"]+' "$dir/Cargo.toml") == "$CLIENT_NAME" ) ]]; then
                FOUND_DIR="$dir"
                break
            fi
        fi
    done

    if [[ -z "$FOUND_DIR" ]]; then
        echo "Error: Client '$CLIENT_NAME' not found!"
        echo "Searched for:"
        echo "1. src/bin/$CLIENT_NAME.rs"
        echo "2. crates named '$CLIENT_NAME' with src/main.rs"
        exit 1
    fi
    
    echo "Found client at: $FOUND_DIR"
    echo "Updating client '$CLIENT_NAME'..."
    cargo install --path "$FOUND_DIR" --root ./prefix --bins --locked --force
    echo "Successfully updated client '$CLIENT_NAME'"

# Run a client by name (searches recursively)
run CLIENT_NAME:
    #!/usr/bin/env bash
    FOUND=0
    
    # Use process substitution to maintain shell context
    while IFS= read -r -d $'\0' dir; do
        if [[ -f "$dir/Cargo.toml" && -f "$dir/src/main.rs" ]]; then
            echo "Running client in: $dir"
            (cd "$dir" && cargo run)
            FOUND=1
        fi
    done < <(find . -type d -name "{{CLIENT_NAME}}" -print0)

    if [[ $FOUND -eq 0 ]]; then
        echo "Error: No client named '{{CLIENT_NAME}}' with src/main.rs found"
        exit 1
    fi

# Add client executables from target/debug to startup.sh (ignores files with extensions)
add-clients *CLIENTS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if clients were provided as arguments
    if [ $# -eq 0 ]; then
        echo "Enter client names (space separated):"
        read -a CLIENTS
    fi
    
    # Ensure startup.sh exists
    touch startup.sh
    
    # Search for ELFs in target/debug folders
    for client in "${CLIENTS[@]}"; do
        echo "Searching for client executable: $client"
        
        found=false
        shopt -s globstar
        for elf in **/target/debug/*; do
            # Skip directories, files with extensions, and non-ELF files
            [[ ! -f "$elf" ]] && continue
            [[ "$elf" == *.* ]] && continue
            
            # Get just the executable name (without path)
            elf_name=$(basename "$elf")
            
            # Check if executable name matches client (case insensitive)
            if [[ "${elf_name,,}" == *"${client,,}"* ]]; then
                found=true
                # Get relative path to ELF
                elf_path="./$(realpath --relative-to=. "$elf")"
                
                # Add to startup.sh if not already present
                if ! grep -qF "$elf_path &" startup.sh; then
                    echo "$elf_path &" >> startup.sh
                    echo "Added: $elf_path &"
                else
                    echo "Already exists: $elf_path &"
                fi
            fi
        done
        
        if [ "$found" = false ]; then
            echo "Warning: No ELF executable found matching '$client' in any target/debug folder"
        fi
    done
    
    echo "Updated startup.sh with clients: ${CLIENTS[@]}"

# Remove clients from startup.sh
remove-clients *CLIENTS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Check if clients were provided as arguments
    if [ $# -eq 0 ]; then
        echo "Enter client names to remove (space separated):"
        read -a CLIENTS
    fi
    
    # Check if startup.sh exists
    if [ ! -f startup.sh ]; then
        echo "Error: startup.sh not found"
        exit 1
    fi
    
    # Create temporary file
    temp_file=$(mktemp)
    
    # Process each line in startup.sh
    while IFS= read -r line; do
        keep_line=true
        for client in "${CLIENTS[@]}"; do
            # Check if line contains the client name (case insensitive)
            if [[ "${line,,}" == *"${client,,}"* ]]; then
                keep_line=false
                echo "Removed: $line"
                break
            fi
        done
        $keep_line && echo "$line" >> "$temp_file"
    done < startup.sh
    
    # Replace original file
    mv "$temp_file" startup.sh
    
    echo "Removed clients: ${CLIENTS[@]}"

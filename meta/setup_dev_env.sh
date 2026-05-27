#!/bin/bash
set -euo pipefail

# === Config ===
GIT_NAME="yichuan-w"
GIT_EMAIL="yichuan_wang@berkeley.edu"
SSH_KEY="$HOME/.ssh/id_ed25519_github"
ZSH_PLUGINS=(
    "https://github.com/zsh-users/zsh-autosuggestions.git"
    "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    "https://github.com/marlonrichert/zsh-autocomplete.git"
)

info()  { echo -e "\033[1;32m[✓]\033[0m $1"; }
warn()  { echo -e "\033[1;33m[!]\033[0m $1"; }
step()  { echo -e "\n\033[1;34m=== $1 ===\033[0m"; }

# === Proxy ===
setup_proxy() {
    step "Configuring proxy"
    if command -v fwdproxy-config &>/dev/null; then
        local cert="/var/facebook/credentials/$(whoami)/x509/$(whoami).pem"
        if [[ -f "$cert" ]]; then
            # Only proxy github.com — avoid breaking internal git (mononoke, etc.)
            git config --global http.https://github.com.proxy https://fwdproxy:8082
            git config --global http.https://github.com.proxySSLCert "$cert"
            git config --global http.https://github.com.proxySSLKey "$cert"
            git config --global http.https://raw.githubusercontent.com.proxy https://fwdproxy:8082
            git config --global http.https://raw.githubusercontent.com.proxySSLCert "$cert"
            git config --global http.https://raw.githubusercontent.com.proxySSLKey "$cert"
            CURL_PROXY="$(fwdproxy-config curl 2>/dev/null)"
            info "Forward proxy configured (github.com only)"
        else
            warn "Proxy cert not found at $cert, skipping proxy"
            CURL_PROXY=""
        fi
    else
        CURL_PROXY=""
        info "No fwdproxy detected, assuming direct internet"
    fi
}

# === Oh My Zsh ===
install_omz() {
    step "Oh My Zsh"
    if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        info "Already installed, skipping"
        return
    fi
    rm -rf "$HOME/.oh-my-zsh/lib" "$HOME/.oh-my-zsh/oh-my-zsh.sh" 2>/dev/null
    local script
    script=$(eval curl $CURL_PROXY -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$script" "" --unattended
    info "Oh My Zsh installed"
}

# === Plugins ===
install_plugins() {
    step "Zsh Plugins"
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    for url in "${ZSH_PLUGINS[@]}"; do
        local name=$(basename "$url" .git)
        if [[ -d "$plugin_dir/$name" ]]; then
            info "$name already installed"
        else
            git clone --depth 1 "$url" "$plugin_dir/$name" 2>/dev/null
            info "$name installed"
        fi
    done
}

# === .zshrc ===
configure_zshrc() {
    step "Configuring .zshrc"
    local zshrc="$HOME/.zshrc"

    if grep -q 'source.*oh-my-zsh.sh' "$zshrc" 2>/dev/null; then
        info ".zshrc already configured, skipping"
        return
    fi

    [[ -f "$zshrc" ]] && cp "$zshrc" "$zshrc.bak.$(date +%s)"

    local plugin_names=()
    for url in "${ZSH_PLUGINS[@]}"; do
        plugin_names+=($(basename "$url" .git))
    done
    local plugins_str=$(IFS=' '; echo "${plugin_names[*]}")

    cat > "$zshrc" << ZSHRC
# Load Facebook stuff (don't remove this line).
[[ -f /usr/facebook/ops/rc/master.zshrc ]] && source /usr/facebook/ops/rc/master.zshrc

# Oh My Zsh
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git $plugins_str)
source \$ZSH/oh-my-zsh.sh

# History
HISTSIZE=1000000
SAVEHIST=1000000
setopt APPEND_HISTORY
setopt COMPLETE_IN_WORD

# Safer sudo rm
if [[ -o interactive ]]; then
    sudo() {
        if [[ "\$1" == "rm" ]]; then
            shift
            command sudo rm --preserve-root=all --one-file-system "\$@"
        else
            command sudo "\$@"
        fi
    }
fi
ZSHRC
    info ".zshrc configured (backup saved)"
}

# === .bashrc — auto switch to zsh ===
configure_bashrc() {
    step "Configuring .bashrc (auto-switch to zsh)"
    local bashrc="$HOME/.bashrc"

    if grep -q 'exec.*zsh' "$bashrc" 2>/dev/null; then
        info ".bashrc already has zsh switch, skipping"
        return
    fi

    if [[ -f "$bashrc" ]]; then
        cat >> "$bashrc" << 'BASH'

# Switch to zsh automatically (for LDAP-managed environments where chsh is unavailable)
if [[ -x /usr/bin/zsh && -z "$ZSH_VERSION" ]]; then
    exec /usr/bin/zsh -l
fi
BASH
        info ".bashrc updated — bash will auto-switch to zsh"
    else
        warn ".bashrc not found, skipping"
    fi
}

# === Git ===
configure_git() {
    step "Git"
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    info "Configured as $GIT_NAME <$GIT_EMAIL>"
}

# === SSH ===
configure_ssh() {
    step "SSH Key & Config"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    if [[ -f "$SSH_KEY" ]]; then
        info "SSH key already exists"
    else
        ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$GIT_EMAIL"
        info "SSH key generated"
    fi

    local ssh_config="$HOME/.ssh/config"
    if grep -q "github.com" "$ssh_config" 2>/dev/null; then
        info "SSH config already has github.com entry"
    else
        local proxy_cmd=""
        if command -v fwdproxy-config &>/dev/null; then
            local proxy_host=$(fwdproxy-config ssh 2>/dev/null | grep -oP '(?<=-x )\S+' || true)
            if [[ -n "$proxy_host" ]]; then
                if ncat --version &>/dev/null 2>&1; then
                    proxy_cmd="    ProxyCommand ncat --proxy $proxy_host --proxy-type http %h %p"
                else
                    proxy_cmd="    ProxyCommand nc -X connect -x $proxy_host %h %p"
                fi
            fi
        fi

        cat >> "$ssh_config" << SSH
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
${proxy_cmd}
SSH
        chmod 600 "$ssh_config"
        info "SSH config updated"
    fi

    echo ""
    warn "Add this public key to https://github.com/settings/ssh/new :"
    echo ""
    cat "${SSH_KEY}.pub"
    echo ""
}

# === Default Shell ===
set_default_shell() {
    step "Default Shell"
    local zsh_path=$(which zsh)
    if [[ "$SHELL" == "$zsh_path" ]]; then
        info "zsh is already default shell"
    else
        if command -v chsh &>/dev/null; then
            chsh -s "$zsh_path" 2>/dev/null && info "Default shell set to zsh" || warn "chsh failed (LDAP user?) — using .bashrc exec fallback"
        else
            warn "chsh not available (LDAP user?) — using .bashrc exec fallback"
        fi
    fi
}

# === Run ===
main() {
    echo -e "\033[1m Dev Environment Setup\033[0m"
    setup_proxy
    install_omz
    install_plugins
    configure_zshrc
    configure_bashrc
    configure_git
    configure_ssh
    set_default_shell

    step "Done"
    info "Open a new terminal or run: exec zsh"
    info "Then test GitHub: ssh -T git@github.com"
}

main

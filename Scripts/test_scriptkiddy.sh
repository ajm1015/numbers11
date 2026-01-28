#!/opt/homebrew/bin/bash
#
# Test suite for scriptkiddy v3.0.0
# Attempts to break the script with various edge cases
#

set -euo pipefail

SCRIPT="./scriptkiddy"
BASH_CMD="/opt/homebrew/bin/bash"
PASS_COUNT=0
FAIL_COUNT=0
TESTS=()
FAILURES=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_test() { printf "${CYAN}[TEST]${RESET} %s\n" "$1"; }
log_pass() { printf "${GREEN}[PASS]${RESET} %s\n" "$1"; ((PASS_COUNT++)); }
log_fail() { printf "${RED}[FAIL]${RESET} %s\n" "$1"; ((FAIL_COUNT++)); FAILURES+=("$1"); }
log_info() { printf "${YELLOW}[INFO]${RESET} %s\n" "$1"; }

run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2
    local args=("$@")

    log_test "$name"

    local output exit_code
    set +e
    output=$("$BASH_CMD" "$SCRIPT" "${args[@]}" 2>&1)
    exit_code=$?
    set -e

    if [[ "$exit_code" -eq "$expected_exit" ]]; then
        log_pass "$name (exit=$exit_code)"
        return 0
    else
        log_fail "$name (expected exit=$expected_exit, got exit=$exit_code)"
        echo "  Output: ${output:0:200}..."
        return 1
    fi
}

# Validate JSON output
validate_json() {
    local output="$1"
    if command -v jq &>/dev/null; then
        if echo "$output" | jq . &>/dev/null; then
            return 0
        else
            return 1
        fi
    elif command -v python3 &>/dev/null; then
        if echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)" &>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        log_info "No JSON validator available"
        return 0
    fi
}

# Validate XML output
validate_xml() {
    local output="$1"
    if command -v xmllint &>/dev/null; then
        if echo "$output" | xmllint --noout - 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif command -v python3 &>/dev/null; then
        if echo "$output" | python3 -c "import sys; from xml.etree import ElementTree; ElementTree.parse(sys.stdin)" &>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        log_info "No XML validator available"
        return 0
    fi
}

# Validate YAML output
validate_yaml() {
    local output="$1"
    if command -v python3 &>/dev/null; then
        if echo "$output" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" &>/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        log_info "No YAML validator available"
        return 0
    fi
}

echo ""
printf "${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}║               scriptkiddy v3.0.0 Test Suite                                  ║${RESET}\n"
printf "${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
echo ""

# ==============================================================================
# SECTION 1: Basic distro tests (all should pass)
# ==============================================================================
printf "\n${BOLD}═══ Section 1: All Distro Generators ═══${RESET}\n\n"

for distro in debian ubuntu ubuntu-legacy fedora rhel centos rocky alma arch opensuse alpine void nixos; do
    run_test "Basic $distro generation" 0 \
        --distro "$distro" --password testpass --dry-run
done

# Test suse alias
run_test "suse alias for opensuse" 0 \
    --distro suse --password testpass --dry-run

# ==============================================================================
# SECTION 2: Invalid input tests (should fail gracefully)
# ==============================================================================
printf "\n${BOLD}═══ Section 2: Invalid Inputs ═══${RESET}\n\n"

run_test "Unknown distro" 1 \
    --distro nonexistent --password test --dry-run

run_test "Invalid filesystem" 1 \
    --distro debian --filesystem zfs --password test --dry-run

run_test "Invalid boot mode" 1 \
    --distro debian --boot-mode hybrid --password test --dry-run

run_test "Unknown option" 1 \
    --distro debian --password test --unknown-flag --dry-run

run_test "Static network without IP" 1 \
    --distro debian --network static --password test --dry-run

# ==============================================================================
# SECTION 3: Special characters in passwords
# ==============================================================================
printf "\n${BOLD}═══ Section 3: Special Character Passwords ═══${RESET}\n\n"

# These should all succeed
run_test "Password with spaces" 0 \
    --distro debian --password "hello world" --dry-run

run_test "Password with quotes" 0 \
    --distro debian --password 'test"quote' --dry-run

run_test "Password with single quotes" 0 \
    --distro debian --password "test'quote" --dry-run

run_test "Password with backticks" 0 \
    --distro debian --password 'test`whoami`test' --dry-run

run_test "Password with dollar sign" 0 \
    --distro debian --password 'test$HOME' --dry-run

run_test "Password with backslash" 0 \
    --distro debian --password 'test\ntest' --dry-run

run_test "Password with semicolons" 0 \
    --distro debian --password 'test;rm -rf /' --dry-run

run_test "Password with pipes" 0 \
    --distro debian --password 'test|cat /etc/passwd' --dry-run

run_test "Password with ampersands" 0 \
    --distro debian --password 'test&&echo pwned' --dry-run

run_test "Password with parentheses" 0 \
    --distro debian --password 'test$(id)test' --dry-run

run_test "Very long password (1000 chars)" 0 \
    --distro debian --password "$(printf 'a%.0s' {1..1000})" --dry-run

# ==============================================================================
# SECTION 4: Special characters in other fields
# ==============================================================================
printf "\n${BOLD}═══ Section 4: Special Characters in Fields ═══${RESET}\n\n"

run_test "Hostname with underscore" 0 \
    --distro debian --hostname "my_host" --password test --dry-run

run_test "Username with numbers" 0 \
    --distro debian --user "user123" --password test --dry-run

run_test "Domain with subdomain" 0 \
    --distro debian --domain "sub.example.com" --password test --dry-run

run_test "Fullname with spaces and unicode" 0 \
    --distro debian --fullname "José García" --password test --dry-run

run_test "Extra packages with commas" 0 \
    --distro debian --packages "vim,htop,curl,wget" --password test --dry-run

run_test "SSH key with special chars" 0 \
    --distro debian --ssh-key "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ== user@host" --password test --dry-run

# ==============================================================================
# SECTION 5: JSON Output Validation (archinstall)
# ==============================================================================
printf "\n${BOLD}═══ Section 5: JSON Output Validation ═══${RESET}\n\n"

log_test "Arch JSON validity - basic"
output=$("$BASH_CMD" "$SCRIPT" --distro arch --password testpass --dry-run 2>&1 | sed -n '/^{/,/^}/p')
if validate_json "$output"; then
    log_pass "Arch JSON validity - basic"
else
    log_fail "Arch JSON validity - basic"
fi

log_test "Arch JSON validity - with encryption"
output=$("$BASH_CMD" "$SCRIPT" --distro arch --password testpass --encrypt --encrypt-pass secret --dry-run 2>&1 | sed -n '/^{/,/^}/p')
if validate_json "$output"; then
    log_pass "Arch JSON validity - with encryption"
else
    log_fail "Arch JSON validity - with encryption"
fi

log_test "Arch JSON validity - with static network"
output=$("$BASH_CMD" "$SCRIPT" --distro arch --password testpass --ip 192.168.1.100 --gateway 192.168.1.1 --dry-run 2>&1 | sed -n '/^{/,/^}/p')
if validate_json "$output"; then
    log_pass "Arch JSON validity - with static network"
else
    log_fail "Arch JSON validity - with static network"
fi

log_test "Arch JSON validity - special chars in password"
output=$("$BASH_CMD" "$SCRIPT" --distro arch --password 'test"quotes\backslash' --dry-run 2>&1 | sed -n '/^{/,/^}/p')
if validate_json "$output"; then
    log_pass "Arch JSON validity - special chars"
else
    log_fail "Arch JSON validity - special chars (JSON may have unescaped characters)"
fi

# ==============================================================================
# SECTION 6: XML Output Validation (autoyast)
# ==============================================================================
printf "\n${BOLD}═══ Section 6: XML Output Validation ═══${RESET}\n\n"

log_test "AutoYaST XML validity - basic"
output=$("$BASH_CMD" "$SCRIPT" --distro opensuse --password testpass --dry-run 2>&1 | sed -n '/<\?xml/,/<\/profile>/p')
if validate_xml "$output"; then
    log_pass "AutoYaST XML validity - basic"
else
    log_fail "AutoYaST XML validity - basic"
fi

log_test "AutoYaST XML validity - with static network"
output=$("$BASH_CMD" "$SCRIPT" --distro opensuse --password testpass --ip 192.168.1.100 --gateway 192.168.1.1 --dry-run 2>&1 | sed -n '/<\?xml/,/<\/profile>/p')
if validate_xml "$output"; then
    log_pass "AutoYaST XML validity - static network"
else
    log_fail "AutoYaST XML validity - static network"
fi

# Test XML entities that could break parsing
log_test "AutoYaST XML - special chars in username"
output=$("$BASH_CMD" "$SCRIPT" --distro opensuse --user "test<user" --password testpass --dry-run 2>&1 | sed -n '/<\?xml/,/<\/profile>/p')
if validate_xml "$output"; then
    log_pass "AutoYaST XML - special chars (but may need escaping)"
else
    log_fail "AutoYaST XML - username with < breaks XML"
fi

# ==============================================================================
# SECTION 7: YAML Output Validation (autoinstall)
# ==============================================================================
printf "\n${BOLD}═══ Section 7: YAML Output Validation ═══${RESET}\n\n"

log_test "Ubuntu Autoinstall YAML validity - basic"
output=$("$BASH_CMD" "$SCRIPT" --distro ubuntu --password testpass --dry-run 2>&1 | sed -n '/^#cloud-config/,/^[^[:space:]]/p' | head -n -1)
# YAML validation might fail due to missing PyYAML, so this is informational
if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
    if validate_yaml "$output"; then
        log_pass "Ubuntu Autoinstall YAML validity - basic"
    else
        log_fail "Ubuntu Autoinstall YAML validity - basic"
    fi
else
    log_info "YAML validation skipped (no PyYAML)"
fi

# ==============================================================================
# SECTION 8: Boundary Values
# ==============================================================================
printf "\n${BOLD}═══ Section 8: Boundary Values ═══${RESET}\n\n"

run_test "Swap size 0 (disable)" 0 \
    --distro debian --swap 0 --password test --dry-run

run_test "Swap size very large" 0 \
    --distro debian --swap 999999 --password test --dry-run

run_test "SSH port 22" 0 \
    --distro debian --ssh-port 22 --password test --dry-run

run_test "SSH port 65535" 0 \
    --distro debian --ssh-port 65535 --password test --dry-run

run_test "All DEs - gnome" 0 --distro debian --de gnome --password test --dry-run
run_test "All DEs - kde" 0 --distro debian --de kde --password test --dry-run
run_test "All DEs - xfce" 0 --distro debian --de xfce --password test --dry-run
run_test "All DEs - lxqt" 0 --distro debian --de lxqt --password test --dry-run
run_test "All DEs - cinnamon" 0 --distro debian --de cinnamon --password test --dry-run
run_test "All DEs - mate" 0 --distro debian --de mate --password test --dry-run
run_test "All DEs - budgie" 0 --distro debian --de budgie --password test --dry-run
run_test "All DEs - i3" 0 --distro debian --de i3 --password test --dry-run
run_test "All DEs - sway" 0 --distro debian --de sway --password test --dry-run
run_test "All DEs - none" 0 --distro debian --de none --password test --dry-run

# ==============================================================================
# SECTION 9: Filesystem combinations
# ==============================================================================
printf "\n${BOLD}═══ Section 9: Filesystem Combinations ═══${RESET}\n\n"

for fs in ext4 btrfs xfs; do
    for boot in efi bios; do
        run_test "$fs + $boot mode" 0 \
            --distro debian --filesystem "$fs" --boot-mode "$boot" --password test --dry-run
    done
done

run_test "btrfs without subvols" 0 \
    --distro debian --filesystem btrfs --no-btrfs-subvols --password test --dry-run

# ==============================================================================
# SECTION 10: Encryption combinations
# ==============================================================================
printf "\n${BOLD}═══ Section 10: Encryption Combinations ═══${RESET}\n\n"

for distro in debian fedora arch opensuse void nixos; do
    run_test "$distro with encryption" 0 \
        --distro "$distro" --encrypt --encrypt-pass secretpass --password test --dry-run
done

run_test "LVM + encryption" 0 \
    --distro fedora --lvm --encrypt --encrypt-pass secret --password test --dry-run

# ==============================================================================
# SECTION 11: Network configurations
# ==============================================================================
printf "\n${BOLD}═══ Section 11: Network Configurations ═══${RESET}\n\n"

run_test "Static IP full config" 0 \
    --distro debian --network static --ip 10.0.0.50 --netmask 255.255.255.0 \
    --gateway 10.0.0.1 --dns "8.8.8.8 1.1.1.1" --password test --dry-run

run_test "WiFi configuration" 0 \
    --distro debian --wifi "My Network" --wifi-pass "wifipass123" --password test --dry-run

# ==============================================================================
# SECTION 12: Root account variations
# ==============================================================================
printf "\n${BOLD}═══ Section 12: Root Account ═══${RESET}\n\n"

run_test "Enable root without password" 0 \
    --distro debian --enable-root --password test --dry-run

run_test "Enable root with password" 0 \
    --distro debian --root-password rootsecret --password test --dry-run

# ==============================================================================
# SECTION 13: Security options
# ==============================================================================
printf "\n${BOLD}═══ Section 13: Security Options ═══${RESET}\n\n"

run_test "Firewall enabled" 0 \
    --distro fedora --firewall --password test --dry-run

run_test "SELinux enforcing" 0 \
    --distro fedora --selinux enforcing --password test --dry-run

run_test "SELinux permissive" 0 \
    --distro fedora --selinux permissive --password test --dry-run

run_test "SELinux disabled" 0 \
    --distro fedora --selinux disabled --password test --dry-run

run_test "SSH root login allowed" 0 \
    --distro debian --ssh-root --password test --dry-run

run_test "SSH disabled" 0 \
    --distro debian --no-ssh --password test --dry-run

# ==============================================================================
# SECTION 14: Complex combinations
# ==============================================================================
printf "\n${BOLD}═══ Section 14: Complex Combinations ═══${RESET}\n\n"

run_test "Full Fedora workstation config" 0 \
    --distro fedora --release 40 \
    --hostname "fedora-workstation" --domain "example.com" \
    --timezone "America/New_York" --locale "en_US.UTF-8" --keyboard "us" \
    --user "developer" --fullname "John Developer" --password "securepass123" \
    --root-password "rootpass" \
    --disk "/dev/nvme0n1" --filesystem btrfs --boot-mode efi --lvm --encrypt --encrypt-pass "diskpass" \
    --swap 8192 \
    --de gnome \
    --packages "vim,git,docker,nodejs" \
    --network static --ip 192.168.1.100 --gateway 192.168.1.1 --dns "8.8.8.8" \
    --firewall --selinux enforcing \
    --ssh-port 2222 --ssh-key "ssh-rsa AAAA..." \
    --dry-run

run_test "Full Arch minimal server config" 0 \
    --distro arch \
    --hostname "arch-server" \
    --user "admin" --password "adminpass" \
    --disk "/dev/sda" --filesystem ext4 --boot-mode bios \
    --swap 0 \
    --de none \
    --no-ssh \
    --dry-run

run_test "Full NixOS desktop config" 0 \
    --distro nixos --release "24.05" \
    --hostname "nixos-desktop" --domain "home.local" \
    --user "nixuser" --password "nixpass" \
    --filesystem btrfs --boot-mode efi \
    --de kde \
    --packages "firefox,vscode" \
    --firewall \
    --ssh-port 22 \
    --dry-run

# ==============================================================================
# SECTION 15: Edge case - Empty/whitespace strings
# ==============================================================================
printf "\n${BOLD}═══ Section 15: Empty/Whitespace Handling ═══${RESET}\n\n"

run_test "Empty hostname (should use default)" 0 \
    --distro debian --hostname "" --password test --dry-run

run_test "Empty domain (should be ok)" 0 \
    --distro debian --domain "" --password test --dry-run

run_test "Whitespace-only packages" 0 \
    --distro debian --packages "   " --password test --dry-run

# ==============================================================================
# SECTION 16: Output content validation
# ==============================================================================
printf "\n${BOLD}═══ Section 16: Output Content Checks ═══${RESET}\n\n"

# Check that generated preseed contains expected directives
log_test "Preseed contains hostname"
output=$("$BASH_CMD" "$SCRIPT" --distro debian --hostname "myserver" --password test --dry-run 2>&1)
if echo "$output" | grep -q "d-i netcfg/get_hostname string myserver"; then
    log_pass "Preseed contains hostname directive"
else
    log_fail "Preseed missing hostname directive"
fi

# Check kickstart has correct DE group
log_test "Kickstart DE group"
output=$("$BASH_CMD" "$SCRIPT" --distro fedora --de gnome --password test --dry-run 2>&1)
if echo "$output" | grep -q "gnome-desktop-environment\|gnome"; then
    log_pass "Kickstart contains GNOME reference"
else
    log_fail "Kickstart missing GNOME reference"
fi

# Check NixOS Nix syntax
log_test "NixOS config syntax"
output=$("$BASH_CMD" "$SCRIPT" --distro nixos --hostname "testbox" --password test --dry-run 2>&1)
if echo "$output" | grep -q 'hostName = "testbox"'; then
    log_pass "NixOS has correct hostname syntax"
else
    log_fail "NixOS hostname syntax issue"
fi

# ==============================================================================
# SECTION 17: Injection attempts
# ==============================================================================
printf "\n${BOLD}═══ Section 17: Injection Attempts ═══${RESET}\n\n"

log_test "Command injection via hostname"
output=$("$BASH_CMD" "$SCRIPT" --distro debian --hostname '$(whoami)' --password test --dry-run 2>&1)
if echo "$output" | grep -q 'get_hostname string $(whoami)'; then
    log_pass "Hostname injection - literal (preseed will interpret)"
else
    log_info "Hostname may have been sanitized"
fi

log_test "XML injection via username"
output=$("$BASH_CMD" "$SCRIPT" --distro opensuse --user '"><script>alert(1)</script>' --password test --dry-run 2>&1)
if echo "$output" | grep -q '<script>'; then
    log_fail "XML injection via username - XSS possible in autoyast"
else
    log_pass "XML injection blocked/escaped"
fi

log_test "JSON injection via hostname"
output=$("$BASH_CMD" "$SCRIPT" --distro arch --hostname '", "malicious": "true' --password test --dry-run 2>&1)
# Check if it breaks JSON
extracted=$(echo "$output" | sed -n '/^{/,/^}/p')
if validate_json "$extracted" 2>/dev/null; then
    log_pass "JSON injection - JSON still valid"
else
    log_fail "JSON injection broke JSON structure"
fi

# ==============================================================================
# SECTION 18: Unicode and i18n
# ==============================================================================
printf "\n${BOLD}═══ Section 18: Unicode and i18n ═══${RESET}\n\n"

run_test "Chinese locale" 0 \
    --distro debian --locale "zh_CN.UTF-8" --password test --dry-run

run_test "Japanese locale" 0 \
    --distro debian --locale "ja_JP.UTF-8" --password test --dry-run

run_test "German keyboard" 0 \
    --distro debian --keyboard "de" --password test --dry-run

run_test "Russian keyboard" 0 \
    --distro debian --keyboard "ru" --password test --dry-run

run_test "Fullname with emojis" 0 \
    --distro debian --fullname "User 🚀" --password test --dry-run

# ==============================================================================
# SECTION 19: Disk device variations
# ==============================================================================
printf "\n${BOLD}═══ Section 19: Disk Device Variations ═══${RESET}\n\n"

run_test "NVMe disk" 0 \
    --distro debian --disk "/dev/nvme0n1" --password test --dry-run

run_test "virtio disk" 0 \
    --distro debian --disk "/dev/vda" --password test --dry-run

run_test "SCSI disk" 0 \
    --distro debian --disk "/dev/sda" --password test --dry-run

run_test "Multipath disk" 0 \
    --distro debian --disk "/dev/mapper/mpath0" --password test --dry-run

run_test "Disk path with spaces (unusual)" 0 \
    --distro debian --disk "/dev/disk/by-id/some disk" --password test --dry-run

# ==============================================================================
# SECTION 20: Version and help flags
# ==============================================================================
printf "\n${BOLD}═══ Section 20: Info Flags ═══${RESET}\n\n"

run_test "--version flag" 0 --version
run_test "--help flag" 0 --help
run_test "--list-distros flag" 0 --list-distros

# ==============================================================================
# SECTION 21: Post-install script
# ==============================================================================
printf "\n${BOLD}═══ Section 21: Post-Install Script ═══${RESET}\n\n"

run_test "Post-script inline" 0 \
    --distro fedora --post-script "echo hello" --password test --dry-run

run_test "Post-script with special chars" 0 \
    --distro fedora --post-script 'echo "test" && rm -rf /tmp/test' --password test --dry-run

# ==============================================================================
# SECTION 22: All releases for each distro
# ==============================================================================
printf "\n${BOLD}═══ Section 22: All Releases ═══${RESET}\n\n"

run_test "Debian bookworm" 0 --distro debian --release bookworm --password test --dry-run
run_test "Debian bullseye" 0 --distro debian --release bullseye --password test --dry-run
run_test "Debian sid" 0 --distro debian --release sid --password test --dry-run

run_test "Ubuntu noble" 0 --distro ubuntu --release noble --password test --dry-run
run_test "Ubuntu jammy" 0 --distro ubuntu --release jammy --password test --dry-run
run_test "Ubuntu focal" 0 --distro ubuntu --release focal --password test --dry-run

run_test "Fedora 40" 0 --distro fedora --release 40 --password test --dry-run
run_test "Fedora 39" 0 --distro fedora --release 39 --password test --dry-run

run_test "Rocky 9" 0 --distro rocky --release 9 --password test --dry-run
run_test "Rocky 8" 0 --distro rocky --release 8 --password test --dry-run

run_test "NixOS unstable" 0 --distro nixos --release unstable --password test --dry-run
run_test "NixOS 24.05" 0 --distro nixos --release "24.05" --password test --dry-run

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
printf "${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}║                           TEST SUMMARY                                        ║${RESET}\n"
printf "${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${RESET}\n"
echo ""
printf "  ${GREEN}Passed:${RESET} %d\n" "$PASS_COUNT"
printf "  ${RED}Failed:${RESET} %d\n" "$FAIL_COUNT"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    printf "${RED}Failed tests:${RESET}\n"
    for failure in "${FAILURES[@]}"; do
        printf "  - %s\n" "$failure"
    done
    echo ""
    exit 1
else
    printf "${GREEN}All tests passed!${RESET}\n"
    echo ""
    exit 0
fi

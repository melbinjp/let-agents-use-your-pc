#!/bin/bash

# SSH Key Validation Module
# Provides comprehensive SSH public key validation functions

set -euo pipefail

# Function to validate SSH key format and security
validate_ssh_key_comprehensive() {
    local key="$1"
    local min_key_length="${2:-2048}"
    
    # Check if key is not empty
    if [[ -z "$key" ]]; then
        echo "ERROR: SSH public key cannot be empty"
        return 1
    fi
    
    # Remove any leading/trailing whitespace
    key=$(echo "$key" | xargs)
    
    # Check if key starts with valid key type
    local key_type
    key_type=$(echo "$key" | awk '{print $1}')
    
    case "$key_type" in
        ssh-rsa)
            echo "INFO: Detected RSA key"
            ;;
        ssh-ed25519)
            echo "INFO: Detected Ed25519 key (recommended)"
            ;;
        ssh-dss)
            echo "WARNING: DSS keys are deprecated and insecure"
            return 1
            ;;
        ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)
            echo "INFO: Detected ECDSA key"
            ;;
        *)
            echo "ERROR: Invalid SSH key type: $key_type"
            echo "Supported types: ssh-rsa, ssh-ed25519, ecdsa-sha2-*"
            return 1
            ;;
    esac
    
    # Check if key has at least 3 parts (type, key, optional comment)
    local key_parts
    key_parts=$(echo "$key" | wc -w)
    if [ "$key_parts" -lt 2 ]; then
        echo "ERROR: Invalid SSH key format. Key must have at least key type and key data"
        return 1
    fi
    
    # Validate key data is base64
    local key_data
    key_data=$(echo "$key" | awk '{print $2}')
    if ! echo "$key_data" | base64 -d &>/dev/null; then
        echo "ERROR: SSH key data is not valid base64"
        return 1
    fi
    
    # Check key length for RSA keys
    if [[ "$key_type" == "ssh-rsa" ]]; then
        local key_bits
        if command -v ssh-keygen &> /dev/null; then
            key_bits=$(echo "$key" | ssh-keygen -l -f - 2>/dev/null | awk '{print $1}' || echo "0")
            if [ "$key_bits" -lt "$min_key_length" ]; then
                echo "ERROR: RSA key length ($key_bits bits) is below minimum ($min_key_length bits)"
                return 1
            fi
            echo "INFO: RSA key length: $key_bits bits"
        fi
    fi
    
    # Try to validate key format using ssh-keygen if available
    if command -v ssh-keygen &> /dev/null; then
        if ! echo "$key" | ssh-keygen -l -f - &>/dev/null; then
            echo "ERROR: SSH key validation failed using ssh-keygen"
            return 1
        fi
    fi
    
    # Check for common security issues
    local key_comment
    key_comment=$(echo "$key" | cut -d' ' -f3- 2>/dev/null || echo "")
    
    # Warn about keys without comments
    if [[ -z "$key_comment" ]]; then
        echo "WARNING: SSH key has no comment. Consider adding a comment for identification"
    fi
    
    echo "SUCCESS: SSH key format validation passed"
    return 0
}

# Function to validate SSH key file permissions
validate_ssh_key_permissions() {
    local key_file="$1"
    local expected_owner="$2"
    
    if [[ ! -f "$key_file" ]]; then
        echo "ERROR: SSH key file does not exist: $key_file"
        return 1
    fi
    
    # Check file permissions (should be 600)
    local file_perms
    file_perms=$(stat -c %a "$key_file")
    if [[ "$file_perms" != "600" ]]; then
        echo "ERROR: SSH key file has incorrect permissions: $file_perms (expected: 600)"
        return 1
    fi
    
    # Check file ownership
    local file_owner
    file_owner=$(stat -c %U "$key_file")
    if [[ "$file_owner" != "$expected_owner" ]]; then
        echo "ERROR: SSH key file has incorrect owner: $file_owner (expected: $expected_owner)"
        return 1
    fi
    
    echo "SUCCESS: SSH key file permissions are correct"
    return 0
}

# Function to validate SSH directory structure
validate_ssh_directory() {
    local ssh_dir="$1"
    local expected_owner="$2"
    
    if [[ ! -d "$ssh_dir" ]]; then
        echo "ERROR: SSH directory does not exist: $ssh_dir"
        return 1
    fi
    
    # Check directory permissions (should be 700)
    local dir_perms
    dir_perms=$(stat -c %a "$ssh_dir")
    if [[ "$dir_perms" != "700" ]]; then
        echo "ERROR: SSH directory has incorrect permissions: $dir_perms (expected: 700)"
        return 1
    fi
    
    # Check directory ownership
    local dir_owner
    dir_owner=$(stat -c %U "$ssh_dir")
    if [[ "$dir_owner" != "$expected_owner" ]]; then
        echo "ERROR: SSH directory has incorrect owner: $dir_owner (expected: $expected_owner)"
        return 1
    fi
    
    echo "SUCCESS: SSH directory permissions are correct"
    return 0
}

# Function to sanitize SSH key input
sanitize_ssh_key() {
    local key="$1"
    
    # Remove any carriage returns and extra whitespace
    key=$(echo "$key" | tr -d '\r' | xargs)
    
    # Remove any potential shell injection characters
    key=$(echo "$key" | sed 's/[;&|`$(){}]//')
    
    echo "$key"
}

# Main validation function that combines all checks
validate_ssh_setup() {
    local public_key="$1"
    local user="$2"
    local min_key_length="${3:-2048}"
    
    echo "INFO: Starting comprehensive SSH setup validation for user: $user"
    
    # Sanitize the key
    public_key=$(sanitize_ssh_key "$public_key")
    
    # Validate key format
    if ! validate_ssh_key_comprehensive "$public_key" "$min_key_length"; then
        return 1
    fi
    
    # Validate SSH directory and file structure
    local user_home
    user_home=$(eval echo "~$user")
    local ssh_dir="$user_home/.ssh"
    local auth_keys_file="$ssh_dir/authorized_keys"
    
    if [[ -d "$ssh_dir" ]]; then
        validate_ssh_directory "$ssh_dir" "$user"
    fi
    
    if [[ -f "$auth_keys_file" ]]; then
        validate_ssh_key_permissions "$auth_keys_file" "$user"
    fi
    
    echo "SUCCESS: SSH setup validation completed successfully"
    return 0
}

# Export functions for use in other scripts
export -f validate_ssh_key_comprehensive
export -f validate_ssh_key_permissions
export -f validate_ssh_directory
export -f sanitize_ssh_key
export -f validate_ssh_setup
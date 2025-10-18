#!/usr/bin/env python3
"""
Security Validation Module for Enhanced MCP Hardware Server
Provides comprehensive security checks and validation
"""

import re
import os
import stat
import hashlib
import secrets
from typing import List, Dict, Optional, Tuple
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

class SecurityValidator:
    """Comprehensive security validation for MCP server operations"""
    
    # Dangerous command patterns that should be blocked or sanitized
    DANGEROUS_PATTERNS = [
        r'rm\s+-rf\s+/',
        r'dd\s+if=.*of=.*',
        r'mkfs\.',
        r'fdisk\s+',
        r'parted\s+',
        r'format\s+',
        r'del\s+/[sq]\s+',
        r'rmdir\s+/[sq]\s+',
        r'>\s*/dev/sd[a-z]',
        r'curl\s+.*\|\s*bash',
        r'wget\s+.*\|\s*bash',
        r'eval\s+\$\(',
        r'`[^`]*`',
        r'\$\([^)]*\)',
        r';\s*rm\s+',
        r'&&\s*rm\s+',
        r'\|\s*rm\s+',
        r'nc\s+.*\s+\d+.*<',
        r'netcat\s+.*\s+\d+.*<',
    ]
    
    # Allowed command prefixes for system operations
    ALLOWED_COMMANDS = [
        'ls', 'cat', 'grep', 'find', 'ps', 'top', 'htop', 'df', 'du', 'free',
        'uname', 'whoami', 'id', 'pwd', 'cd', 'mkdir', 'touch', 'cp', 'mv',
        'chmod', 'chown', 'ln', 'tar', 'gzip', 'gunzip', 'zip', 'unzip',
        'apt', 'yum', 'dnf', 'pacman', 'pip', 'npm', 'yarn', 'docker',
        'git', 'vim', 'nano', 'emacs', 'python', 'python3', 'node', 'java',
        'gcc', 'make', 'cmake', 'systemctl', 'service', 'journalctl',
        'nvidia-smi', 'lspci', 'lsusb', 'lscpu', 'lsmem', 'iostat', 'vmstat'
    ]
    
    def __init__(self):
        self.blocked_commands = []
        self.security_log = []
    
    def validate_hostname(self, hostname: str) -> Tuple[bool, str]:
        """
        Validate hostname for security and format compliance
        
        Args:
            hostname: The hostname to validate
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not hostname or not isinstance(hostname, str):
            return False, "Hostname must be a non-empty string"
        
        # Length check
        if len(hostname) > 253:
            return False, "Hostname too long (max 253 characters)"
        
        # Format validation
        if hostname.startswith('-') or hostname.endswith('-'):
            return False, "Hostname cannot start or end with hyphen"
        
        if '..' in hostname:
            return False, "Hostname cannot contain consecutive dots"
        
        # Character validation
        allowed_chars = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-')
        if not all(c in allowed_chars for c in hostname):
            return False, "Hostname contains invalid characters"
        
        # Check for suspicious patterns
        suspicious_patterns = [
            r'localhost',
            r'127\.0\.0\.1',
            r'0\.0\.0\.0',
            r'::1',
            r'.*\.local$',
            r'.*\.internal$',
            r'.*\.corp$'
        ]
        
        for pattern in suspicious_patterns:
            if re.match(pattern, hostname, re.IGNORECASE):
                logger.warning(f"Potentially suspicious hostname: {hostname}")
        
        return True, ""
    
    def validate_command(self, command: str, allow_sudo: bool = False) -> Tuple[bool, str]:
        """
        Validate command for security risks
        
        Args:
            command: The command to validate
            allow_sudo: Whether sudo commands are allowed
            
        Returns:
            Tuple of (is_safe, error_message)
        """
        if not command or not isinstance(command, str):
            return False, "Command must be a non-empty string"
        
        # Remove leading/trailing whitespace
        command = command.strip()
        
        # Check for dangerous patterns
        for pattern in self.DANGEROUS_PATTERNS:
            if re.search(pattern, command, re.IGNORECASE):
                self.blocked_commands.append(command)
                return False, f"Command contains dangerous pattern: {pattern}"
        
        # Check for command injection attempts
        injection_patterns = [
            r';\s*[^;]+',  # Command chaining with semicolon
            r'&&\s*[^&]+',  # Command chaining with &&
            r'\|\s*[^|]+',  # Piping to potentially dangerous commands
            r'`[^`]+`',     # Command substitution with backticks
            r'\$\([^)]+\)', # Command substitution with $()
            r'>\s*/dev/',   # Redirecting to device files
            r'<\s*/dev/',   # Reading from device files
        ]
        
        for pattern in injection_patterns:
            matches = re.findall(pattern, command)
            for match in matches:
                # Check if the chained command is safe
                chained_cmd = re.sub(r'^[;&|`$()>\s]+', '', match).split()[0]
                if chained_cmd not in self.ALLOWED_COMMANDS:
                    return False, f"Potentially dangerous command chaining: {match}"
        
        # Extract the main command
        main_command = command.split()[0]
        if main_command.lower() == 'sudo':
            if not allow_sudo:
                return False, "Sudo commands not allowed in this context"
            if len(command.split()) < 2:
                return False, "Incomplete sudo command"
            main_command = command.split()[1]
        
        # Check if main command is in allowed list
        if main_command not in self.ALLOWED_COMMANDS:
            logger.warning(f"Command not in allowed list: {main_command}")
            # Don't block, but log for monitoring
        
        return True, ""
    
    def validate_file_path(self, file_path: str, operation: str = "read") -> Tuple[bool, str]:
        """
        Validate file path for security risks
        
        Args:
            file_path: The file path to validate
            operation: The operation type (read, write, execute)
            
        Returns:
            Tuple of (is_safe, error_message)
        """
        if not file_path or not isinstance(file_path, str):
            return False, "File path must be a non-empty string"
        
        # Normalize path
        try:
            normalized_path = os.path.normpath(file_path)
        except Exception as e:
            return False, f"Invalid file path: {e}"
        
        # Check for path traversal attempts
        if '..' in normalized_path:
            return False, "Path traversal attempt detected"
        
        # Check for access to sensitive system files
        sensitive_paths = [
            '/etc/passwd',
            '/etc/shadow',
            '/etc/sudoers',
            '/root/',
            '/proc/kcore',
            '/dev/mem',
            '/dev/kmem',
            '/sys/firmware/',
            '/boot/',
        ]
        
        for sensitive_path in sensitive_paths:
            if normalized_path.startswith(sensitive_path):
                if operation in ['write', 'execute']:
                    return False, f"Write/execute access denied to sensitive path: {sensitive_path}"
                else:
                    logger.warning(f"Read access to sensitive path: {normalized_path}")
        
        return True, ""
    
    def validate_ssh_key(self, key_path: str) -> Tuple[bool, str]:
        """
        Validate SSH private key file
        
        Args:
            key_path: Path to the SSH private key
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if not key_path or not isinstance(key_path, str):
            return False, "Key path must be a non-empty string"
        
        # Check if file exists
        if not os.path.exists(key_path):
            return False, f"SSH key file not found: {key_path}"
        
        # Check file permissions
        try:
            file_stat = os.stat(key_path)
            file_mode = stat.filemode(file_stat.st_mode)
            
            # SSH keys should have restrictive permissions (600 or 400)
            if file_stat.st_mode & 0o077:  # Check if group/other have any permissions
                return False, f"SSH key has insecure permissions: {file_mode}"
        
        except Exception as e:
            return False, f"Cannot check key file permissions: {e}"
        
        # Basic key format validation
        try:
            with open(key_path, 'r') as f:
                key_content = f.read()
                
            # Check for valid key headers
            valid_headers = [
                '-----BEGIN OPENSSH PRIVATE KEY-----',
                '-----BEGIN RSA PRIVATE KEY-----',
                '-----BEGIN EC PRIVATE KEY-----',
                '-----BEGIN PRIVATE KEY-----'
            ]
            
            if not any(header in key_content for header in valid_headers):
                return False, "Invalid SSH key format"
                
        except Exception as e:
            return False, f"Cannot read SSH key file: {e}"
        
        return True, ""
    
    def sanitize_command_output(self, output: str) -> str:
        """
        Sanitize command output to remove potentially sensitive information
        
        Args:
            output: Raw command output
            
        Returns:
            Sanitized output
        """
        if not output:
            return output
        
        # Remove potential credentials from output
        patterns_to_redact = [
            (r'password[=:]\s*\S+', 'password=***'),
            (r'token[=:]\s*\S+', 'token=***'),
            (r'key[=:]\s*\S+', 'key=***'),
            (r'secret[=:]\s*\S+', 'secret=***'),
            (r'api[_-]?key[=:]\s*\S+', 'api_key=***'),
            (r'auth[_-]?token[=:]\s*\S+', 'auth_token=***'),
        ]
        
        sanitized = output
        for pattern, replacement in patterns_to_redact:
            sanitized = re.sub(pattern, replacement, sanitized, flags=re.IGNORECASE)
        
        return sanitized
    
    def generate_session_token(self) -> str:
        """Generate a secure session token"""
        return secrets.token_urlsafe(32)
    
    def hash_sensitive_data(self, data: str) -> str:
        """Hash sensitive data for logging purposes"""
        return hashlib.sha256(data.encode()).hexdigest()[:16]
    
    def log_security_event(self, event_type: str, details: str, severity: str = "INFO"):
        """Log security-related events"""
        from datetime import datetime
        event = {
            'timestamp': str(datetime.now()),
            'type': event_type,
            'details': details,
            'severity': severity
        }
        self.security_log.append(event)
        logger.log(getattr(logging, severity), f"Security Event: {event_type} - {details}")
    
    def get_security_summary(self) -> Dict:
        """Get summary of security events and blocked operations"""
        return {
            'blocked_commands': len(self.blocked_commands),
            'security_events': len(self.security_log),
            'recent_events': self.security_log[-10:] if self.security_log else []
        }

# Global security validator instance
security_validator = SecurityValidator()
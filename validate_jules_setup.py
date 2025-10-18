#!/usr/bin/env python3
"""
Jules Setup Validation Script
Validates that the hardware access setup is ready for Jules integration
"""

import os
import sys
import json
import subprocess
import platform
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_test(name, passed, details=""):
    """Print test result"""
    status = f"{Colors.GREEN}✓ PASS{Colors.END}" if passed else f"{Colors.RED}✗ FAIL{Colors.END}"
    print(f"{status} {name}")
    if details:
        print(f"     {details}")

def run_command(cmd):
    """Run command and return success status"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            capture_output=True,
            text=True,
            timeout=10
        )
        return True, result.stdout
    except:
        return False, ""

def validate_python_version():
    """Validate Python version"""
    version = sys.version_info
    passed = version.major >= 3 and version.minor >= 8
    details = f"Python {version.major}.{version.minor}.{version.micro}"
    print_test("Python Version (3.8+)", passed, details)
    return passed

def validate_dependencies():
    """Validate required Python packages"""
    required = ["paramiko", "requests", "mcp"]
    all_passed = True
    
    for package in required:
        try:
            __import__(package)
            print_test(f"Package: {package}", True)
        except ImportError:
            print_test(f"Package: {package}", False, "Not installed")
            all_passed = False
    
    return all_passed

def validate_ssh_keys():
    """Validate SSH key files exist and have correct permissions"""
    keys = ["jules_key", "jules_key.pub"]
    all_passed = True
    
    for key in keys:
        if os.path.exists(key):
            # Check permissions
            stat_info = os.stat(key)
            mode = stat_info.st_mode & 0o777
            
            if key.endswith(".pub"):
                expected = 0o644
            else:
                expected = 0o600
            
            if mode == expected:
                print_test(f"SSH Key: {key}", True, f"Permissions: {oct(mode)}")
            else:
                print_test(f"SSH Key: {key}", False, f"Wrong permissions: {oct(mode)} (expected {oct(expected)})")
                all_passed = False
        else:
            print_test(f"SSH Key: {key}", False, "File not found")
            all_passed = False
    
    return all_passed

def validate_ssh_server():
    """Validate SSH server is running"""
    system = platform.system()
    
    if system == "Linux":
        success, _ = run_command("systemctl is-active ssh || systemctl is-active sshd")
        print_test("SSH Server Running", success)
        return success
    elif system == "Darwin":
        success, output = run_command("sudo systemsetup -getremotelogin")
        is_on = "On" in output
        print_test("SSH Server Running", is_on, output.strip())
        return is_on
    elif system == "Windows":
        success, _ = run_command("sc query sshd")
        print_test("SSH Server Running", success)
        return success
    
    return False

def validate_jules_user():
    """Validate jules user exists and has sudo access"""
    system = platform.system()
    
    if system in ["Linux", "Darwin"]:
        # Check if user exists
        success, _ = run_command("id jules")
        print_test("Jules User Exists", success)
        
        if not success:
            return False
        
        # Check sudo access
        success, _ = run_command("sudo -l -U jules | grep -q NOPASSWD")
        print_test("Jules Sudo Access", success)
        
        # Check SSH directory
        success, _ = run_command("test -d /home/jules/.ssh")
        print_test("Jules SSH Directory", success)
        
        # Check authorized_keys
        success, _ = run_command("test -f /home/jules/.ssh/authorized_keys")
        print_test("Jules Authorized Keys", success)
        
        return success
    
    return True

def validate_mcp_config():
    """Validate MCP server configuration"""
    config_file = "mcp-server-config.json"
    
    if not os.path.exists(config_file):
        print_test("MCP Config File", False, "File not found")
        return False
    
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        # Check required sections
        required_sections = ["mcp_server", "ssh_config", "settings"]
        all_present = all(section in config for section in required_sections)
        
        if all_present:
            print_test("MCP Config Structure", True)
            
            # Check AI agent mode
            ai_mode = config.get("settings", {}).get("ai_agent_mode", False)
            print_test("AI Agent Mode Enabled", ai_mode)
            
            # Check rate limit
            rate_limit = config.get("settings", {}).get("rate_limit", 0)
            print_test("Rate Limit Configured", rate_limit >= 60, f"{rate_limit} req/min")
            
            return all_present and ai_mode
        else:
            print_test("MCP Config Structure", False, "Missing required sections")
            return False
    
    except json.JSONDecodeError:
        print_test("MCP Config File", False, "Invalid JSON")
        return False

def validate_connection_files():
    """Validate connection files for Jules"""
    files = ["ai_agent_connection.json", "ai_agent_connection.txt"]
    all_passed = True
    
    for file in files:
        if os.path.exists(file):
            if file.endswith(".json"):
                try:
                    with open(file, 'r') as f:
                        data = json.load(f)
                    
                    # Check required fields
                    required = ["ssh_config", "capabilities", "security"]
                    has_required = all(field in data for field in required)
                    
                    if has_required:
                        print_test(f"Connection File: {file}", True)
                        
                        # Check capabilities
                        caps = data.get("capabilities", [])
                        essential_caps = ["command_execution", "file_operations", "environment_setup"]
                        has_essential = all(cap in caps for cap in essential_caps)
                        print_test("Essential Capabilities", has_essential, f"{len(caps)} capabilities")
                        
                        # Check security settings
                        security = data.get("security", {})
                        ai_mode = security.get("ai_agent_mode", False)
                        bypass = security.get("bypass_security_available", False)
                        print_test("Security Configuration", ai_mode and bypass)
                    else:
                        print_test(f"Connection File: {file}", False, "Missing required fields")
                        all_passed = False
                
                except json.JSONDecodeError:
                    print_test(f"Connection File: {file}", False, "Invalid JSON")
                    all_passed = False
            else:
                print_test(f"Connection File: {file}", True)
        else:
            print_test(f"Connection File: {file}", False, "File not found")
            all_passed = False
    
    return all_passed

def validate_mcp_server():
    """Validate MCP server can be imported"""
    try:
        # Try to import the server
        import enhanced_mcp_hardware_server
        print_test("MCP Server Import", True)
        
        # Check if security validator is available
        try:
            from security_validator import security_validator
            print_test("Security Validator", True)
        except ImportError:
            print_test("Security Validator", False, "Not available")
        
        return True
    except ImportError as e:
        print_test("MCP Server Import", False, str(e))
        return False

def validate_documentation():
    """Validate Jules-specific documentation exists"""
    docs = [
        "AGENTS.md",
        "JULES_INTEGRATION_GUIDE.md",
        "AI_AGENT_USAGE_GUIDE.md",
        "README.md"
    ]
    
    all_passed = True
    for doc in docs:
        exists = os.path.exists(doc)
        print_test(f"Documentation: {doc}", exists)
        if not exists:
            all_passed = False
    
    return all_passed

def validate_hardware_info():
    """Validate hardware information can be gathered"""
    cpu_count = os.cpu_count()
    print_test("CPU Detection", cpu_count is not None, f"{cpu_count} cores")
    
    # Check for GPU
    success, output = run_command("nvidia-smi --query-gpu=name --format=csv,noheader")
    if success and output.strip():
        print_test("GPU Detection", True, output.strip().split('\n')[0])
    else:
        print_test("GPU Detection", False, "No NVIDIA GPU detected (optional)")
    
    # Check Docker
    success, _ = run_command("docker --version")
    print_test("Docker Available", success, "(optional)")
    
    return True

def main():
    """Main validation function"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}Jules Setup Validation{Colors.END}".center(70))
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")
    
    results = {}
    
    print(f"{Colors.BOLD}1. Python Environment{Colors.END}")
    results['python'] = validate_python_version()
    results['dependencies'] = validate_dependencies()
    print()
    
    print(f"{Colors.BOLD}2. SSH Configuration{Colors.END}")
    results['ssh_keys'] = validate_ssh_keys()
    results['ssh_server'] = validate_ssh_server()
    results['jules_user'] = validate_jules_user()
    print()
    
    print(f"{Colors.BOLD}3. MCP Server Configuration{Colors.END}")
    results['mcp_config'] = validate_mcp_config()
    results['connection_files'] = validate_connection_files()
    results['mcp_server'] = validate_mcp_server()
    print()
    
    print(f"{Colors.BOLD}4. Documentation{Colors.END}")
    results['documentation'] = validate_documentation()
    print()
    
    print(f"{Colors.BOLD}5. Hardware Information{Colors.END}")
    results['hardware'] = validate_hardware_info()
    print()
    
    # Summary
    print(f"{Colors.BOLD}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}Validation Summary{Colors.END}")
    print(f"{Colors.BOLD}{'='*60}{Colors.END}")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    percentage = (passed / total) * 100
    
    print(f"\nTests Passed: {passed}/{total} ({percentage:.0f}%)")
    
    if percentage == 100:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ All validations passed!{Colors.END}")
        print(f"{Colors.GREEN}Your setup is ready for Jules integration.{Colors.END}")
        print(f"\n{Colors.BOLD}Next steps:{Colors.END}")
        print(f"  1. Start MCP server: python enhanced_mcp_hardware_server.py")
        print(f"  2. Share ai_agent_connection.json with Jules")
        print(f"  3. See JULES_INTEGRATION_GUIDE.md for workflows")
        return 0
    elif percentage >= 80:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}⚠ Most validations passed{Colors.END}")
        print(f"{Colors.YELLOW}Your setup should work, but some optional features may be unavailable.{Colors.END}")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}✗ Setup incomplete{Colors.END}")
        print(f"{Colors.RED}Please fix the failed validations before using with Jules.{Colors.END}")
        print(f"\n{Colors.BOLD}Troubleshooting:{Colors.END}")
        print(f"  • Run setup again: python setup_for_jules.py")
        print(f"  • Check TROUBLESHOOTING.md for common issues")
        print(f"  • Review logs: tail -f mcp-hardware-server.log")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Validation interrupted{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Validation error: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

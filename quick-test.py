#!/usr/bin/env python3
"""
Quick Test - Verify Jules Hardware Access Setup
Tests all components and provides clear pass/fail output
"""

import os
import sys
import subprocess
import json
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_test(name, passed, message=""):
    """Print test result"""
    icon = f"{Colors.GREEN}✓{Colors.END}" if passed else f"{Colors.RED}✗{Colors.END}"
    status = f"{Colors.GREEN}PASS{Colors.END}" if passed else f"{Colors.RED}FAIL{Colors.END}"
    print(f"{icon} {name}: {status}")
    if message:
        print(f"  {Colors.YELLOW}→{Colors.END} {message}")

def test_docker_available():
    """Test if Docker is available"""
    try:
        result = subprocess.run(['docker', '--version'], 
                              capture_output=True, timeout=5)
        return result.returncode == 0, "Docker is installed"
    except:
        return False, "Docker not found. Install from https://docker.com"

def test_docker_running():
    """Test if Docker daemon is running"""
    try:
        result = subprocess.run(['docker', 'ps'], 
                              capture_output=True, timeout=5)
        return result.returncode == 0, "Docker daemon is running"
    except:
        return False, "Docker daemon not running. Start Docker Desktop"

def test_docker_container():
    """Test if jules-agent container exists"""
    try:
        result = subprocess.run(
            ['docker', 'ps', '-a', '--filter', 'name=jules-agent', '--format', '{{.Names}}'],
            capture_output=True, text=True, timeout=5
        )
        exists = 'jules-agent' in result.stdout
        if exists:
            # Check if running
            result = subprocess.run(
                ['docker', 'ps', '--filter', 'name=jules-agent', '--format', '{{.Names}}'],
                capture_output=True, text=True, timeout=5
            )
            running = 'jules-agent' in result.stdout
            if running:
                return True, "Container is running"
            else:
                return False, "Container exists but not running. Run: docker-compose up -d"
        return False, "Container not found. Run: cd docker && ./setup.sh"
    except:
        return False, "Could not check container status"

def test_generated_files():
    """Test if generated files exist"""
    docker_files = Path('generated_files/docker')
    native_files = Path('generated_files/native')
    
    if docker_files.exists() or native_files.exists():
        if docker_files.exists():
            return True, f"Docker files found in {docker_files}"
        else:
            return True, f"Native files found in {native_files}"
    return False, "No generated files. Run: python setup.py"

def test_connection_files():
    """Test if connection files are properly formatted"""
    docker_conn = Path('generated_files/docker/.jules/connection.json')
    native_conn = Path('generated_files/native/.jules/connection.json')
    
    conn_file = docker_conn if docker_conn.exists() else native_conn
    
    if not conn_file.exists():
        return False, "connection.json not found"
    
    try:
        with open(conn_file, 'r') as f:
            data = json.load(f)
        
        required = ['ssh_hostname', 'username']
        missing = [k for k in required if k not in data]
        
        if missing:
            return False, f"Missing fields: {', '.join(missing)}"
        
        return True, f"Connection file valid: {conn_file}"
    except json.JSONDecodeError:
        return False, "connection.json is not valid JSON"
    except Exception as e:
        return False, f"Error reading connection file: {e}"

def test_tunnel_running():
    """Test if tunnel is running"""
    # Check for cloudflared
    try:
        result = subprocess.run(['pgrep', 'cloudflared'],
                              capture_output=True, timeout=5)
        if result.returncode == 0:
            return True, "Cloudflare tunnel is running"
    except:
        pass
    
    # Check for ngrok
    try:
        result = subprocess.run(['pgrep', 'ngrok'],
                              capture_output=True, timeout=5)
        if result.returncode == 0:
            return True, "ngrok tunnel is running"
    except:
        pass
    
    # Check Docker container tunnel
    try:
        result = subprocess.run(
            ['docker', 'exec', 'jules-agent', 'pgrep', 'cloudflared'],
            capture_output=True, timeout=5
        )
        if result.returncode == 0:
            return True, "Tunnel running in Docker container"
    except:
        pass
    
    return False, "No tunnel detected. Check: python tunnel_manager.py status"

def test_ssh_service():
    """Test if SSH service is running"""
    # Check native SSH
    try:
        if sys.platform == 'darwin':
            result = subprocess.run(['launchctl', 'list'],
                                  capture_output=True, text=True, timeout=5)
            if 'com.openssh.sshd' in result.stdout:
                return True, "SSH service running (macOS)"
        else:
            result = subprocess.run(['systemctl', 'is-active', 'ssh'],
                                  capture_output=True, text=True, timeout=5)
            if 'active' in result.stdout.lower():
                return True, "SSH service running (Linux)"
    except:
        pass
    
    # Check Docker SSH
    try:
        result = subprocess.run(
            ['docker', 'exec', 'jules-agent', 'systemctl', 'is-active', 'ssh'],
            capture_output=True, text=True, timeout=5
        )
        if 'active' in result.stdout.lower():
            return True, "SSH running in Docker container"
    except:
        pass
    
    return False, "SSH service not detected"

def main():
    """Run all tests"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}Jules Hardware Access - Quick Test{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")
    
    tests = [
        ("Docker Available", test_docker_available),
        ("Docker Running", test_docker_running),
        ("Jules Container", test_docker_container),
        ("Generated Files", test_generated_files),
        ("Connection Files", test_connection_files),
        ("Tunnel Running", test_tunnel_running),
        ("SSH Service", test_ssh_service),
    ]
    
    results = []
    for name, test_func in tests:
        passed, message = test_func()
        print_test(name, passed, message)
        results.append((name, passed, message))
    
    # Summary
    print(f"\n{Colors.BOLD}Summary:{Colors.END}")
    passed_count = sum(1 for _, passed, _ in results if passed)
    total_count = len(results)
    
    print(f"  Passed: {passed_count}/{total_count}")
    
    if passed_count == total_count:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ All tests passed! Your setup is ready for Jules.{Colors.END}")
        print(f"\n{Colors.BLUE}Next steps:{Colors.END}")
        print(f"  1. Copy files to your project: ./copy-to-project.sh ~/your-project")
        print(f"  2. Commit and push to GitHub")
        print(f"  3. Jules can now access your hardware!")
        return 0
    else:
        print(f"\n{Colors.YELLOW}{Colors.BOLD}⚠ Some tests failed. Please fix the issues above.{Colors.END}")
        print(f"\n{Colors.BLUE}Troubleshooting:{Colors.END}")
        print(f"  • Run: python status.py")
        print(f"  • Check: TROUBLESHOOTING.md")
        print(f"  • Setup: python setup.py")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Test cancelled{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Test failed: {e}{Colors.END}")
        sys.exit(1)

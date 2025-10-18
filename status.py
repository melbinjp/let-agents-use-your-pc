#!/usr/bin/env python3
"""
Jules Hardware Access - Status Dashboard
Simple monitoring for Docker and/or Native installations
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime
import time

class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'
    CYAN = '\033[96m'

def clear_screen():
    """Clear terminal screen"""
    os.system('cls' if os.name == 'nt' else 'clear')

def print_header(text):
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(70)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")

def print_section(text):
    print(f"\n{Colors.BOLD}{Colors.CYAN}{text}{Colors.END}")
    print(f"{Colors.CYAN}{'─'*70}{Colors.END}")

def get_status_icon(is_ok):
    """Get status icon"""
    return f"{Colors.GREEN}●{Colors.END}" if is_ok else f"{Colors.RED}●{Colors.END}"

def check_docker_status():
    """Check Docker installation status"""
    status = {
        'installed': False,
        'running': False,
        'container_running': False,
        'container_healthy': False,
        'tunnel_active': False,
        'ssh_active': False,
        'connection_url': None
    }
    
    # Check if Docker is installed
    try:
        result = subprocess.run(['docker', '--version'], 
                              capture_output=True, text=True, timeout=5)
        status['installed'] = result.returncode == 0
    except:
        return status
    
    # Check if Docker daemon is running
    try:
        result = subprocess.run(['docker', 'ps'], 
                              capture_output=True, text=True, timeout=5)
        status['running'] = result.returncode == 0
    except:
        return status
    
    if not status['running']:
        return status
    
    # Check if jules-agent container is running
    try:
        result = subprocess.run(['docker', 'ps', '--filter', 'name=jules-agent', '--format', '{{.Names}}'],
                              capture_output=True, text=True, timeout=5)
        status['container_running'] = 'jules-agent' in result.stdout
    except:
        pass
    
    if not status['container_running']:
        return status
    
    # Check container health
    try:
        result = subprocess.run(['docker', 'inspect', '--format', '{{.State.Health.Status}}', 'jules-agent'],
                              capture_output=True, text=True, timeout=5)
        status['container_healthy'] = 'healthy' in result.stdout.lower()
    except:
        pass
    
    # Check tunnel status
    try:
        result = subprocess.run(['docker', 'exec', 'jules-agent', 'pgrep', 'cloudflared'],
                              capture_output=True, text=True, timeout=5)
        status['tunnel_active'] = result.returncode == 0
    except:
        pass
    
    # Check SSH status
    try:
        result = subprocess.run(['docker', 'exec', 'jules-agent', 'systemctl', 'is-active', 'ssh'],
                              capture_output=True, text=True, timeout=5)
        status['ssh_active'] = 'active' in result.stdout.lower()
    except:
        pass
    
    # Get connection URL
    if status['tunnel_active']:
        try:
            result = subprocess.run(['docker', 'exec', 'jules-agent', '/connection-info.sh'],
                                  capture_output=True, text=True, timeout=5)
            # Parse output for hostname
            for line in result.stdout.split('\n'):
                if 'SSH Hostname:' in line:
                    status['connection_url'] = line.split(':', 1)[1].strip()
                    break
        except:
            pass
    
    return status

def check_native_status():
    """Check native installation status"""
    status = {
        'tunnel_running': False,
        'tunnel_type': None,
        'ssh_running': False,
        'jules_user_exists': False,
        'connection_url': None
    }
    
    # Check if tunnel is running
    try:
        # Check for cloudflared
        result = subprocess.run(['pgrep', 'cloudflared'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            status['tunnel_running'] = True
            status['tunnel_type'] = 'cloudflare'
    except:
        pass
    
    if not status['tunnel_running']:
        try:
            # Check for ngrok
            result = subprocess.run(['pgrep', 'ngrok'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                status['tunnel_running'] = True
                status['tunnel_type'] = 'ngrok'
        except:
            pass
    
    if not status['tunnel_running']:
        try:
            # Check for tailscale
            result = subprocess.run(['pgrep', 'tailscaled'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                status['tunnel_running'] = True
                status['tunnel_type'] = 'tailscale'
        except:
            pass
    
    # Check SSH service
    try:
        if sys.platform == 'darwin':  # macOS
            result = subprocess.run(['launchctl', 'list'],
                                  capture_output=True, text=True, timeout=5)
            status['ssh_running'] = 'com.openssh.sshd' in result.stdout
        else:  # Linux
            result = subprocess.run(['systemctl', 'is-active', 'ssh'],
                                  capture_output=True, text=True, timeout=5)
            status['ssh_running'] = 'active' in result.stdout.lower()
    except:
        pass
    
    # Check if jules user exists
    try:
        result = subprocess.run(['id', 'jules'],
                              capture_output=True, text=True, timeout=5)
        status['jules_user_exists'] = result.returncode == 0
    except:
        pass
    
    # Try to get connection URL from generated files
    try:
        conn_file = Path('generated_files/native/.jules/connection.json')
        if conn_file.exists():
            data = json.loads(conn_file.read_text())
            status['connection_url'] = data.get('hostname') or data.get('ssh_hostname')
    except:
        pass
    
    return status

def display_docker_status(status):
    """Display Docker status"""
    print_section("🐳 Docker Status")
    
    print(f"{get_status_icon(status['installed'])} Docker Installed: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['installed'] else f"{Colors.RED}No{Colors.END}")
    
    if not status['installed']:
        print(f"\n{Colors.YELLOW}Install Docker: https://www.docker.com/products/docker-desktop{Colors.END}")
        return
    
    print(f"{get_status_icon(status['running'])} Docker Running: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['running'] else f"{Colors.RED}No{Colors.END}")
    
    if not status['running']:
        print(f"\n{Colors.YELLOW}Start Docker Desktop or run: sudo systemctl start docker{Colors.END}")
        return
    
    print(f"{get_status_icon(status['container_running'])} Container Running: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['container_running'] else f"{Colors.RED}No{Colors.END}")
    
    if not status['container_running']:
        print(f"\n{Colors.YELLOW}Start container: cd docker && docker-compose up -d{Colors.END}")
        return
    
    print(f"{get_status_icon(status['container_healthy'])} Container Health: ", end='')
    print(f"{Colors.GREEN}Healthy{Colors.END}" if status['container_healthy'] else f"{Colors.YELLOW}Starting...{Colors.END}")
    
    print(f"{get_status_icon(status['tunnel_active'])} Tunnel Active: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['tunnel_active'] else f"{Colors.RED}No{Colors.END}")
    
    print(f"{get_status_icon(status['ssh_active'])} SSH Active: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['ssh_active'] else f"{Colors.RED}No{Colors.END}")
    
    if status['connection_url']:
        print(f"\n{Colors.BOLD}Connection URL:{Colors.END} {Colors.CYAN}{status['connection_url']}{Colors.END}")
        print(f"{Colors.BOLD}Connect with:{Colors.END} ssh jules@{status['connection_url']}")
    
    # Overall status
    all_ok = all([status['container_running'], status['tunnel_active'], status['ssh_active']])
    print(f"\n{Colors.BOLD}Overall Status:{Colors.END} ", end='')
    if all_ok:
        print(f"{Colors.GREEN}✓ Ready for Jules!{Colors.END}")
    else:
        print(f"{Colors.YELLOW}⚠ Needs attention{Colors.END}")

def display_native_status(status):
    """Display native status"""
    print_section("🖥️  Native Status")
    
    print(f"{get_status_icon(status['tunnel_running'])} Tunnel Running: ", end='')
    if status['tunnel_running']:
        print(f"{Colors.GREEN}Yes ({status['tunnel_type']}){Colors.END}")
    else:
        print(f"{Colors.RED}No{Colors.END}")
        print(f"\n{Colors.YELLOW}Start tunnel: python tunnel_manager.py start{Colors.END}")
        return
    
    print(f"{get_status_icon(status['ssh_running'])} SSH Running: ", end='')
    print(f"{Colors.GREEN}Yes{Colors.END}" if status['ssh_running'] else f"{Colors.RED}No{Colors.END}")
    
    if not status['ssh_running']:
        print(f"\n{Colors.YELLOW}Start SSH: sudo systemctl start ssh{Colors.END}")
    
    print(f"{get_status_icon(status['jules_user_exists'])} Jules User: ", end='')
    print(f"{Colors.GREEN}Exists{Colors.END}" if status['jules_user_exists'] else f"{Colors.RED}Not found{Colors.END}")
    
    if not status['jules_user_exists']:
        print(f"\n{Colors.YELLOW}Run setup: python jules_setup.py{Colors.END}")
    
    if status['connection_url']:
        print(f"\n{Colors.BOLD}Connection URL:{Colors.END} {Colors.CYAN}{status['connection_url']}{Colors.END}")
        print(f"{Colors.BOLD}Connect with:{Colors.END} ssh jules@{status['connection_url']}")
    
    # Overall status
    all_ok = all([status['tunnel_running'], status['ssh_running'], status['jules_user_exists']])
    print(f"\n{Colors.BOLD}Overall Status:{Colors.END} ", end='')
    if all_ok:
        print(f"{Colors.GREEN}✓ Ready for Jules!{Colors.END}")
    else:
        print(f"{Colors.YELLOW}⚠ Needs attention{Colors.END}")

def display_quick_actions():
    """Display quick action commands"""
    print_section("⚡ Quick Actions")
    
    print(f"{Colors.BOLD}Docker:{Colors.END}")
    print(f"  • View logs: {Colors.CYAN}docker-compose logs -f{Colors.END}")
    print(f"  • Restart: {Colors.CYAN}docker-compose restart{Colors.END}")
    print(f"  • Stop: {Colors.CYAN}docker-compose down{Colors.END}")
    print(f"  • Shell: {Colors.CYAN}docker-compose exec jules-agent bash{Colors.END}")
    
    print(f"\n{Colors.BOLD}Native:{Colors.END}")
    print(f"  • Check tunnel: {Colors.CYAN}python tunnel_manager.py status{Colors.END}")
    print(f"  • Validate: {Colors.CYAN}python validate_jules_setup.py{Colors.END}")
    print(f"  • Test connection: {Colors.CYAN}python test_ai_agent_connection.py{Colors.END}")
    
    print(f"\n{Colors.BOLD}Files:{Colors.END}")
    print(f"  • Docker files: {Colors.CYAN}generated_files/docker/{Colors.END}")
    print(f"  • Native files: {Colors.CYAN}generated_files/native/{Colors.END}")

def display_file_locations():
    """Display file locations"""
    print_section("📁 File Locations")
    
    docker_files = Path('generated_files/docker')
    native_files = Path('generated_files/native')
    
    if docker_files.exists():
        print(f"{Colors.GREEN}●{Colors.END} Docker files: {Colors.CYAN}{docker_files}{Colors.END}")
        if (docker_files / '.jules').exists():
            print(f"  • Connection config: .jules/connection.json")
        if (docker_files / 'AGENTS.md').exists():
            print(f"  • Agent capabilities: AGENTS.md")
    
    if native_files.exists():
        print(f"{Colors.GREEN}●{Colors.END} Native files: {Colors.CYAN}{native_files}{Colors.END}")
        if (native_files / '.jules').exists():
            print(f"  • Connection config: .jules/connection.json")
        if (native_files / 'AGENTS.md').exists():
            print(f"  • Agent capabilities: AGENTS.md")
    
    if not docker_files.exists() and not native_files.exists():
        print(f"{Colors.YELLOW}No generated files found. Run setup first.{Colors.END}")

def main():
    """Main status dashboard"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Jules Hardware Access Status Dashboard')
    parser.add_argument('--watch', action='store_true', help='Watch mode (refresh every 5 seconds)')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    args = parser.parse_args()
    
    try:
        while True:
            if not args.json:
                if args.watch:
                    clear_screen()
                
                print_header("Jules Hardware Access - Status Dashboard")
                print(f"{Colors.BOLD}Last updated:{Colors.END} {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            
            # Check setup config
            config_file = Path('configs/setup_config.json')
            if config_file.exists():
                config = json.loads(config_file.read_text())
                docker_enabled = config.get('docker_enabled', False)
                native_enabled = config.get('native_enabled', False)
            else:
                # Auto-detect
                docker_enabled = Path('docker/docker-compose.yml').exists()
                native_enabled = Path('jules_setup.py').exists()
            
            # Collect status
            status_data = {}
            
            if docker_enabled:
                docker_status = check_docker_status()
                status_data['docker'] = docker_status
                if not args.json:
                    display_docker_status(docker_status)
            
            if native_enabled:
                native_status = check_native_status()
                status_data['native'] = native_status
                if not args.json:
                    display_native_status(native_status)
            
            if args.json:
                print(json.dumps(status_data, indent=2))
                break
            
            # Display additional info
            display_file_locations()
            display_quick_actions()
            
            print(f"\n{Colors.BOLD}Press Ctrl+C to exit{Colors.END}")
            
            if not args.watch:
                break
            
            time.sleep(5)
    
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Exiting...{Colors.END}")
        return 0
    except Exception as e:
        print(f"\n{Colors.RED}Error: {e}{Colors.END}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

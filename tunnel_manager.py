#!/usr/bin/env python3
"""
Tunnel Manager - Flexible tunnel solution with multiple providers
Supports: ngrok, Cloudflare, Tailscale, and localhost
"""

import os
import sys
import json
import subprocess
import time
import requests
import platform
from pathlib import Path
from typing import Optional, Dict, Any

class Colors:
    GREEN = '\033[92m'
    BLUE = '\033[94m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

class TunnelManager:
    """Manages different tunnel providers with automatic fallback"""
    
    def __init__(self):
        self.tunnel_process = None
        self.tunnel_url = None
        self.tunnel_type = None
        self.config_file = "tunnel_config.json"
        
    def detect_available_tunnels(self) -> Dict[str, bool]:
        """Detect which tunnel providers are available"""
        available = {
            'ngrok': self._check_ngrok(),
            'cloudflare': self._check_cloudflare(),
            'tailscale': self._check_tailscale(),
            'localhost': True  # Always available
        }
        return available
    
    def _check_ngrok(self) -> bool:
        """Check if ngrok is installed"""
        try:
            result = subprocess.run(['ngrok', 'version'], 
                                  capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def _check_cloudflare(self) -> bool:
        """Check if cloudflared is installed"""
        try:
            result = subprocess.run(['cloudflared', 'version'], 
                                  capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def _check_tailscale(self) -> bool:
        """Check if Tailscale is installed and running"""
        try:
            if platform.system() == 'Windows':
                result = subprocess.run(['tailscale', 'status'], 
                                      capture_output=True, timeout=5)
            else:
                result = subprocess.run(['tailscale', 'status'], 
                                      capture_output=True, timeout=5)
            return result.returncode == 0
        except:
            return False
    
    def start_tunnel(self, preferred: str = 'auto', port: int = 22) -> Optional[str]:
        """
        Start a tunnel with the preferred provider
        
        Args:
            preferred: 'ngrok', 'cloudflare', 'tailscale', 'localhost', or 'auto'
            port: Local port to tunnel (default: 22 for SSH)
        
        Returns:
            Tunnel URL or None if failed
        """
        available = self.detect_available_tunnels()
        
        # Auto-select best available
        if preferred == 'auto':
            if available['ngrok']:
                preferred = 'ngrok'
            elif available['cloudflare']:
                preferred = 'cloudflare'
            elif available['tailscale']:
                preferred = 'tailscale'
            else:
                preferred = 'localhost'
        
        # Start the selected tunnel
        if preferred == 'ngrok' and available['ngrok']:
            return self._start_ngrok(port)
        elif preferred == 'cloudflare' and available['cloudflare']:
            return self._start_cloudflare(port)
        elif preferred == 'tailscale' and available['tailscale']:
            return self._get_tailscale_url()
        elif preferred == 'localhost':
            return self._get_localhost_url(port)
        else:
            print(f"{Colors.RED}✗ {preferred} not available{Colors.END}")
            return None
    
    def _start_ngrok(self, port: int) -> Optional[str]:
        """Start ngrok tunnel"""
        print(f"{Colors.BLUE}Starting ngrok tunnel...{Colors.END}")
        
        try:
            # Start ngrok
            self.tunnel_process = subprocess.Popen(
                ['ngrok', 'tcp', str(port), '--log', 'stdout'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait for tunnel to start
            time.sleep(3)
            
            # Get tunnel URL from ngrok API
            try:
                response = requests.get('http://localhost:4040/api/tunnels', timeout=5)
                if response.status_code == 200:
                    data = response.json()
                    if data.get('tunnels'):
                        tunnel = data['tunnels'][0]
                        url = tunnel['public_url']
                        # Extract hostname and port
                        url = url.replace('tcp://', '')
                        self.tunnel_url = url
                        self.tunnel_type = 'ngrok'
                        self._save_config()
                        print(f"{Colors.GREEN}✓ ngrok tunnel started: {url}{Colors.END}")
                        return url
            except:
                pass
            
            print(f"{Colors.RED}✗ Could not get ngrok tunnel URL{Colors.END}")
            return None
            
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to start ngrok: {e}{Colors.END}")
            return None
    
    def _start_cloudflare(self, port: int) -> Optional[str]:
        """Start Cloudflare tunnel"""
        print(f"{Colors.BLUE}Starting Cloudflare tunnel...{Colors.END}")
        
        try:
            # Start cloudflared quick tunnel
            self.tunnel_process = subprocess.Popen(
                ['cloudflared', 'tunnel', '--url', f'tcp://localhost:{port}'],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait and parse output for URL
            time.sleep(5)
            
            # Try to read the tunnel URL from output
            # Note: This is a temporary tunnel, URL will be in stderr
            for line in self.tunnel_process.stderr:
                if 'trycloudflare.com' in line:
                    # Extract URL
                    import re
                    match = re.search(r'https://([a-z0-9-]+\.trycloudflare\.com)', line)
                    if match:
                        url = match.group(1)
                        self.tunnel_url = url
                        self.tunnel_type = 'cloudflare'
                        self._save_config()
                        print(f"{Colors.GREEN}✓ Cloudflare tunnel started: {url}{Colors.END}")
                        return url
                    break
            
            print(f"{Colors.YELLOW}⚠ Cloudflare tunnel started but URL not detected{Colors.END}")
            print(f"{Colors.YELLOW}  Check cloudflared output for tunnel URL{Colors.END}")
            return None
            
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to start Cloudflare tunnel: {e}{Colors.END}")
            return None
    
    def _get_tailscale_url(self) -> Optional[str]:
        """Get Tailscale IP"""
        print(f"{Colors.BLUE}Getting Tailscale address...{Colors.END}")
        
        try:
            result = subprocess.run(['tailscale', 'ip', '-4'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                ip = result.stdout.strip()
                self.tunnel_url = ip
                self.tunnel_type = 'tailscale'
                self._save_config()
                print(f"{Colors.GREEN}✓ Tailscale address: {ip}{Colors.END}")
                return ip
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to get Tailscale address: {e}{Colors.END}")
        
        return None
    
    def _get_localhost_url(self, port: int) -> str:
        """Get localhost URL (for local testing)"""
        url = f"localhost:{port}"
        self.tunnel_url = url
        self.tunnel_type = 'localhost'
        self._save_config()
        print(f"{Colors.YELLOW}⚠ Using localhost (local network only): {url}{Colors.END}")
        return url
    
    def stop_tunnel(self):
        """Stop the running tunnel"""
        if self.tunnel_process:
            print(f"{Colors.BLUE}Stopping tunnel...{Colors.END}")
            self.tunnel_process.terminate()
            try:
                self.tunnel_process.wait(timeout=5)
            except:
                self.tunnel_process.kill()
            self.tunnel_process = None
            print(f"{Colors.GREEN}✓ Tunnel stopped{Colors.END}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get current tunnel status"""
        return {
            'running': self.tunnel_process is not None,
            'type': self.tunnel_type,
            'url': self.tunnel_url,
            'available_providers': self.detect_available_tunnels()
        }
    
    def _save_config(self):
        """Save tunnel configuration"""
        config = {
            'type': self.tunnel_type,
            'url': self.tunnel_url,
            'last_updated': time.time()
        }
        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=2)
    
    def load_config(self) -> Optional[Dict[str, Any]]:
        """Load saved tunnel configuration"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    return json.load(f)
        except:
            pass
        return None

def install_tunnel_provider(provider: str) -> bool:
    """Install a tunnel provider"""
    print(f"{Colors.BLUE}Installing {provider}...{Colors.END}")
    
    system = platform.system()
    
    if provider == 'ngrok':
        print(f"{Colors.YELLOW}Please install ngrok:{Colors.END}")
        if system == 'Windows':
            print("  1. Download from: https://ngrok.com/download")
            print("  2. Extract ngrok.exe to a folder in your PATH")
            print("  3. Run: ngrok authtoken YOUR_TOKEN (get token from ngrok.com)")
        elif system == 'Darwin':
            print("  brew install ngrok/ngrok/ngrok")
            print("  ngrok authtoken YOUR_TOKEN")
        else:
            print("  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null")
            print("  echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | sudo tee /etc/apt/sources.list.d/ngrok.list")
            print("  sudo apt update && sudo apt install ngrok")
            print("  ngrok authtoken YOUR_TOKEN")
        return False
    
    elif provider == 'cloudflare':
        print(f"{Colors.YELLOW}Please install cloudflared:{Colors.END}")
        if system == 'Windows':
            print("  Download from: https://github.com/cloudflare/cloudflared/releases")
        elif system == 'Darwin':
            print("  brew install cloudflared")
        else:
            print("  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared")
            print("  chmod +x cloudflared")
            print("  sudo mv cloudflared /usr/local/bin/")
        return False
    
    elif provider == 'tailscale':
        print(f"{Colors.YELLOW}Please install Tailscale:{Colors.END}")
        print("  Visit: https://tailscale.com/download")
        if system == 'Windows':
            print("  Download and run the Windows installer")
        elif system == 'Darwin':
            print("  Download from Mac App Store or: brew install tailscale")
        else:
            print("  curl -fsSL https://tailscale.com/install.sh | sh")
        return False
    
    return False

def interactive_setup():
    """Interactive tunnel setup for first-time users"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'Tunnel Setup Wizard'.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")
    
    print("Let's set up a tunnel so Jules can access your hardware!\n")
    
    # Detect available tunnels
    manager = TunnelManager()
    available = manager.detect_available_tunnels()
    
    print(f"{Colors.BOLD}Available tunnel providers:{Colors.END}\n")
    
    options = []
    option_num = 1
    
    if available['ngrok']:
        print(f"  {Colors.GREEN}✓{Colors.END} {option_num}. ngrok (Recommended for personal use)")
        print(f"     - Easiest setup")
        print(f"     - Free tier is great")
        print(f"     - Perfect for testing\n")
        options.append('ngrok')
        option_num += 1
    else:
        print(f"  {Colors.YELLOW}○{Colors.END} {option_num}. ngrok (Not installed)")
        print(f"     - Install: https://ngrok.com/download")
        print(f"     - Best for: Personal projects\n")
        options.append('ngrok')
        option_num += 1
    
    if available['cloudflare']:
        print(f"  {Colors.GREEN}✓{Colors.END} {option_num}. Cloudflare (Recommended for enterprise)")
        print(f"     - Your own domain")
        print(f"     - Enterprise features")
        print(f"     - DDoS protection\n")
        options.append('cloudflare')
        option_num += 1
    else:
        print(f"  {Colors.YELLOW}○{Colors.END} {option_num}. Cloudflare (Not installed)")
        print(f"     - Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/")
        print(f"     - Best for: Production/Enterprise\n")
        options.append('cloudflare')
        option_num += 1
    
    if available['tailscale']:
        print(f"  {Colors.GREEN}✓{Colors.END} {option_num}. Tailscale (Recommended for always-on)")
        print(f"     - Zero configuration")
        print(f"     - Always available")
        print(f"     - Most reliable\n")
        options.append('tailscale')
        option_num += 1
    else:
        print(f"  {Colors.YELLOW}○{Colors.END} {option_num}. Tailscale (Not installed)")
        print(f"     - Install: https://tailscale.com/download")
        print(f"     - Best for: 24/7 access\n")
        options.append('tailscale')
        option_num += 1
    
    print(f"  {option_num}. localhost (Local network only - for testing)\n")
    options.append('localhost')
    
    # Get user choice
    while True:
        try:
            choice = input(f"{Colors.BOLD}Choose a tunnel provider (1-{len(options)}): {Colors.END}")
            choice_num = int(choice)
            if 1 <= choice_num <= len(options):
                selected = options[choice_num - 1]
                break
            else:
                print(f"{Colors.RED}Please enter a number between 1 and {len(options)}{Colors.END}")
        except ValueError:
            print(f"{Colors.RED}Please enter a valid number{Colors.END}")
        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}Setup cancelled{Colors.END}")
            return None
    
    # Check if selected provider is available
    if selected != 'localhost' and not available[selected]:
        print(f"\n{Colors.YELLOW}⚠ {selected} is not installed yet{Colors.END}")
        print(f"\n{Colors.BOLD}Installation instructions:{Colors.END}")
        install_tunnel_provider(selected)
        print(f"\n{Colors.BLUE}After installing, run this script again!{Colors.END}")
        return None
    
    # Start the tunnel
    print(f"\n{Colors.BLUE}Starting {selected} tunnel...{Colors.END}\n")
    url = manager.start_tunnel(selected, 22)
    
    if url:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ Success!{Colors.END}")
        print(f"\n{Colors.BOLD}Your tunnel is ready:{Colors.END}")
        print(f"  {Colors.GREEN}{url}{Colors.END}")
        print(f"\n{Colors.BOLD}Next steps:{Colors.END}")
        print(f"  1. Keep this terminal open")
        print(f"  2. Run setup: python setup_for_jules.py")
        print(f"  3. The setup will use this tunnel automatically")
        print(f"\n{Colors.BLUE}Press Ctrl+C to stop the tunnel{Colors.END}\n")
        
        # Save for setup script to use
        config = {
            'provider': selected,
            'url': url,
            'port': 22,
            'timestamp': time.time()
        }
        with open('active_tunnel.json', 'w') as f:
            json.dump(config, f, indent=2)
        
        return manager
    else:
        print(f"\n{Colors.RED}✗ Failed to start tunnel{Colors.END}")
        print(f"\n{Colors.YELLOW}Troubleshooting:{Colors.END}")
        if selected == 'ngrok':
            print(f"  1. Make sure you have an ngrok account")
            print(f"  2. Run: ngrok authtoken YOUR_TOKEN")
            print(f"  3. Try again")
        elif selected == 'cloudflare':
            print(f"  1. Make sure cloudflared is installed")
            print(f"  2. Try: cloudflared tunnel --url tcp://localhost:22")
        elif selected == 'tailscale':
            print(f"  1. Make sure Tailscale is running")
            print(f"  2. Run: sudo tailscale up")
            print(f"  3. Try again")
        return None

def main():
    """Main CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Tunnel Manager for MCP Hardware Server',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive setup (recommended for first time)
  python tunnel_manager.py setup
  
  # Start tunnel with auto-detection
  python tunnel_manager.py start
  
  # Start specific provider
  python tunnel_manager.py start --provider ngrok
  python tunnel_manager.py start --provider cloudflare
  python tunnel_manager.py start --provider tailscale
  
  # Check status
  python tunnel_manager.py status
  
  # Install a provider
  python tunnel_manager.py install --provider ngrok
        """
    )
    parser.add_argument('action', 
                       choices=['setup', 'start', 'stop', 'status', 'install'],
                       help='Action to perform')
    parser.add_argument('--provider', 
                       choices=['auto', 'ngrok', 'cloudflare', 'tailscale', 'localhost'],
                       default='auto', 
                       help='Tunnel provider to use')
    parser.add_argument('--port', type=int, default=22, 
                       help='Local port to tunnel (default: 22 for SSH)')
    
    args = parser.parse_args()
    
    manager = TunnelManager()
    
    if args.action == 'setup':
        # Interactive setup wizard
        manager = interactive_setup()
        if manager:
            try:
                # Keep running
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                manager.stop_tunnel()
                print(f"\n{Colors.GREEN}Tunnel stopped{Colors.END}")
        sys.exit(0 if manager else 1)
    
    elif args.action == 'start':
        url = manager.start_tunnel(args.provider, args.port)
        if url:
            print(f"\n{Colors.GREEN}{Colors.BOLD}Tunnel URL: {url}{Colors.END}")
            print(f"{Colors.BLUE}Keep this terminal open to maintain the tunnel{Colors.END}")
            try:
                # Keep running
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                manager.stop_tunnel()
        else:
            print(f"\n{Colors.RED}Failed to start tunnel{Colors.END}")
            print(f"{Colors.YELLOW}Try: python tunnel_manager.py install --provider {args.provider}{Colors.END}")
            sys.exit(1)
    
    elif args.action == 'stop':
        manager.stop_tunnel()
    
    elif args.action == 'status':
        status = manager.get_status()
        print(f"\n{Colors.BOLD}Tunnel Status:{Colors.END}")
        print(f"  Running: {status['running']}")
        print(f"  Type: {status['type']}")
        print(f"  URL: {status['url']}")
        print(f"\n{Colors.BOLD}Available Providers:{Colors.END}")
        for provider, available in status['available_providers'].items():
            status_icon = f"{Colors.GREEN}✓{Colors.END}" if available else f"{Colors.RED}✗{Colors.END}"
            print(f"  {status_icon} {provider}")
    
    elif args.action == 'install':
        install_tunnel_provider(args.provider)

if __name__ == '__main__':
    main()

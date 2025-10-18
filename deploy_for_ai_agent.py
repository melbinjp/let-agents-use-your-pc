#!/usr/bin/env python3
"""
Deploy MCP Hardware Server for Remote AI Agent Access
One-click deployment script for users to make their hardware available to AI agents
"""

import os
import sys
import json
import subprocess
import platform
import socket
import secrets
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional

class AIAgentDeployment:
    """Handles deployment of MCP server for AI agent access"""
    
    def __init__(self):
        self.system_info = self.detect_system()
        self.config = {}
        self.ssh_keys = {}
        self.tunnel_info = {}
        
    def detect_system(self) -> Dict[str, str]:
        """Detect system information"""
        return {
            'os': platform.system(),
            'architecture': platform.machine(),
            'python_version': platform.python_version(),
            'hostname': socket.gethostname(),
            'platform': platform.platform()
        }
    
    def print_banner(self):
        """Print deployment banner"""
        print("🤖 AI Agent Hardware Access - Deployment")
        print("=" * 50)
        print(f"System: {self.system_info['os']} {self.system_info['architecture']}")
        print(f"Hostname: {self.system_info['hostname']}")
        print(f"Python: {self.system_info['python_version']}")
        print("=" * 50)
        print()
        print("This will set up your device to be accessible by remote AI agents.")
        print("The AI agent will be able to:")
        print("  • Execute commands with full system access")
        print("  • Install software and manage packages")
        print("  • Access files and manage data")
        print("  • Use Docker and containers")
        print("  • Monitor system resources")
        print("  • Run development environments")
        print()
    
    def check_dependencies(self) -> bool:
        """Check and install required dependencies"""
        print("📦 Checking dependencies...")
        
        required_packages = [
            'paramiko', 'requests', 'asyncio'
        ]
        
        missing = []
        for package in required_packages:
            try:
                __import__(package.replace('-', '_'))
            except ImportError:
                missing.append(package)
        
        if missing:
            print(f"Installing missing packages: {', '.join(missing)}")
            try:
                subprocess.check_call([
                    sys.executable, '-m', 'pip', 'install'
                ] + missing)
                print("✅ Dependencies installed")
            except subprocess.CalledProcessError:
                print("❌ Failed to install dependencies")
                return False
        else:
            print("✅ All dependencies available")
        
        return True
    
    def generate_ssh_keys(self) -> bool:
        """Generate SSH keys for AI agent access"""
        print("\n🔐 Generating SSH keys for AI agent...")
        
        # Generate unique key names
        key_name = f"ai_agent_{secrets.token_hex(4)}"
        private_key_path = f"{key_name}_key"
        public_key_path = f"{private_key_path}.pub"
        
        try:
            # Generate Ed25519 key pair (most secure and compatible)
            subprocess.check_call([
                "ssh-keygen", 
                "-t", "ed25519",
                "-f", private_key_path,
                "-N", "",  # No passphrase for AI agent
                "-C", f"ai-agent@{self.system_info['hostname']}"
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Set proper permissions
            os.chmod(private_key_path, 0o600)
            os.chmod(public_key_path, 0o644)
            
            # Read keys
            with open(private_key_path, 'r') as f:
                private_key_content = f.read()
            
            with open(public_key_path, 'r') as f:
                public_key_content = f.read().strip()
            
            self.ssh_keys = {
                'private_key_path': private_key_path,
                'public_key_path': public_key_path,
                'private_key_content': private_key_content,
                'public_key_content': public_key_content
            }
            
            print(f"✅ SSH keys generated: {private_key_path}")
            return True
            
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("❌ Failed to generate SSH keys. Ensure ssh-keygen is available.")
            return False
    
    def setup_ssh_server(self) -> bool:
        """Set up SSH server for AI agent access"""
        print("\n🌐 Setting up SSH server...")
        
        if self.system_info['os'] == 'Windows':
            return self.setup_windows_ssh()
        else:
            return self.setup_unix_ssh()
    
    def setup_windows_ssh(self) -> bool:
        """Set up SSH on Windows"""
        try:
            # Check if OpenSSH is available
            result = subprocess.run(['ssh', '-V'], capture_output=True, text=True)
            if result.returncode != 0:
                print("❌ OpenSSH not available. Please install OpenSSH Server.")
                print("   Run: Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0")
                return False
            
            # For Windows, we'll use the existing SSH setup or guide user
            print("✅ OpenSSH detected on Windows")
            print("⚠️  Manual SSH server setup may be required on Windows")
            print("   Ensure SSH server is running and configured for key authentication")
            
            return True
            
        except FileNotFoundError:
            print("❌ SSH not available on Windows")
            return False
    
    def setup_unix_ssh(self) -> bool:
        """Set up SSH on Unix-like systems"""
        try:
            # Check if SSH server is installed
            ssh_service_names = ['ssh', 'sshd', 'openssh-server']
            ssh_installed = False
            
            for service in ssh_service_names:
                try:
                    result = subprocess.run(['systemctl', 'status', service], 
                                          capture_output=True, text=True)
                    if result.returncode == 0 or 'not found' not in result.stderr:
                        ssh_installed = True
                        break
                except:
                    continue
            
            if not ssh_installed:
                print("Installing SSH server...")
                # Try different package managers
                install_commands = [
                    ['sudo', 'apt', 'update', '&&', 'sudo', 'apt', 'install', '-y', 'openssh-server'],
                    ['sudo', 'yum', 'install', '-y', 'openssh-server'],
                    ['sudo', 'dnf', 'install', '-y', 'openssh-server']
                ]
                
                for cmd in install_commands:
                    try:
                        subprocess.check_call(cmd)
                        ssh_installed = True
                        break
                    except:
                        continue
                
                if not ssh_installed:
                    print("❌ Could not install SSH server automatically")
                    print("   Please install openssh-server manually")
                    return False
            
            # Start SSH service
            try:
                subprocess.check_call(['sudo', 'systemctl', 'enable', 'ssh'])
                subprocess.check_call(['sudo', 'systemctl', 'start', 'ssh'])
                print("✅ SSH server configured and started")
            except:
                print("⚠️  SSH server setup may require manual configuration")
            
            return True
            
        except Exception as e:
            print(f"❌ SSH setup failed: {e}")
            return False
    
    def create_ai_user(self) -> bool:
        """Create dedicated user for AI agent"""
        print("\n👤 Setting up AI agent user...")
        
        username = "aiagent"
        
        if self.system_info['os'] == 'Windows':
            # Windows user creation
            try:
                # Create user (this might require admin privileges)
                subprocess.check_call([
                    'net', 'user', username, '/add', '/passwordreq:no'
                ])
                print(f"✅ Created user: {username}")
                return True
            except subprocess.CalledProcessError:
                print("⚠️  User creation failed. Using current user for AI agent access.")
                username = os.getenv('USERNAME', 'user')
        else:
            # Unix user creation
            try:
                # Create user with home directory
                subprocess.check_call([
                    'sudo', 'useradd', '-m', '-s', '/bin/bash', username
                ])
                
                # Add to sudo group for full access
                subprocess.check_call([
                    'sudo', 'usermod', '-aG', 'sudo', username
                ])
                
                # Configure passwordless sudo
                sudo_rule = f"{username} ALL=(ALL) NOPASSWD:ALL\n"
                with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
                    f.write(sudo_rule)
                    temp_file = f.name
                
                subprocess.check_call([
                    'sudo', 'cp', temp_file, f'/etc/sudoers.d/{username}'
                ])
                os.unlink(temp_file)
                
                print(f"✅ Created user: {username} with sudo access")
                
            except subprocess.CalledProcessError:
                print("⚠️  User creation failed. Using current user for AI agent access.")
                username = os.getenv('USER', 'user')
        
        # Set up SSH keys for the user
        return self.setup_user_ssh_keys(username)
    
    def setup_user_ssh_keys(self, username: str) -> bool:
        """Set up SSH keys for AI agent user"""
        try:
            if self.system_info['os'] == 'Windows':
                # Windows SSH key setup
                ssh_dir = Path.home() / '.ssh'
            else:
                # Unix SSH key setup
                if username == os.getenv('USER', 'user'):
                    ssh_dir = Path.home() / '.ssh'
                else:
                    ssh_dir = Path(f'/home/{username}/.ssh')
            
            # Create .ssh directory
            ssh_dir.mkdir(mode=0o700, exist_ok=True)
            
            # Add public key to authorized_keys
            authorized_keys = ssh_dir / 'authorized_keys'
            with open(authorized_keys, 'a') as f:
                f.write(f"\n{self.ssh_keys['public_key_content']}\n")
            
            # Set proper permissions
            authorized_keys.chmod(0o600)
            
            if self.system_info['os'] != 'Windows' and username != os.getenv('USER', 'user'):
                # Change ownership to the AI user
                subprocess.check_call([
                    'sudo', 'chown', '-R', f'{username}:{username}', str(ssh_dir)
                ])
            
            self.config['ssh_username'] = username
            print(f"✅ SSH keys configured for user: {username}")
            return True
            
        except Exception as e:
            print(f"❌ SSH key setup failed: {e}")
            return False
    
    def setup_tunnel(self) -> bool:
        """Set up tunnel for remote access"""
        print("\n🌐 Setting up remote access tunnel...")
        
        print("Choose tunnel method:")
        print("1. Cloudflare Tunnel (recommended)")
        print("2. ngrok")
        print("3. Manual port forwarding")
        print("4. Skip tunnel setup")
        
        choice = input("Enter choice (1-4): ").strip()
        
        if choice == "1":
            return self.setup_cloudflare_tunnel()
        elif choice == "2":
            return self.setup_ngrok_tunnel()
        elif choice == "3":
            return self.setup_manual_tunnel()
        else:
            print("⚠️  Skipping tunnel setup. Manual configuration required.")
            return True
    
    def setup_cloudflare_tunnel(self) -> bool:
        """Set up Cloudflare tunnel"""
        print("\nSetting up Cloudflare tunnel...")
        
        # Check if cloudflared is installed
        try:
            subprocess.check_call(['cloudflared', '--version'], 
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            print("Installing cloudflared...")
            if not self.install_cloudflared():
                return False
        
        print("Please provide your Cloudflare tunnel token:")
        print("1. Go to https://one.dash.cloudflare.com/")
        print("2. Navigate to Networks → Tunnels")
        print("3. Create a new tunnel")
        print("4. Copy the tunnel token")
        
        token = input("\nEnter tunnel token: ").strip()
        if not token:
            print("❌ Tunnel token required")
            return False
        
        # Configure tunnel
        config_dir = Path.home() / '.cloudflared'
        config_dir.mkdir(exist_ok=True)
        
        tunnel_config = {
            'tunnel': token,
            'credentials-file': str(config_dir / 'credentials.json'),
            'ingress': [
                {
                    'hostname': f"ai-agent-{secrets.token_hex(4)}.your-domain.com",
                    'service': 'ssh://localhost:22'
                },
                {
                    'service': 'http_status:404'
                }
            ]
        }
        
        with open(config_dir / 'config.yml', 'w') as f:
            import yaml
            yaml.dump(tunnel_config, f)
        
        # Start tunnel
        try:
            subprocess.Popen(['cloudflared', 'tunnel', 'run'])
            print("✅ Cloudflare tunnel started")
            self.tunnel_info = {
                'type': 'cloudflare',
                'hostname': tunnel_config['ingress'][0]['hostname'],
                'port': 22
            }
            return True
        except Exception as e:
            print(f"❌ Failed to start tunnel: {e}")
            return False
    
    def install_cloudflared(self) -> bool:
        """Install cloudflared"""
        try:
            if self.system_info['os'] == 'Linux':
                # Download and install cloudflared for Linux
                subprocess.check_call([
                    'wget', '-O', '/tmp/cloudflared.deb',
                    'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb'
                ])
                subprocess.check_call(['sudo', 'dpkg', '-i', '/tmp/cloudflared.deb'])
            elif self.system_info['os'] == 'Darwin':
                # macOS installation
                subprocess.check_call(['brew', 'install', 'cloudflared'])
            else:
                print("❌ Automatic cloudflared installation not supported on this platform")
                return False
            
            return True
        except subprocess.CalledProcessError:
            print("❌ Failed to install cloudflared")
            return False
    
    def setup_ngrok_tunnel(self) -> bool:
        """Set up ngrok tunnel"""
        print("\nSetting up ngrok tunnel...")
        print("Please ensure ngrok is installed and configured with your auth token")
        
        try:
            # Start ngrok tunnel for SSH
            process = subprocess.Popen([
                'ngrok', 'tcp', '22'
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Give ngrok time to start
            import time
            time.sleep(3)
            
            # Get tunnel info from ngrok API
            import requests
            try:
                response = requests.get('http://localhost:4040/api/tunnels')
                tunnels = response.json()['tunnels']
                
                if tunnels:
                    tunnel = tunnels[0]
                    public_url = tunnel['public_url']
                    # Parse hostname and port from tcp://hostname:port
                    if public_url.startswith('tcp://'):
                        host_port = public_url[6:]  # Remove 'tcp://'
                        hostname, port = host_port.rsplit(':', 1)
                        
                        self.tunnel_info = {
                            'type': 'ngrok',
                            'hostname': hostname,
                            'port': int(port)
                        }
                        
                        print(f"✅ ngrok tunnel active: {hostname}:{port}")
                        return True
            except:
                pass
            
            print("⚠️  ngrok tunnel started but could not retrieve connection info")
            print("   Check ngrok dashboard at http://localhost:4040")
            return True
            
        except FileNotFoundError:
            print("❌ ngrok not found. Please install ngrok first.")
            return False
        except Exception as e:
            print(f"❌ ngrok setup failed: {e}")
            return False
    
    def setup_manual_tunnel(self) -> bool:
        """Set up manual port forwarding"""
        print("\nManual tunnel setup selected.")
        print("You'll need to configure port forwarding manually:")
        print("1. Forward port 22 (SSH) on your router/firewall")
        print("2. Ensure your device has a static IP or dynamic DNS")
        print("3. Configure any necessary firewall rules")
        
        hostname = input("Enter your public hostname/IP: ").strip()
        port = input("Enter SSH port (default 22): ").strip() or "22"
        
        try:
            port = int(port)
            self.tunnel_info = {
                'type': 'manual',
                'hostname': hostname,
                'port': port
            }
            print("✅ Manual tunnel configuration saved")
            return True
        except ValueError:
            print("❌ Invalid port number")
            return False
    
    def create_mcp_config(self) -> bool:
        """Create MCP server configuration"""
        print("\n⚙️ Creating MCP server configuration...")
        
        config = {
            "server_config": {
                "name": "ai-agent-hardware-server",
                "version": "1.0.0",
                "log_level": "INFO",
                "max_connections": 50,
                "request_timeout": 300,
                "session_timeout": 7200
            },
            "ssh_config": {
                "private_key_path": self.ssh_keys['private_key_path'],
                "public_key_path": self.ssh_keys['public_key_path'],
                "public_key_content": self.ssh_keys['public_key_content'],
                "username": self.config.get('ssh_username', 'aiagent'),
                "default_port": 22
            },
            "security_config": {
                "ai_agent_mode": True,
                "enable_rate_limiting": True,
                "max_requests_per_minute": 120,
                "enable_command_validation": False,
                "enable_audit_logging": True
            },
            "endpoints": [],
            "deployment_info": {
                "system": self.system_info,
                "tunnel": self.tunnel_info,
                "deployed_at": str(datetime.now()),
                "deployment_id": secrets.token_hex(8)
            }
        }
        
        with open('mcp-server-config.json', 'w') as f:
            json.dump(config, f, indent=2)
        
        print("✅ MCP server configuration created")
        return True
    
    def generate_connection_info(self) -> Dict[str, Any]:
        """Generate connection information for AI agent"""
        
        connection_info = {
            "mcp_server_type": "hardware_access",
            "server_version": "1.0.0",
            "connection_method": "ssh_tunnel",
            "ssh_config": {
                "hostname": self.tunnel_info.get('hostname', 'localhost'),
                "port": self.tunnel_info.get('port', 22),
                "username": self.config.get('ssh_username', 'aiagent'),
                "private_key": self.ssh_keys['private_key_content']
            },
            "capabilities": [
                "command_execution",
                "file_operations", 
                "docker_management",
                "environment_setup",
                "system_monitoring",
                "package_installation",
                "hardware_access"
            ],
            "security": {
                "ai_agent_mode": True,
                "bypass_security_available": True,
                "sudo_access": True,
                "rate_limit": "120 requests/minute"
            },
            "system_info": self.system_info,
            "deployment_id": secrets.token_hex(8)
        }
        
        return connection_info
    
    def save_connection_info(self, connection_info: Dict[str, Any]):
        """Save connection information to files"""
        
        # Save as JSON for programmatic access
        with open('ai_agent_connection.json', 'w') as f:
            json.dump(connection_info, f, indent=2)
        
        # Save as readable text for sharing
        with open('ai_agent_connection.txt', 'w') as f:
            f.write("AI Agent Hardware Access - Connection Information\n")
            f.write("=" * 50 + "\n\n")
            
            f.write("SSH Connection Details:\n")
            f.write(f"  Hostname: {connection_info['ssh_config']['hostname']}\n")
            f.write(f"  Port: {connection_info['ssh_config']['port']}\n")
            f.write(f"  Username: {connection_info['ssh_config']['username']}\n")
            f.write(f"\n")
            
            f.write("System Information:\n")
            f.write(f"  OS: {connection_info['system_info']['os']}\n")
            f.write(f"  Architecture: {connection_info['system_info']['architecture']}\n")
            f.write(f"  Hostname: {connection_info['system_info']['hostname']}\n")
            f.write(f"\n")
            
            f.write("Capabilities:\n")
            for capability in connection_info['capabilities']:
                f.write(f"  • {capability.replace('_', ' ').title()}\n")
            f.write(f"\n")
            
            f.write("Security Settings:\n")
            f.write(f"  AI Agent Mode: {connection_info['security']['ai_agent_mode']}\n")
            f.write(f"  Sudo Access: {connection_info['security']['sudo_access']}\n")
            f.write(f"  Rate Limit: {connection_info['security']['rate_limit']}\n")
            f.write(f"\n")
            
            f.write("SSH Private Key:\n")
            f.write("-" * 30 + "\n")
            f.write(connection_info['ssh_config']['private_key'])
            f.write("-" * 30 + "\n")
    
    def run_deployment(self) -> bool:
        """Run complete deployment process"""
        
        self.print_banner()
        
        # Confirm deployment
        confirm = input("Continue with deployment? (y/N): ").strip().lower()
        if confirm != 'y':
            print("Deployment cancelled.")
            return False
        
        steps = [
            ("Checking dependencies", self.check_dependencies),
            ("Generating SSH keys", self.generate_ssh_keys),
            ("Setting up SSH server", self.setup_ssh_server),
            ("Creating AI user", self.create_ai_user),
            ("Setting up tunnel", self.setup_tunnel),
            ("Creating MCP config", self.create_mcp_config),
        ]
        
        for step_name, step_func in steps:
            print(f"\n📋 {step_name}...")
            if not step_func():
                print(f"❌ {step_name} failed. Deployment aborted.")
                return False
        
        # Generate and save connection info
        connection_info = self.generate_connection_info()
        self.save_connection_info(connection_info)
        
        return True
    
    def print_success_message(self):
        """Print deployment success message"""
        print("\n" + "=" * 60)
        print("🎉 AI Agent Hardware Access - Deployment Complete!")
        print("=" * 60)
        
        print("\n📁 Files created:")
        print("  • ai_agent_connection.json - Connection info (JSON format)")
        print("  • ai_agent_connection.txt - Connection info (human readable)")
        print("  • mcp-server-config.json - MCP server configuration")
        print(f"  • {self.ssh_keys['private_key_path']} - SSH private key")
        print(f"  • {self.ssh_keys['public_key_path']} - SSH public key")
        
        print("\n🚀 Next steps:")
        print("1. Start the MCP server:")
        print("   python enhanced_mcp_hardware_server.py")
        print()
        print("2. Share connection details with your AI agent:")
        print("   • Send the contents of 'ai_agent_connection.txt'")
        print("   • Or provide the JSON file for programmatic access")
        print()
        print("3. The AI agent can now access your hardware remotely!")
        
        if self.tunnel_info.get('type') == 'cloudflare':
            print(f"\n🌐 Tunnel: {self.tunnel_info['hostname']}:{self.tunnel_info['port']}")
        elif self.tunnel_info.get('type') == 'ngrok':
            print(f"\n🌐 Tunnel: {self.tunnel_info['hostname']}:{self.tunnel_info['port']}")
            print("   Note: ngrok tunnel URLs change on restart")
        
        print("\n⚠️  Security reminder:")
        print("   • Keep the SSH private key secure")
        print("   • Monitor system logs for AI agent activity")
        print("   • The AI agent has full system access")

def main():
    """Main deployment function"""
    
    deployment = AIAgentDeployment()
    
    try:
        if deployment.run_deployment():
            deployment.print_success_message()
            return 0
        else:
            print("\n❌ Deployment failed. Please check the errors above.")
            return 1
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Deployment interrupted by user.")
        return 1
    except Exception as e:
        print(f"\n❌ Deployment failed with error: {e}")
        return 1

if __name__ == "__main__":
    import sys
    from datetime import datetime
    sys.exit(main())
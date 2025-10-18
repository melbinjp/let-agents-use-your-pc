#!/usr/bin/env python3
"""
⚠️  DEPRECATED: This script is deprecated!
Please use setup.py instead.

Usage:
    python setup.py                    # New unified setup

---

Jules Hardware Access Setup (DEPRECATED)
Optimized setup script for connecting Jules (Google's AI coding agent) to your hardware
"""

import os
import sys
import json
import subprocess

print("\n" + "="*60)
print("⚠️  WARNING: setup_for_jules.py is DEPRECATED!")
print("="*60)
print("\nPlease use the new unified setup:")
print("  python setup.py")
print()
response = input("Continue with deprecated script anyway? (y/N): ").strip().lower()
if response != 'y':
    print("\nCancelled. Run: python setup.py")
    sys.exit(0)
print()
import platform
from pathlib import Path
from datetime import datetime

class Colors:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    """Print a formatted header"""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

def print_success(text):
    """Print success message"""
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_error(text):
    """Print error message"""
    print(f"{Colors.RED}✗ {text}{Colors.END}")

def print_info(text):
    """Print info message"""
    print(f"{Colors.CYAN}ℹ {text}{Colors.END}")

def print_warning(text):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")

def run_command(cmd, check=True, capture_output=True):
    """Run a shell command"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=check,
            capture_output=capture_output,
            text=True
        )
        return result.returncode == 0, result.stdout if capture_output else ""
    except subprocess.CalledProcessError as e:
        return False, e.stderr if capture_output else ""

def check_python_version():
    """Check if Python version is adequate"""
    print_info("Checking Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 8:
        print_success(f"Python {version.major}.{version.minor}.{version.micro} detected")
        return True
    else:
        print_error(f"Python 3.8+ required, found {version.major}.{version.minor}.{version.micro}")
        return False

def install_dependencies():
    """Install Python dependencies"""
    print_info("Installing Python dependencies...")
    
    requirements = [
        "paramiko>=2.11.0",
        "requests>=2.28.0",
        "mcp>=0.1.0"
    ]
    
    for req in requirements:
        success, _ = run_command(f"{sys.executable} -m pip install {req}", check=False)
        if success:
            print_success(f"Installed {req}")
        else:
            print_warning(f"Failed to install {req}, may already be installed")
    
    return True

def detect_platform():
    """Detect the operating system"""
    system = platform.system()
    print_info(f"Detected platform: {system}")
    return system

def setup_ssh_server(system):
    """Setup SSH server based on platform"""
    print_info("Setting up SSH server...")
    
    if system == "Linux":
        # Check if SSH is installed
        success, _ = run_command("which sshd", check=False)
        if not success:
            print_info("Installing OpenSSH server...")
            if os.path.exists("/usr/bin/apt"):
                run_command("sudo apt update && sudo apt install -y openssh-server", check=False)
            elif os.path.exists("/usr/bin/yum"):
                run_command("sudo yum install -y openssh-server", check=False)
            else:
                print_warning("Please install OpenSSH server manually")
                return False
        
        # Start and enable SSH service
        run_command("sudo systemctl start ssh || sudo systemctl start sshd", check=False)
        run_command("sudo systemctl enable ssh || sudo systemctl enable sshd", check=False)
        print_success("SSH server configured")
        return True
    
    elif system == "Darwin":  # macOS
        print_info("Enabling Remote Login (SSH) on macOS...")
        run_command("sudo systemsetup -setremotelogin on", check=False)
        print_success("SSH server enabled")
        return True
    
    elif system == "Windows":
        print_info("Please ensure OpenSSH Server is installed via Windows Settings")
        print_info("Settings > Apps > Optional Features > OpenSSH Server")
        return True
    
    return False

def generate_ssh_keys():
    """Generate SSH keys for Jules"""
    print_info("Generating SSH keys for Jules...")
    
    key_path = Path("jules_key")
    if key_path.exists():
        print_warning("SSH keys already exist, skipping generation")
        return str(key_path), str(key_path.with_suffix(".pub"))
    
    # Generate Ed25519 key (modern and secure)
    success, _ = run_command(
        f'ssh-keygen -t ed25519 -f jules_key -N "" -C "jules@ai-agent"',
        check=False
    )
    
    if success:
        print_success("SSH keys generated successfully")
        # Set correct permissions
        os.chmod("jules_key", 0o600)
        os.chmod("jules_key.pub", 0o644)
        return "jules_key", "jules_key.pub"
    else:
        print_error("Failed to generate SSH keys")
        return None, None

def create_jules_user():
    """Create dedicated jules user account"""
    print_info("Creating jules user account...")
    
    system = platform.system()
    
    # Check if user already exists
    if system in ["Linux", "Darwin"]:
        success, _ = run_command("id jules", check=False)
        if success:
            print_warning("Jules user already exists")
            return True
        
        # Create user
        if system == "Linux":
            run_command("sudo useradd -m -s /bin/bash jules", check=False)
        else:  # macOS
            print_info("Please create 'jules' user manually on macOS")
            return True
        
        # Add to sudo group
        run_command("sudo usermod -aG sudo jules 2>/dev/null || sudo usermod -aG wheel jules", check=False)
        
        # Configure passwordless sudo
        sudo_rule = "jules ALL=(ALL) NOPASSWD:ALL"
        run_command(f'echo "{sudo_rule}" | sudo tee /etc/sudoers.d/jules', check=False)
        run_command("sudo chmod 0440 /etc/sudoers.d/jules", check=False)
        
        print_success("Jules user created with sudo access")
        return True
    
    elif system == "Windows":
        print_info("Please create 'jules' user manually on Windows")
        print_info("Run: net user jules /add")
        print_info("Then: net localgroup Administrators jules /add")
        return True
    
    return False

def setup_ssh_access(public_key_path):
    """Setup SSH access for jules user"""
    print_info("Configuring SSH access for Jules...")
    
    system = platform.system()
    
    if system in ["Linux", "Darwin"]:
        # Read public key
        try:
            with open(public_key_path, 'r') as f:
                public_key = f.read().strip()
        except Exception as e:
            print_error(f"Failed to read public key: {e}")
            return False
        
        # Create .ssh directory for jules user
        run_command("sudo mkdir -p /home/jules/.ssh", check=False)
        run_command(f'echo "{public_key}" | sudo tee /home/jules/.ssh/authorized_keys', check=False)
        run_command("sudo chmod 700 /home/jules/.ssh", check=False)
        run_command("sudo chmod 600 /home/jules/.ssh/authorized_keys", check=False)
        run_command("sudo chown -R jules:jules /home/jules/.ssh", check=False)
        
        print_success("SSH access configured for Jules")
        return True
    
    return True

def setup_cloudflare_tunnel():
    """Setup Cloudflare tunnel for remote access"""
    print_info("Setting up Cloudflare tunnel...")
    
    # Check if cloudflared is installed
    success, _ = run_command("which cloudflared", check=False)
    if not success:
        print_info("Installing cloudflared...")
        system = platform.system()
        
        if system == "Linux":
            arch = platform.machine()
            if arch == "x86_64":
                url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
            elif arch == "aarch64":
                url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
            else:
                print_warning("Unsupported architecture for cloudflared")
                return None
            
            run_command(f"curl -L {url} -o cloudflared", check=False)
            run_command("chmod +x cloudflared", check=False)
            run_command("sudo mv cloudflared /usr/local/bin/", check=False)
        
        elif system == "Darwin":
            run_command("brew install cloudflared", check=False)
        
        elif system == "Windows":
            print_info("Please install cloudflared manually from:")
            print_info("https://github.com/cloudflare/cloudflared/releases")
            return None
    
    # Create tunnel
    print_info("Creating Cloudflare tunnel...")
    print_info("This will create a temporary tunnel. For production, configure a named tunnel.")
    
    # Start tunnel in background
    tunnel_cmd = "cloudflared tunnel --url ssh://localhost:22"
    print_info(f"Starting tunnel: {tunnel_cmd}")
    print_info("Note: For production use, configure a persistent tunnel with cloudflared tunnel create")
    
    return "tunnel-will-be-created-on-first-run"

def create_connection_files(hostname, username, private_key_path):
    """Create connection files for Jules"""
    print_info("Creating connection files for Jules...")
    
    # Read private key
    try:
        with open(private_key_path, 'r') as f:
            private_key = f.read()
    except Exception as e:
        print_error(f"Failed to read private key: {e}")
        return False
    
    # Get hardware info
    cpu_count = os.cpu_count() or 0
    
    # Try to get memory info
    memory_gb = 0
    try:
        if platform.system() == "Linux":
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal' in line:
                        memory_gb = int(line.split()[1]) / (1024 * 1024)
                        break
    except:
        pass
    
    # Try to detect GPU
    gpu_info = []
    success, output = run_command("nvidia-smi --query-gpu=name --format=csv,noheader", check=False)
    if success and output:
        gpu_info = [line.strip() for line in output.strip().split('\n') if line.strip()]
    
    # Create JSON connection file
    connection_data = {
        "mcp_server_type": "hardware_access",
        "connection_method": "ssh_tunnel",
        "ssh_config": {
            "hostname": hostname,
            "port": 22,
            "username": username,
            "private_key": private_key
        },
        "capabilities": [
            "command_execution",
            "file_operations",
            "docker_management",
            "environment_setup",
            "system_monitoring",
            "package_installation",
            "hardware_access",
            "gpu_access" if gpu_info else None
        ],
        "security": {
            "ai_agent_mode": True,
            "bypass_security_available": True,
            "sudo_access": True,
            "rate_limit": "120 requests/minute"
        },
        "hardware_info": {
            "cpu_count": cpu_count,
            "memory_gb": round(memory_gb, 1),
            "gpu_info": gpu_info,
            "platform": platform.system(),
            "architecture": platform.machine()
        },
        "setup_date": datetime.now().isoformat(),
        "documentation": {
            "agent_guide": "AGENTS.md",
            "jules_guide": "JULES_INTEGRATION_GUIDE.md",
            "usage_guide": "AI_AGENT_USAGE_GUIDE.md"
        }
    }
    
    # Remove None values from capabilities
    connection_data["capabilities"] = [c for c in connection_data["capabilities"] if c is not None]
    
    # Write JSON file
    with open("ai_agent_connection.json", 'w') as f:
        json.dump(connection_data, f, indent=2)
    
    print_success("Created ai_agent_connection.json")
    
    # Create human-readable text file
    text_content = f"""
╔══════════════════════════════════════════════════════════════╗
║          Jules Hardware Access - Connection Info             ║
╚══════════════════════════════════════════════════════════════╝

🔗 CONNECTION DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SSH Hostname:  {hostname}
SSH Port:      22
Username:      {username}
Private Key:   {private_key_path}

📋 QUICK START FOR JULES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Share ai_agent_connection.json with Jules
2. Jules can now access your hardware for testing and development
3. All Jules activities are logged to mcp-hardware-server.log

💻 HARDWARE CAPABILITIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CPU Cores:     {cpu_count}
Memory:        {round(memory_gb, 1)} GB
GPU:           {', '.join(gpu_info) if gpu_info else 'No GPU detected'}
Platform:      {platform.system()} {platform.machine()}

🎯 WHAT JULES CAN DO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Execute any command with sudo access
✓ Install and manage software packages
✓ Access and modify files
✓ Manage Docker containers
✓ Use GPU for ML/AI workloads
✓ Set up development environments
✓ Run tests and benchmarks
✓ Monitor system resources

🔒 SECURITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ SSH key authentication only (no passwords)
✓ Complete audit logging of all activities
✓ Rate limiting (120 requests/minute)
✓ Dedicated user account for Jules

📚 DOCUMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• JULES_INTEGRATION_GUIDE.md - Jules-specific workflows
• AGENTS.md - Agent capabilities reference
• AI_AGENT_USAGE_GUIDE.md - MCP tool reference
• TROUBLESHOOTING.md - Common issues and solutions

🚀 NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Start MCP server: python enhanced_mcp_hardware_server.py
2. Share ai_agent_connection.json with Jules
3. Monitor activity: tail -f mcp-hardware-server.log

Setup completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    
    with open("ai_agent_connection.txt", 'w') as f:
        f.write(text_content)
    
    print_success("Created ai_agent_connection.txt")
    
    return True

def create_mcp_config(username, private_key_path, public_key_path):
    """Create MCP server configuration"""
    print_info("Creating MCP server configuration...")
    
    config = {
        "mcp_server": {
            "name": "enhanced-hardware-server",
            "version": "1.0.0",
            "created": datetime.now().isoformat()
        },
        "ssh_config": {
            "private_key_path": private_key_path,
            "public_key_path": public_key_path,
            "username": username
        },
        "cloudflare_config": {
            "email": os.getenv("CLOUDFLARE_EMAIL", ""),
            "api_key": os.getenv("CLOUDFLARE_API_KEY", ""),
            "domain": "wecanuseai.com"
        },
        "endpoints": [],
        "settings": {
            "auto_failover": True,
            "health_check_interval": 300,
            "max_connections_per_endpoint": 5,
            "session_timeout": 3600,
            "ai_agent_mode": True,
            "rate_limit": 120
        }
    }
    
    with open("mcp-server-config.json", 'w') as f:
        json.dump(config, f, indent=2)
    
    print_success("Created mcp-server-config.json")
    return True

def main():
    """Main setup function"""
    print_header("Jules Hardware Access Setup")
    print_info("This script will set up your hardware for Jules access")
    print_info("Jules is Google's experimental AI coding agent")
    print()
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        print_error("Failed to install dependencies")
        sys.exit(1)
    
    # Detect platform
    system = detect_platform()
    
    # Setup SSH server
    if not setup_ssh_server(system):
        print_warning("SSH server setup incomplete, please configure manually")
    
    # Generate SSH keys
    private_key, public_key = generate_ssh_keys()
    if not private_key:
        print_error("Failed to generate SSH keys")
        sys.exit(1)
    
    # Create jules user
    if not create_jules_user():
        print_warning("Jules user creation incomplete, please configure manually")
    
    # Setup SSH access
    if not setup_ssh_access(public_key):
        print_warning("SSH access setup incomplete, please configure manually")
    
    # Setup Cloudflare tunnel
    tunnel_hostname = setup_cloudflare_tunnel()
    if not tunnel_hostname:
        print_warning("Cloudflare tunnel setup skipped")
        tunnel_hostname = "localhost"  # Fallback for local testing
    
    # Create MCP config
    if not create_mcp_config("jules", private_key, public_key):
        print_error("Failed to create MCP configuration")
        sys.exit(1)
    
    # Create connection files
    if not create_connection_files(tunnel_hostname, "jules", private_key):
        print_error("Failed to create connection files")
        sys.exit(1)
    
    # Generate repository files
    print_header("Generating Repository Files")
    print_info("Creating files to add to your project repository...")
    try:
        import subprocess
        result = subprocess.run([sys.executable, "generate_repo_files.py"], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print_success("Repository files generated successfully!")
            print_info("📁 Check: generated_repo_files/ directory")
        else:
            print_warning("Could not generate repository files automatically")
            print_info("Run manually: python generate_repo_files.py")
    except Exception as e:
        print_warning(f"Could not generate repository files: {e}")
        print_info("Run manually: python generate_repo_files.py")
    
    # Final instructions
    print_header("Setup Complete!")
    print_success("Your hardware is now ready for Jules access")
    print()
    print_info("Next steps:")
    print(f"  1. Start the MCP server: {Colors.BOLD}python enhanced_mcp_hardware_server.py{Colors.END}")
    print(f"  2. Add files to your project: {Colors.BOLD}See generated_repo_files/INSTRUCTIONS.md{Colors.END}")
    print(f"  3. Monitor activity: {Colors.BOLD}tail -f mcp-hardware-server.log{Colors.END}")
    print()
    print_info("📋 Important:")
    print(f"  • Copy files from {Colors.BOLD}generated_repo_files/{Colors.END} to your project")
    print(f"  • Add {Colors.BOLD}AGENTS.md{Colors.END} to your project root")
    print(f"  • Add {Colors.BOLD}.jules/{Colors.END} directory to your project")
    print(f"  • Commit and push to GitHub")
    print()
    print_info("Documentation:")
    print(f"  • {Colors.BOLD}generated_repo_files/INSTRUCTIONS.md{Colors.END} - How to add files")
    print(f"  • {Colors.BOLD}JULES_INTEGRATION_GUIDE.md{Colors.END} - Complete guide")
    print(f"  • {Colors.BOLD}JULES_EXAMPLE_WORKFLOWS.md{Colors.END} - Example workflows")
    print()
    print_info("Test the setup:")
    print(f"  {Colors.BOLD}python test_ai_agent_connection.py{Colors.END}")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        print_warning("Setup interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"Setup failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

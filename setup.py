#!/usr/bin/env python3
"""
Unified Jules Hardware Access Setup
Supports both Docker and Native installations from the same repo
"""

import os
import sys
import json
import platform
import subprocess
import shutil
from pathlib import Path
from datetime import datetime

class Colors:
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(70)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*70}{Colors.END}\n")

def print_success(text):
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_error(text):
    print(f"{Colors.RED}✗ {text}{Colors.END}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ {text}{Colors.END}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")

def check_docker():
    """Check if Docker is available"""
    try:
        result = subprocess.run(['docker', '--version'], 
                              capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def check_docker_running():
    """Check if Docker daemon is running"""
    try:
        result = subprocess.run(['docker', 'ps'], 
                              capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def get_setup_mode():
    """Ask user to choose setup mode"""
    print_header("Jules Hardware Access Setup")
    print_info("Choose your setup method:\n")
    
    has_docker = check_docker()
    docker_running = check_docker_running() if has_docker else False
    
    print(f"{Colors.BOLD}1. Docker Setup (Recommended){Colors.END}")
    print("   ✅ Works on Windows, macOS, and Linux")
    print("   ✅ Isolated from your system")
    print("   ✅ Easy to remove")
    print("   ✅ GPU support included")
    
    if not has_docker:
        print(f"   {Colors.RED}⚠ Docker not installed{Colors.END}")
    elif not docker_running:
        print(f"   {Colors.YELLOW}⚠ Docker not running{Colors.END}")
    else:
        print(f"   {Colors.GREEN}✓ Docker available{Colors.END}")
    
    print(f"\n{Colors.BOLD}2. Native Setup (Advanced){Colors.END}")
    print("   • 100% native performance")
    print("   • Direct system access")
    print("   • More control")
    
    detected_os = platform.system()
    if detected_os == "Windows":
        print(f"   {Colors.YELLOW}⚠ Native setup on Windows requires WSL{Colors.END}")
    else:
        print(f"   {Colors.GREEN}✓ Native setup supported on {detected_os}{Colors.END}")
    
    print(f"\n{Colors.BOLD}3. Both (Docker + Native){Colors.END}")
    print("   • Run both simultaneously")
    print("   • Separate connection files")
    print("   • Choose per task")
    
    print()
    
    while True:
        choice = input(f"{Colors.BOLD}Choose [1/2/3] (default: 1): {Colors.END}").strip() or "1"
        if choice in ['1', '2', '3']:
            return choice
        print_error("Invalid choice. Please enter 1, 2, or 3.")

def create_config_structure():
    """Create organized directory structure for configurations"""
    base_dir = Path.cwd()
    
    # Create organized structure
    dirs = {
        'configs': base_dir / 'configs',
        'docker_config': base_dir / 'configs' / 'docker',
        'native_config': base_dir / 'configs' / 'native',
        'generated': base_dir / 'generated_files',
        'docker_generated': base_dir / 'generated_files' / 'docker',
        'native_generated': base_dir / 'generated_files' / 'native',
        'logs': base_dir / 'logs',
        'docker_logs': base_dir / 'logs' / 'docker',
        'native_logs': base_dir / 'logs' / 'native',
    }
    
    for name, path in dirs.items():
        path.mkdir(parents=True, exist_ok=True)
    
    # Create .gitignore for sensitive files
    gitignore_content = """# Sensitive configuration
configs/docker/.env
configs/native/.env
*.key
*.pem

# Generated files (user should copy these)
generated_files/

# Logs
logs/
*.log

# Temporary files
*.tmp
__pycache__/
"""
    
    gitignore_path = base_dir / '.gitignore'
    if not gitignore_path.exists():
        gitignore_path.write_text(gitignore_content)
    
    return dirs

def setup_docker(dirs):
    """Setup Docker installation"""
    print_header("Docker Setup")
    
    docker_dir = Path('docker')
    config_dir = dirs['docker_config']
    
    # Check if setup script exists
    if platform.system() == "Windows":
        setup_script = docker_dir / 'setup.ps1'
        cmd = f'powershell -ExecutionPolicy Bypass -File {setup_script}'
    else:
        setup_script = docker_dir / 'setup.sh'
        setup_script.chmod(0o755)
        cmd = f'bash {setup_script}'
    
    print_info(f"Running Docker setup script: {setup_script}")
    print()
    
    # Run setup
    result = subprocess.run(cmd, shell=True)
    
    if result.returncode == 0:
        print_success("Docker setup completed!")
        
        # Copy generated files to organized location
        docker_env = docker_dir / '.env'
        if docker_env.exists():
            shutil.copy(docker_env, config_dir / '.env')
            print_success(f"Configuration saved to: {config_dir}")
        
        return True
    else:
        print_error("Docker setup failed")
        return False

def setup_native(dirs):
    """Setup native installation"""
    print_header("Native Setup")
    
    config_dir = dirs['native_config']
    
    print_info("Running native setup...")
    print()
    
    # Run jules_setup.py
    result = subprocess.run([sys.executable, 'jules_setup.py'])
    
    if result.returncode == 0:
        print_success("Native setup completed!")
        
        # Move generated files to organized location
        gen_dir = Path('generated_repo_files')
        if gen_dir.exists():
            # Copy to native generated folder
            if (gen_dir / '.jules').exists():
                shutil.copytree(gen_dir / '.jules', 
                              dirs['native_generated'] / '.jules',
                              dirs_exist_ok=True)
            if (gen_dir / 'AGENTS.md').exists():
                shutil.copy(gen_dir / 'AGENTS.md',
                          dirs['native_generated'] / 'AGENTS.md')
            
            print_success(f"Files saved to: {dirs['native_generated']}")
        
        return True
    else:
        print_error("Native setup failed")
        return False

def create_status_config(mode, dirs):
    """Create configuration for status monitoring"""
    config = {
        'mode': mode,
        'setup_date': datetime.now().isoformat(),
        'docker_enabled': mode in ['1', '3'],
        'native_enabled': mode in ['2', '3'],
        'dirs': {k: str(v) for k, v in dirs.items()}
    }
    
    config_file = Path('configs') / 'setup_config.json'
    config_file.write_text(json.dumps(config, indent=2))
    
    return config

def main():
    """Main setup flow"""
    try:
        # Get setup mode
        mode = get_setup_mode()
        
        # Create organized directory structure
        print_info("Creating organized directory structure...")
        dirs = create_config_structure()
        print_success("Directory structure created")
        
        success = True
        
        # Setup based on mode
        if mode == '1':  # Docker only
            success = setup_docker(dirs)
        
        elif mode == '2':  # Native only
            success = setup_native(dirs)
        
        elif mode == '3':  # Both
            print_info("Setting up both Docker and Native installations...")
            print()
            
            docker_success = setup_docker(dirs)
            print()
            
            if docker_success:
                print_info("Docker setup complete. Now setting up native...")
                print()
            
            native_success = setup_native(dirs)
            
            success = docker_success or native_success
            
            if docker_success and native_success:
                print_success("Both Docker and Native setups completed!")
            elif docker_success:
                print_warning("Docker setup succeeded, but native setup failed")
            elif native_success:
                print_warning("Native setup succeeded, but Docker setup failed")
        
        # Create status config
        create_status_config(mode, dirs)
        
        # Final summary
        if success:
            print_header("Setup Complete!")
            
            print_info("📁 Your files are organized:")
            print(f"  • Configurations: {Colors.BOLD}configs/{Colors.END}")
            print(f"  • Generated files: {Colors.BOLD}generated_files/{Colors.END}")
            print(f"  • Logs: {Colors.BOLD}logs/{Colors.END}")
            print()
            
            print_info("🎯 Next steps:")
            print("  1. Check status: python status.py")
            print("  2. Copy files to your project")
            print("  3. Commit and push to GitHub")
            print()
            
            print_info("📊 Monitor your setup:")
            print(f"  {Colors.BOLD}python status.py{Colors.END} - View connection status")
            print()
            
            return 0
        else:
            print_error("Setup failed. Check logs for details.")
            return 1
    
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Setup cancelled by user{Colors.END}")
        return 1
    except Exception as e:
        print_error(f"Setup failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())

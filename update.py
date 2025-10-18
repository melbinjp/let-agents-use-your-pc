#!/usr/bin/env python3
"""
Update Script - Keep Jules Hardware Access Up to Date
"""

import os
import sys
import subprocess
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

def print_success(text):
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_error(text):
    print(f"{Colors.RED}✗ {text}{Colors.END}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ {text}{Colors.END}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")

def check_git():
    """Check if we're in a git repository"""
    try:
        result = subprocess.run(['git', 'rev-parse', '--git-dir'],
                              capture_output=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def get_current_branch():
    """Get current git branch"""
    try:
        result = subprocess.run(['git', 'branch', '--show-current'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return result.stdout.strip()
    except:
        pass
    return None

def check_uncommitted_changes():
    """Check for uncommitted changes"""
    try:
        result = subprocess.run(['git', 'status', '--porcelain'],
                              capture_output=True, text=True, timeout=5)
        return bool(result.stdout.strip())
    except:
        return False

def pull_updates():
    """Pull latest updates from git"""
    try:
        result = subprocess.run(['git', 'pull'],
                              capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def main():
    """Main update flow"""
    print_header("Jules Hardware Access - Update")
    
    # Check if git repo
    if not check_git():
        print_error("Not a git repository!")
        print_info("This script only works if you cloned the repository with git.")
        print_info("To update manually:")
        print("  1. Download latest version from GitHub")
        print("  2. Replace files (keep your configs/)")
        return 1
    
    # Get current branch
    branch = get_current_branch()
    if branch:
        print_info(f"Current branch: {branch}")
    
    # Check for uncommitted changes
    if check_uncommitted_changes():
        print_warning("You have uncommitted changes!")
        print_info("Your local changes:")
        subprocess.run(['git', 'status', '--short'])
        print()
        
        response = input(f"{Colors.YELLOW}Continue anyway? (y/N): {Colors.END}").strip().lower()
        if response != 'y':
            print_info("Update cancelled. Commit or stash your changes first.")
            return 0
    
    # Pull updates
    print_info("Pulling latest updates...")
    success, stdout, stderr = pull_updates()
    
    if success:
        if "Already up to date" in stdout:
            print_success("Already up to date!")
        else:
            print_success("Update successful!")
            print()
            print_info("Changes:")
            print(stdout)
            
            # Check if requirements changed
            if 'requirements.txt' in stdout:
                print()
                print_warning("requirements.txt was updated!")
                print_info("Run: pip install -r requirements.txt")
            
            # Check if docker files changed
            if 'docker/' in stdout:
                print()
                print_warning("Docker files were updated!")
                print_info("Rebuild container: cd docker && docker-compose up -d --build")
        
        print()
        print_info("Next steps:")
        print("  • Check CHANGELOG.md for breaking changes")
        print("  • Run: python quick-test.py")
        print("  • Run: python status.py")
        
        return 0
    else:
        print_error("Update failed!")
        print_error(stderr)
        print()
        print_info("Troubleshooting:")
        print("  • Check your internet connection")
        print("  • Resolve any merge conflicts")
        print("  • Run: git status")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Update cancelled{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Update failed: {e}{Colors.END}")
        sys.exit(1)

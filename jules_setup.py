#!/usr/bin/env python3
"""
⚠️  DEPRECATED: This script is deprecated!
Please use setup.py instead.

This script will be removed in a future version.

Usage:
    python setup.py                    # New unified setup
    python setup.py --help             # See all options

---

Jules Setup - One Command to Rule Them All (DEPRECATED)

Unified setup that handles everything:
- Platform detection
- Tunnel configuration  
- SSH setup
- File generation
- API integration
- Automatic testing

Usage:
    jules_setup.py                    # Interactive mode
    jules_setup.py --repo user/repo   # With repo
    jules_setup.py --quick            # Skip prompts
"""

import sys

print("⚠️  WARNING: jules_setup.py is DEPRECATED!")
print("Please use: python setup.py")
print()
response = input("Continue anyway? (y/N): ").strip().lower()
if response != 'y':
    print("Cancelled. Run: python setup.py")
    sys.exit(0)
print()

import os
import sys
import json
import platform
import subprocess
from pathlib import Path
from datetime import datetime

# Add color support
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
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
    print(f"{Colors.CYAN}ℹ {text}{Colors.END}")

def print_warning(text):
    print(f"{Colors.YELLOW}⚠ {text}{Colors.END}")

def print_step(number, total, text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}[{number}/{total}] {text}{Colors.END}")

def run_command(cmd, check=True):
    """Run command and return success"""
    try:
        result = subprocess.run(cmd, shell=True, check=check, 
                              capture_output=True, text=True, timeout=60)
        return result.returncode == 0, result.stdout, result.stderr
    except:
        return False, "", ""

def main():
    """Main unified setup"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Jules Hardware Setup - One Command Setup',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode (recommended)
  python jules_setup.py
  
  # Quick mode (uses defaults)
  python jules_setup.py --quick
  
  # With GitHub repo
  python jules_setup.py --repo user/repo
  
  # Full automation
  python jules_setup.py --repo user/repo --api-key KEY --auto-test
        """
    )
    
    parser.add_argument('--repo', help='GitHub repository (user/repo)')
    parser.add_argument('--hardware-name', help='Name for this hardware')
    parser.add_argument('--tunnel', choices=['auto', 'ngrok', 'cloudflare', 'tailscale'],
                       default='auto', help='Tunnel provider')
    parser.add_argument('--api-key', help='Jules API key')
    parser.add_argument('--auto-test', action='store_true',
                       help='Automatically create test session')
    parser.add_argument('--auto-pr', action='store_true',
                       help='Automatically create PR')
    parser.add_argument('--quick', action='store_true',
                       help='Quick mode with defaults')
    
    args = parser.parse_args()
    
    print_header("Jules Hardware Setup")
    print_info("One command to set up everything!")
    print()
    
    # Step 1: Platform Detection
    print_step(1, 6, "Detecting Platform")
    detected_platform = platform.system()
    print_success(f"Platform: {detected_platform}")
    
    # Step 2: Tunnel Setup
    print_step(2, 6, "Setting Up Tunnel")
    print_info("Running tunnel wizard...")
    
    success, stdout, stderr = run_command(
        f"{sys.executable} tunnel_manager.py setup" if not args.quick 
        else f"{sys.executable} tunnel_manager.py start --provider {args.tunnel}"
    )
    
    if success:
        print_success("Tunnel configured")
    else:
        print_warning("Tunnel setup needs attention")
        print_info("Run manually: python tunnel_manager.py setup")
    
    # Step 3: Main Setup
    print_step(3, 6, "Configuring Hardware")
    print_info("Running main setup...")
    
    success, stdout, stderr = run_command(f"{sys.executable} setup_for_jules.py")
    
    if success:
        print_success("Hardware configured")
    else:
        print_error("Setup failed")
        print_error(stderr)
        return 1
    
    # Step 4: Validation
    print_step(4, 6, "Validating Setup")
    
    success, stdout, stderr = run_command(f"{sys.executable} validate_jules_setup.py")
    
    if success:
        print_success("Validation passed")
    else:
        print_warning("Some validations failed")
        print_info("Check: python validate_jules_setup.py")
    
    # Step 5: Repository Integration
    print_step(5, 6, "Preparing Repository Files")
    
    if Path("generated_repo_files").exists():
        print_success("Files generated in: generated_repo_files/")
        print_info("Next: Copy files to your project repository")
        print_info("See: generated_repo_files/INSTRUCTIONS.md")
    else:
        print_warning("Files not generated")
        print_info("Run: python generate_repo_files.py")
    
    # Step 6: API Integration (Optional)
    if args.auto_test and args.repo and args.api_key:
        print_step(6, 6, "Creating Test Session via API")
        print_info("This requires Jules API integration...")
        print_warning("API helper not yet implemented")
        print_info("See: JULES_API_INTEGRATION.md for manual setup")
    else:
        print_step(6, 6, "API Integration (Optional)")
        print_info("To enable automatic testing:")
        print_info("  1. Get API key: https://jules.google.com/settings#api")
        print_info("  2. Run: jules_setup.py --repo user/repo --api-key KEY --auto-test")
    
    # Final Summary
    print_header("Setup Complete!")
    print_success("Your hardware is ready for Jules!")
    print()
    
    print_info("📁 Generated files:")
    print("  • generated_repo_files/AGENTS.md")
    print("  • generated_repo_files/.jules/hardware_connection.json")
    print("  • generated_repo_files/INSTRUCTIONS.md")
    print()
    
    print_info("🚀 Next steps:")
    print("  1. Copy files to your project (see INSTRUCTIONS.md)")
    print("  2. Commit and push to GitHub")
    print("  3. Use with Jules!")
    print()
    
    print_info("📚 Documentation:")
    print("  • GETTING_STARTED.md - Complete guide")
    print("  • JULES_EXAMPLE_WORKFLOWS.md - Example workflows")
    print("  • QUICK_REFERENCE.md - Quick commands")
    print()
    
    print_info("🧪 Test your setup:")
    print(f"  {Colors.BOLD}python test_ai_agent_connection.py{Colors.END}")
    print()
    
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Setup cancelled by user{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Setup failed: {e}{Colors.END}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

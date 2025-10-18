#!/usr/bin/env python3
"""
Generate Repository Files for Jules Integration

This script creates ready-to-copy files that users can add to their project repositories
to enable Jules hardware access without cluttering their actual project.
"""

import os
import sys
import json
import platform
import shutil
from datetime import datetime
from pathlib import Path

class Colors:
    GREEN = '\033[92m'
    BLUE = '\033[94m'
    YELLOW = '\033[93m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_header(text):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(60)}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")

def print_success(text):
    print(f"{Colors.GREEN}✓ {text}{Colors.END}")

def print_info(text):
    print(f"{Colors.BLUE}ℹ {text}{Colors.END}")

def get_system_info():
    """Get system information for templates"""
    info = {
        'PLATFORM': platform.system(),
        'CPU_COUNT': os.cpu_count() or 'Unknown',
        'MEMORY_GB': 'Unknown',
        'GPU_INFO': 'No GPU detected',
        'DOCKER_STATUS': 'Not detected',
        'SETUP_DATE': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    
    # Try to get memory info
    try:
        if platform.system() == 'Linux':
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal' in line:
                        mem_kb = int(line.split()[1])
                        info['MEMORY_GB'] = f"{mem_kb / (1024 * 1024):.1f}"
                        break
        elif platform.system() == 'Windows':
            import subprocess
            result = subprocess.run(['wmic', 'computersystem', 'get', 'totalphysicalmemory'],
                                  capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    mem_bytes = int(lines[1].strip())
                    info['MEMORY_GB'] = f"{mem_bytes / (1024**3):.1f}"
    except:
        pass
    
    # Try to detect GPU
    try:
        import subprocess
        result = subprocess.run(['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and result.stdout.strip():
            info['GPU_INFO'] = result.stdout.strip().split('\n')[0]
    except:
        pass
    
    # Try to detect Docker
    try:
        import subprocess
        result = subprocess.run(['docker', '--version'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            info['DOCKER_STATUS'] = 'Available'
    except:
        pass
    
    return info

def load_template(template_path):
    """Load a template file"""
    try:
        with open(template_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print(f"Error loading template {template_path}: {e}")
        return None

def fill_template(template_content, info):
    """Fill template with actual values"""
    for key, value in info.items():
        placeholder = f"{{{key}}}"
        template_content = template_content.replace(placeholder, str(value))
    return template_content

def create_output_directory():
    """Create output directory for generated files"""
    output_dir = Path("generated_repo_files")
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(exist_ok=True)
    (output_dir / ".jules").mkdir(exist_ok=True)
    return output_dir

def copy_connection_file(output_dir):
    """Copy connection file if it exists"""
    connection_file = Path("ai_agent_connection.json")
    if connection_file.exists():
        shutil.copy(connection_file, output_dir / ".jules" / "hardware_connection.json")
        return True
    return False

def generate_files():
    """Generate all repository files"""
    print_header("Generate Repository Files for Jules")
    
    # Get system info
    print_info("Detecting system information...")
    info = get_system_info()
    print_success(f"Platform: {info['PLATFORM']}")
    print_success(f"CPU: {info['CPU_COUNT']} cores")
    print_success(f"Memory: {info['MEMORY_GB']} GB")
    print_success(f"GPU: {info['GPU_INFO']}")
    print_success(f"Docker: {info['DOCKER_STATUS']}")
    
    # Create output directory
    print_info("\nCreating output directory...")
    output_dir = create_output_directory()
    print_success(f"Created: {output_dir}")
    
    # Generate AGENTS.md
    print_info("\nGenerating AGENTS.md...")
    template = load_template("templates/AGENTS.md.template")
    if template:
        content = fill_template(template, info)
        with open(output_dir / "AGENTS.md", 'w', encoding='utf-8') as f:
            f.write(content)
        print_success("Generated: AGENTS.md")
    
    # Generate README addition
    print_info("Generating README_ADDITION.md...")
    template = load_template("templates/README_ADDITION.md.template")
    if template:
        content = fill_template(template, info)
        with open(output_dir / "README_ADDITION.md", 'w', encoding='utf-8') as f:
            f.write(content)
        print_success("Generated: README_ADDITION.md")
    
    # Generate .jules/README.md
    print_info("Generating .jules/README.md...")
    template = load_template("templates/DOT_JULES_README.md.template")
    if template:
        content = fill_template(template, info)
        with open(output_dir / ".jules" / "README.md", 'w', encoding='utf-8') as f:
            f.write(content)
        print_success("Generated: .jules/README.md")
    
    # Copy connection file
    print_info("Copying connection file...")
    if copy_connection_file(output_dir):
        print_success("Copied: .jules/hardware_connection.json")
    else:
        print_info("⚠ Connection file not found. Run setup first.")
        # Create placeholder
        placeholder = {
            "note": "Run setup_for_jules.py first to generate the actual connection file",
            "then": "Copy ai_agent_connection.json to .jules/hardware_connection.json"
        }
        with open(output_dir / ".jules" / "hardware_connection.json", 'w') as f:
            json.dump(placeholder, f, indent=2)
        print_info("Created placeholder connection file")
    
    # Create instructions file
    print_info("\nCreating instructions...")
    instructions = """
# 📋 How to Add These Files to Your Project

## What You Have

This folder contains files ready to copy to your project repository:

```
generated_repo_files/
├── AGENTS.md                           # Add to your repo root
├── README_ADDITION.md                  # Add to your README.md
└── .jules/
    ├── README.md                       # Explains the .jules directory
    └── hardware_connection.json        # Connection configuration
```

## Step-by-Step Instructions

### 1. Copy Files to Your Project

```bash
# Navigate to your project repository
cd /path/to/your/project

# Copy AGENTS.md to root
cp /path/to/generated_repo_files/AGENTS.md .

# Copy .jules directory
cp -r /path/to/generated_repo_files/.jules .
```

### 2. Update Your README.md

Open your project's `README.md` and add the content from `README_ADDITION.md`.

You can add it:
- At the top (for high visibility)
- In a "Testing" section
- In a "Development" section
- Wherever makes sense for your project

### 3. Commit and Push

```bash
git add AGENTS.md .jules/
git commit -m "Add Jules hardware access configuration"
git push
```

### 4. Verify

Check that these files are in your GitHub repository:
- `AGENTS.md` in the root
- `.jules/hardware_connection.json` in the .jules directory
- `.jules/README.md` in the .jules directory

## Using with Jules

Once these files are in your repository, Jules will automatically discover them!

### Example Jules Prompt (Single Hardware)

```
I have hardware available at .jules/hardware_connection.json

Please:
1. Run the full test suite on real hardware
2. Report any platform-specific issues
3. Check performance metrics
```

### Multiple Hardware Support

If you have multiple machines, you can add more connection files:

1. **Run setup on each machine:**
   ```bash
   # On Windows laptop
   python setup_for_jules.py
   # Copy: ai_agent_connection.json → windows_laptop.json
   
   # On Linux server
   python setup_for_jules.py
   # Copy: ai_agent_connection.json → linux_server.json
   ```

2. **Add all to .jules/ directory:**
   ```
   .jules/
   ├── hardware_connection.json    # Default
   ├── windows_laptop.json         # Windows
   ├── linux_server.json           # Linux
   └── gpu_workstation.json        # GPU
   ```

3. **Specify in Jules prompt:**
   ```
   I have multiple hardware options:
   - Windows: .jules/windows_laptop.json
   - Linux: .jules/linux_server.json
   - GPU: .jules/gpu_workstation.json
   
   Please use the GPU workstation for ML training.
   ```

Jules will:
1. Read AGENTS.md to understand available hardware
2. Read the specified connection file
3. Execute tests on that specific hardware
4. Report results back to you

See DYNAMIC_HARDWARE_SWITCHING.md for advanced scenarios.

## Important Notes

### Before Using
- ✅ Make sure MCP server is running on your hardware
- ✅ Verify connection file is up to date
- ✅ Check that hardware is online and accessible

### Security
- 🔐 Connection uses SSH key authentication
- 📝 All activity is logged on your hardware
- 🚦 Rate limited to prevent abuse
- 👤 You control when hardware is available

### Monitoring
While Jules is working, you can:
- Watch logs: `tail -f mcp-hardware-server.log`
- Monitor resources: Task Manager / htop
- See real-time activity

## Troubleshooting

### Jules Can't Find Hardware
- Check that `.jules/hardware_connection.json` exists in your repo
- Verify the file is committed and pushed to GitHub
- Make sure MCP server is running on your hardware

### Connection Fails
- Verify MCP server is running: `python enhanced_mcp_hardware_server.py`
- Check connection file is valid JSON
- Ensure hardware is online and accessible

### Need to Update Connection
1. Run setup again on your hardware
2. Copy new `ai_agent_connection.json`
3. Replace `.jules/hardware_connection.json` in your repo
4. Commit and push

## Questions?

See the MCP Hardware Server documentation for more details:
- JULES_INTEGRATION_GUIDE.md - Complete guide
- JULES_EXAMPLE_WORKFLOWS.md - Example workflows
- TROUBLESHOOTING.md - Common issues

---

**Generated**: {SETUP_DATE}
**Platform**: {PLATFORM}
**Ready to use**: Copy files to your project and commit!
""".format(**info)
    
    with open(output_dir / "INSTRUCTIONS.md", 'w', encoding='utf-8') as f:
        f.write(instructions)
    print_success("Created: INSTRUCTIONS.md")
    
    # Create .gitignore for the .jules directory
    gitignore_content = """# Jules Hardware Connection
# Uncomment the line below if you want to keep connection private
# hardware_connection.json

# Keep README
!README.md
"""
    with open(output_dir / ".jules" / ".gitignore", 'w', encoding='utf-8') as f:
        f.write(gitignore_content)
    print_success("Created: .jules/.gitignore")
    
    # Summary
    print_header("Generation Complete!")
    print_success("All files generated successfully!")
    print()
    print_info("📁 Output directory: generated_repo_files/")
    print()
    print_info("📋 Next steps:")
    print("  1. Read: generated_repo_files/INSTRUCTIONS.md")
    print("  2. Copy files to your project repository")
    print("  3. Commit and push to GitHub")
    print("  4. Use with Jules!")
    print()
    print_info("💡 Tip: Keep AGENTS.md and .jules/ in your project root")
    print_info("💡 Tip: Add README_ADDITION.md content to your README.md")
    print()

if __name__ == "__main__":
    try:
        generate_files()
    except KeyboardInterrupt:
        print("\n\nGeneration cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nError: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

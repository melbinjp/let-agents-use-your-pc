# 📁 Repository Structure

This document explains the organization of the Jules Hardware Access repository.

---

## 📖 Essential Documentation

| File | Purpose |
|------|---------|
| **README.md** | Main overview and quick start |
| **USER_FLOWS.md** | Visual flowcharts for all scenarios |
| **GETTING_STARTED.md** | Complete setup guide |
| **AGENTS.md** | For Jules to read (capabilities reference) |
| **JULES_EXAMPLE_WORKFLOWS.md** | Real-world workflow examples |
| **QUICK_REFERENCE.md** | All commands at a glance |
| **TROUBLESHOOTING.md** | Common issues and solutions |
| **CONTRIBUTING.md** | Contribution guidelines |

---

## 🔧 Core Scripts

| Script | Purpose |
|--------|---------|
| **jules_setup.py** | Main unified setup script (recommended) |
| **tunnel_manager.py** | Tunnel management (ngrok/Cloudflare/Tailscale) |
| **generate_repo_files.py** | Generate connection files for repository |
| **validate_jules_setup.py** | Validate setup and configuration |
| **setup_for_jules.py** | Legacy setup script (still supported) |

---

## 🧪 Testing & Validation

| Script | Purpose |
|--------|---------|
| **test_ai_agent_connection.py** | Test Jules connection |
| **test_ai_agent_flexibility.py** | Test flexible connection methods |
| **test_mcp_server_complete.py** | Test MCP server functionality |
| **run_tests.py** | Run all tests |
| **simple_test_runner.py** | Simple test runner |
| **security_validator.py** | Validate security configuration |
| **production_validation.py** | Production readiness validation |

---

## 🖥️ Platform-Specific Directories

### `/linux/`
Linux-specific installation scripts and configurations
- Native Linux installation
- systemd service files
- Platform-specific utilities

### `/macos/`
macOS-specific installation scripts and configurations
- macOS installation
- LaunchDaemon configurations
- Platform-specific utilities

### `/windows/`
Windows-specific installation scripts and configurations
- Windows installation (PowerShell)
- Windows Service configurations
- Platform-specific utilities

### `/docker/`
Docker-based installation
- Dockerfile
- docker-compose.yml
- Container-specific configurations
- GPU support configuration

### `/virtualbox/`
VirtualBox VM configurations
- Pre-configured VM images
- Automated VM setup scripts

---

## 📝 Templates

### `/templates/`
Template files for generating repository files
- `.jules/` directory templates
- AGENTS.md template
- Connection info templates
- Configuration templates

---

## 🔍 Diagnostics

### `/diagnostics/`
Diagnostic and monitoring tools
- Tunnel reliability monitoring
- Health check scripts
- Performance monitoring
- Connection testing

---

## 🧪 Tests

### `/tests/`
Automated test suite
- Unit tests
- Integration tests
- Security tests
- Platform-specific tests

---

## 🛠️ Utility Scripts

| Script | Purpose |
|--------|---------|
| **config_manager.py** | Configuration management |
| **enhanced_mcp_hardware_server.py** | MCP hardware server |
| **deploy_for_ai_agent.py** | Deployment utilities |
| **setup.py** | Universal setup (legacy) |
| **setup.sh** | Shell-based setup (legacy) |
| **setup.ps1** | PowerShell setup (legacy) |

---

## 📦 Configuration Files

| File | Purpose |
|------|---------|
| **requirements.txt** | Python dependencies |
| **mcp-server-config.json** | MCP server configuration |
| **.gitignore** | Git ignore rules |
| **.env** | Environment variables (not committed) |

---

## 🗂️ Generated Files (Not in Repo)

These are created during setup:

### `generated_repo_files/`
Generated connection files for your project:
- `.jules/` - Connection configurations
- `AGENTS.md` - Agent capabilities
- `INSTRUCTIONS.md` - Setup instructions

---

## 📊 File Organization Philosophy

### Keep It Simple
- **One main script**: `jules_setup.py` for most users
- **Clear documentation**: Each doc has a specific purpose
- **No redundancy**: Removed duplicate/outdated docs

### User-Focused
- **Visual guides**: USER_FLOWS.md with flowcharts
- **Quick start**: README.md gets you started fast
- **Deep dive**: GETTING_STARTED.md for details
- **Reference**: QUICK_REFERENCE.md for commands

### Platform Support
- **Universal**: Works on Linux, macOS, Windows
- **Platform-specific**: Optimized installers per OS
- **Docker**: Containerized option
- **VirtualBox**: Pre-configured VMs

---

## 🎯 What to Use When

### First Time Setup
1. Read **README.md**
2. Check **USER_FLOWS.md** for your scenario
3. Run `python jules_setup.py`
4. Follow **GETTING_STARTED.md** if needed

### Troubleshooting
1. Check **TROUBLESHOOTING.md**
2. Run diagnostic scripts
3. Check platform-specific docs

### Advanced Usage
1. **QUICK_REFERENCE.md** - All commands
2. **JULES_EXAMPLE_WORKFLOWS.md** - Real examples
3. Platform-specific directories for customization

### Contributing
1. Read **CONTRIBUTING.md**
2. Check `/tests/` for test examples
3. Follow existing code patterns

---

## 🧹 What Was Removed

During cleanup, we removed:
- Redundant navigation files
- Duplicate setup guides
- Implementation status docs
- Outdated integration guides
- Redundant summaries
- Old checklist files

**Why?** To keep the repo clean, focused, and easy to navigate.

---

## 📈 Repository Stats

- **Core Scripts**: 5 main scripts
- **Documentation**: 7 essential docs
- **Test Scripts**: 7 validation tools
- **Platform Support**: 4 platforms (Linux, macOS, Windows, Docker)
- **Templates**: Complete set for file generation

---

**Everything you need, nothing you don't.** 🎯

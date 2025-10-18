# 🤖 Jules Hardware Access

**Give Jules secure remote access to your hardware in 5 minutes!**

Perfect for **Jules** (Google's AI coding agent) to test code on real hardware, use your GPU, and access your development environment.

---

## 📦 Two Repositories Explained

**Important:** This system uses two separate repositories:

1. **This Repo (Setup Tools)** - Clone once, use for all projects
   - Contains setup scripts and monitoring tools
   - Generates connection files
   - Stays on your local machine

2. **Your Project Repo** - Any repo where you want Jules to work
   - Gets the generated `.jules/` folder and `AGENTS.md`
   - Jules reads connection info from here
   - Commit and push to GitHub

**→ [HOW_IT_WORKS.md](HOW_IT_WORKS.md)** - Complete explanation with examples

---

## 🎯 What Jules Can Do

- ✅ **Test on Real Hardware** - Not just VMs, actual hardware
- ✅ **GPU Access** - Train ML models on your GPU
- ✅ **Custom Environments** - Test on specific OS/configurations
- ✅ **Performance Testing** - Real-world benchmarks
- ✅ **Full System Access** - Install packages, run commands

---

## 🤖 Universal Compatibility

While **optimized for Jules** (Google's AI coding agent), this system works with **any AI agent** that can:
- Clone git repositories
- Read JSON configuration files
- SSH into remote machines

**Supported Agents:**
- ✅ **Jules** (Google) - Primary focus, fully optimized
- ✅ **Claude** (Anthropic) - Works with explicit instructions
- ✅ **GPT-4** (OpenAI) - Works with Advanced Data Analysis
- ✅ **Custom AI agents** - With SSH capability

**→ [UNIVERSAL_SETUP.md](UNIVERSAL_SETUP.md)** - Setup guide for other AI agents

---

## ⚡ Two Setup Methods

### 🐳 Method 1: Docker (Recommended - Works Everywhere!)

**Works on Windows, macOS, and Linux**

```bash
cd docker
./setup.sh          # Linux/Mac
.\setup.ps1         # Windows PowerShell
```

**Why Docker?**
- ✅ Works on ALL platforms (Windows, Mac, Linux)
- ✅ Isolated from your system
- ✅ Easy to remove
- ✅ GPU support included
- ✅ 2-minute setup

**→ [docker/QUICK_START.md](docker/QUICK_START.md)** - Complete Docker guide

---

### 🖥️ Method 2: Native Installation

**For advanced users who want native performance**

```bash
# Interactive setup
python jules_setup.py

# With your GitHub repo
python jules_setup.py --repo username/repository
```

**→ [GETTING_STARTED.md](GETTING_STARTED.md)** - Native installation guide

---

## 🔄 Setup Options

**→ [USER_FLOWS.md](USER_FLOWS.md)** - Visual flowcharts for all scenarios

### Quick Reference

| Scenario | Method | Command | Time |
|----------|--------|---------|------|
| **First time (any OS)** | 🐳 Docker | `cd docker && ./setup.sh` | 2 min |
| **Windows** | 🐳 Docker | `cd docker && .\setup.ps1` | 2 min |
| **With GPU** | 🐳 Docker | Enable GPU in docker-compose.yml | 5 min |
| **Native Linux/Mac** | 🖥️ Native | `python jules_setup.py` | 5 min |
| **Multiple hardware** | Either | Run setup on each machine | 5 min each |
| **Enterprise** | 🖥️ Native | `python jules_setup.py --tunnel cloudflare --domain company.com` | 15 min |

---

## 🎯 Use Cases

- **Testing** - Jules tests your code on real hardware
- **ML/AI** - Train models on your GPU
- **Performance** - Benchmark on actual hardware
- **Integration** - Test with real databases/services
- **CI/CD** - Automated testing in pipelines

---

## 📖 Documentation

| Document | Purpose |
|----------|----------|
| **[HOW_IT_WORKS.md](HOW_IT_WORKS.md)** | ⭐ Two-repo system explained |
| **[docker/QUICK_START.md](docker/QUICK_START.md)** | 🐳 Docker setup (recommended) |
| **[SETUP_SIMPLIFIED.md](SETUP_SIMPLIFIED.md)** | Understanding the building blocks |
| **[USER_FLOWS.md](USER_FLOWS.md)** | Visual flowcharts for all scenarios |
| **[VISUAL_OVERVIEW.md](VISUAL_OVERVIEW.md)** | Complete visual guide with diagrams |
| **[GETTING_STARTED.md](GETTING_STARTED.md)** | Native installation guide |
| **[AGENTS.md](AGENTS.md)** | For Jules to read |
| **[JULES_EXAMPLE_WORKFLOWS.md](JULES_EXAMPLE_WORKFLOWS.md)** | Real workflow examples |
| **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** | All commands |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Fix common issues |

### 🛠️ Tools

| Tool | Purpose |
|------|---------|
| **`python setup.py`** | Unified setup (Docker/Native/Both) |
| **`python status.py`** | Status monitoring dashboard |
| **`./copy-to-project.sh`** | Copy files to your project (Linux/Mac) |
| **`.\copy-to-project.ps1`** | Copy files to your project (Windows) |

---

## 🔒 Security

- 🔐 **SSH key authentication** (no passwords)
- 🌐 **Encrypted tunnels** (Cloudflare/ngrok/Tailscale)
- 📝 **Complete audit logging** of all activities
- 👤 **Dedicated user account** for Jules
- ⚠️ **Use dedicated hardware** (VM recommended)

**Security Warning:** This gives Jules full access to your system. Use a dedicated machine or VM, not your primary computer.

---

## 🔧 How It Works

```mermaid
graph LR
    A[Jules AI] --> B[Encrypted Tunnel]
    B --> C[SSH Server]
    C --> D[Your Hardware]
```

1. **Tunnel Setup** - Creates secure encrypted tunnel (Cloudflare/ngrok/Tailscale)
2. **SSH Configuration** - Configures SSH with key-based authentication
3. **User Account** - Creates dedicated `jules` user with sudo access
4. **Connection Files** - Generates connection info for Jules

---

## 🚀 Quick Start

### 🐳 Docker Setup (Recommended - 2 Minutes)

**Step 1: Clone This Repo (Setup Tools)**
```bash
git clone <this-repo-url>
cd jules-hardware-access
```

**Step 2: Run Setup**
```bash
cd docker
./setup.sh          # Linux/Mac
.\setup.ps1         # Windows PowerShell
```

**Step 3: Edit .env File**
The script creates `.env` - add your:
- Cloudflare token (from https://one.dash.cloudflare.com/)
- SSH public key (from `cat ~/.ssh/id_rsa.pub`)

**Step 4: Run Setup Again**
```bash
./setup.sh          # Linux/Mac
.\setup.ps1         # Windows PowerShell
```

**Step 5: Copy Files to Your Project Repo**
```bash
# Easy way (using helper script):
./copy-to-project.sh ~/your-project-repo docker

# Or manual way:
cd ~/your-project-repo
cp -r ~/jules-hardware-access/generated_files/docker/.jules .
cp ~/jules-hardware-access/generated_files/docker/AGENTS.md .

# Commit and push YOUR project
cd ~/your-project-repo
git add .jules/ AGENTS.md
git commit -m "Add Jules hardware access"
git push
```

**Windows:**
```powershell
# Easy way:
.\copy-to-project.ps1 -ProjectPath C:\your-project-repo -Mode docker

# Or manual way:
cd C:\your-project-repo
Copy-Item -Recurse C:\jules-hardware-access\generated_files\docker\.jules .
Copy-Item C:\jules-hardware-access\generated_files\docker\AGENTS.md .
git add .jules/ AGENTS.md
git commit -m "Add Jules hardware access"
git push
```

**Done!** Jules can now access your hardware when working on your project.

**→ [docker/QUICK_START.md](docker/QUICK_START.md)** - Detailed Docker guide  
**→ [HOW_IT_WORKS.md](HOW_IT_WORKS.md)** - Understanding the two-repo system

---

### 🖥️ Native Setup (Advanced)

```bash
# In this repo (setup tools)
python setup.py
# Follow interactive prompts

# Copy to your project
cp -r generated_files/native/.jules ~/your-project/
cp generated_files/native/AGENTS.md ~/your-project/
```

**→ [GETTING_STARTED.md](GETTING_STARTED.md)** - Native installation guide

---

## 🛠️ Advanced Options

### Multiple Hardware
```bash
# Setup on each machine
python jules_setup.py --hardware-name "Laptop"
python jules_setup.py --hardware-name "GPU Server"
python jules_setup.py --hardware-name "Cloud VM"
```

### Enterprise Setup
```bash
python jules_setup.py --tunnel cloudflare --domain company.com
```

### CI/CD Integration
```bash
python jules_setup.py --ci-mode
```

### Cloud Deployment
```bash
python jules_setup.py --cloud aws  # or azure, gcp
```

---

## 🔧 Troubleshooting

### Quick Diagnostics
```bash
# Check tunnel status
python tunnel_manager.py status

# Validate setup
python validate_jules_setup.py

# Test connection
python test_ai_agent_connection.py
```

### Common Issues

**Tunnel not starting?**
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Run: `python tunnel_manager.py status`

**SSH connection failing?**
- Run: `python validate_jules_setup.py`
- Check SSH key permissions

**Need help?**
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions

---

## 📋 What Gets Installed

- **Tunnel Software** - Cloudflare/ngrok/Tailscale (your choice)
- **SSH Server** - OpenSSH with secure configuration
- **Jules User** - Dedicated user account with sudo access
- **Connection Files** - Ready-to-use connection info for Jules

---

## 🗑️ Uninstallation

```bash
# Remove everything
./uninstall.sh

# Platform-specific
./docker/uninstall.sh      # Docker installation
sudo ./linux/uninstall.sh  # Native Linux installation
```

---

## 💻 System Requirements

**Minimum:**
- 2 CPU cores
- 4GB RAM
- 10GB disk space
- Linux, macOS, or Windows

**Recommended for GPU:**
- 4+ CPU cores
- 8GB+ RAM
- NVIDIA GPU with CUDA
- SSD storage

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📚 Learn More

- **[INDEX.md](INDEX.md)** - Complete documentation index
- **[USER_FLOWS.md](USER_FLOWS.md)** - Visual flowcharts for all scenarios
- **[VISUAL_OVERVIEW.md](VISUAL_OVERVIEW.md)** - Complete visual guide
- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Detailed walkthrough
- **[AGENTS.md](AGENTS.md)** - What Jules needs to know
- **[JULES_EXAMPLE_WORKFLOWS.md](JULES_EXAMPLE_WORKFLOWS.md)** - Real examples
- **[REPOSITORY_STRUCTURE.md](REPOSITORY_STRUCTURE.md)** - Repository organization

---

**Ready to get started?** Run `python jules_setup.py` and follow the prompts! 🚀

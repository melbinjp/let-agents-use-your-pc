# Quick Reference - Jules Hardware Access

## 🚀 Setup (5 Minutes)

```bash
# 1. Setup for Jules
python setup_for_jules.py

# 2. Validate setup
python validate_jules_setup.py

# 3. Start server
python enhanced_mcp_hardware_server.py

# 4. Share with Jules
# File: ai_agent_connection.json
```

## 📚 Documentation Quick Links

| Need | Document |
|------|----------|
| **Jules reference** | [AGENTS.md](AGENTS.md) |
| **Setup guide** | [JULES_INTEGRATION_GUIDE.md](JULES_INTEGRATION_GUIDE.md) |
| **Examples** | [JULES_EXAMPLE_WORKFLOWS.md](JULES_EXAMPLE_WORKFLOWS.md) |
| **Quick start** | [QUICK_START.md](QUICK_START.md) |
| **Troubleshooting** | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| **Tool reference** | [AI_AGENT_USAGE_GUIDE.md](AI_AGENT_USAGE_GUIDE.md) |

## 🎯 Common Commands

### Setup & Validation
```bash
# Setup for Jules
python setup_for_jules.py

# Validate setup
python validate_jules_setup.py

# Test connection
python test_ai_agent_connection.py
```

### Server Management
```bash
# Start server
python enhanced_mcp_hardware_server.py

# Start in background
nohup python enhanced_mcp_hardware_server.py > mcp_server.log 2>&1 &

# Stop server
pkill -f enhanced_mcp_hardware_server.py
```

### Monitoring
```bash
# Watch logs
tail -f mcp-hardware-server.log

# Monitor system
htop

# Check Jules activity
sudo journalctl -u ssh -f | grep jules

# Check GPU
nvidia-smi
```

### Testing
```bash
# Test SSH connection
ssh -i jules_key jules@your-tunnel-hostname

# Test command execution
ssh -i jules_key jules@your-tunnel-hostname "echo test"

# Test sudo access
ssh -i jules_key jules@your-tunnel-hostname "sudo echo test"
```

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `mcp-server-config.json` | MCP server configuration |
| `ai_agent_connection.json` | Connection info for Jules |
| `ai_agent_connection.txt` | Human-readable connection info |
| `jules_key` | SSH private key (keep secure!) |
| `jules_key.pub` | SSH public key |

## 🎯 Jules Capabilities

### Command Execution
```json
{
  "tool": "execute_command",
  "arguments": {
    "command": "your-command",
    "bypass_security": true
  }
}
```

### Docker Operations
```json
{
  "tool": "docker_operations",
  "arguments": {
    "operation": "run",
    "image": "python:3.9"
  }
}
```

### Environment Setup
```json
{
  "tool": "environment_setup",
  "arguments": {
    "environment_type": "python",
    "workspace_path": "/tmp/jules_workspace"
  }
}
```

### File Transfer
```json
{
  "tool": "bulk_file_transfer",
  "arguments": {
    "operation": "upload",
    "source": "content",
    "destination": "/path/to/file"
  }
}
```

### System Monitoring
```json
{
  "tool": "system_monitoring",
  "arguments": {
    "metrics": ["cpu", "memory", "gpu"]
  }
}
```

## 🔒 Security

### Features
- ✅ SSH key authentication only
- ✅ Complete audit logging
- ✅ Rate limiting (120 req/min)
- ✅ Dedicated user account
- ✅ Sudo access control

### Best Practices
1. Use dedicated hardware (VM recommended)
2. Monitor logs regularly
3. Rotate SSH keys monthly
4. Review Jules changes before merging
5. Backup data before Jules access

## 🐛 Troubleshooting

### Connection Issues
```bash
# Check server status
ps aux | grep enhanced_mcp

# Check SSH service
sudo systemctl status ssh

# Test tunnel
curl https://your-tunnel.trycloudflare.com

# Check SSH key permissions
ls -la jules_key*
```

### Permission Issues
```bash
# Check Jules user
id jules

# Check sudo access
sudo -l -U jules

# Check SSH directory
ls -la /home/jules/.ssh/
```

### Performance Issues
```bash
# Check system resources
htop
df -h
free -h

# Check network
ping 8.8.8.8

# Check GPU
nvidia-smi
```

## 📊 Monitoring

### Real-Time
```bash
# Watch logs
tail -f mcp-hardware-server.log

# Monitor system
htop

# Monitor GPU
watch -n 1 nvidia-smi

# Monitor network
sudo netstat -tulpn | grep :22
```

### Audit Logs
Location: `mcp-hardware-server.log`

Contains:
- Command executions
- Security events
- Connection attempts
- Resource usage
- Error messages

## 🎯 Example Jules Prompts

### Test Repository
```
Jules, using my hardware (.jules/hardware_connection.json):
1. Clone the repository
2. Run the test suite
3. Report any failures
```

### Train ML Model
```
Jules, I have a GPU (.jules/hardware_connection.json):
1. Check GPU with nvidia-smi
2. Set up PyTorch environment
3. Train the model
4. Monitor GPU usage
```

### Docker Testing
```
Jules, using my hardware (.jules/hardware_connection.json):
1. Build Docker image
2. Run integration tests
3. Check logs
4. Clean up containers
```

## 📁 File Locations

### On Your Machine
```
mcp-hardware-server/
├── enhanced_mcp_hardware_server.py  # MCP server
├── mcp-server-config.json           # Configuration
├── ai_agent_connection.json         # Connection info
├── jules_key                        # Private key
├── jules_key.pub                    # Public key
└── mcp-hardware-server.log          # Activity log
```

### On Jules Side
```
your-repository/
├── .jules/
│   └── hardware_connection.json     # Connection info
├── src/
├── tests/
└── README.md
```

## 🔄 Workflow

### User Setup
1. Run `python setup_for_jules.py`
2. Validate with `python validate_jules_setup.py`
3. Start server: `python enhanced_mcp_hardware_server.py`
4. Share `ai_agent_connection.json` with Jules

### Jules Usage
1. Discover hardware connection
2. Connect via SSH
3. Execute tasks with MCP tools
4. Monitor resources
5. Clean up temporary files

### Monitoring
1. Watch logs: `tail -f mcp-hardware-server.log`
2. Monitor system: `htop`
3. Check Jules activity: `journalctl -u ssh -f | grep jules`
4. Review audit trail

## 💡 Tips

### Performance
- Use SSD for Jules workspace
- Ensure adequate RAM (8GB+)
- Good internet connection
- Latest GPU drivers for ML tasks

### Security
- Use dedicated hardware
- Monitor logs regularly
- Rotate SSH keys monthly
- Review changes before merging
- Backup important data

### Efficiency
- Clean up temporary files
- Use working directories
- Batch operations when possible
- Monitor resource usage
- Set appropriate timeouts

## 📞 Getting Help

### Self-Help
1. Check logs: `tail -f mcp-hardware-server.log`
2. Run validation: `python validate_jules_setup.py`
3. Test connection: `python test_ai_agent_connection.py`
4. Review documentation

### Documentation
- **AGENTS.md** - Jules reference
- **JULES_INTEGRATION_GUIDE.md** - Complete guide
- **JULES_EXAMPLE_WORKFLOWS.md** - Examples
- **TROUBLESHOOTING.md** - Common issues

### Testing
```bash
# Validate setup
python validate_jules_setup.py

# Test connection
python test_ai_agent_connection.py

# Test flexibility
python test_ai_agent_flexibility.py

# Test MCP server
python test_mcp_server_complete.py
```

## 🎓 Learning Path

### Beginner
1. Read README.md
2. Run setup_for_jules.py
3. Validate setup
4. Share connection with Jules
5. Try simple Jules task

### Intermediate
1. Review JULES_INTEGRATION_GUIDE.md
2. Try example workflows
3. Monitor Jules activity
4. Customize configuration
5. Optimize performance

### Advanced
1. Review AGENTS.md
2. Create custom workflows
3. Multi-platform testing
4. CI/CD integration
5. Enterprise deployment

## 🌟 Key Features

### For Jules
- ✅ Unrestricted command execution
- ✅ Docker management
- ✅ GPU access
- ✅ Environment setup
- ✅ File operations
- ✅ System monitoring

### For Users
- ✅ Easy setup (5 minutes)
- ✅ Clear documentation
- ✅ Validation tools
- ✅ Example workflows
- ✅ Monitoring tools

### For Enterprises
- ✅ Enterprise security
- ✅ Audit trail
- ✅ Scalability
- ✅ Compliance
- ✅ Professional docs

## 📈 Status

- ✅ Production Ready
- ✅ Jules Optimized
- ✅ Fully Documented
- ✅ Tested & Validated
- ✅ Enterprise Grade

---

**Quick Start**: `python setup_for_jules.py`
**Documentation**: [AGENTS.md](AGENTS.md)
**Examples**: [JULES_EXAMPLE_WORKFLOWS.md](JULES_EXAMPLE_WORKFLOWS.md)
**Support**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

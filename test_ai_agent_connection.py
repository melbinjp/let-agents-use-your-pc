#!/usr/bin/env python3
"""
AI Agent Connection Tester
Tests connection to deployed MCP hardware server
"""

import json
import asyncio
import paramiko
import sys
from pathlib import Path
from typing import Dict, Any, Optional

class AIAgentConnectionTester:
    """Tests AI agent connection to hardware server"""
    
    def __init__(self, connection_file: str = "ai_agent_connection.json"):
        self.connection_file = connection_file
        self.connection_info = None
        
    def load_connection_info(self) -> bool:
        """Load connection information"""
        try:
            with open(self.connection_file, 'r') as f:
                self.connection_info = json.load(f)
            return True
        except FileNotFoundError:
            print(f"❌ Connection file not found: {self.connection_file}")
            return False
        except json.JSONDecodeError:
            print(f"❌ Invalid JSON in connection file: {self.connection_file}")
            return False
    
    async def test_ssh_connection(self) -> bool:
        """Test SSH connection"""
        print("🔐 Testing SSH connection...")
        
        ssh_config = self.connection_info['ssh_config']
        
        try:
            # Create SSH client
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Create private key from string
            import io
            private_key_file = io.StringIO(ssh_config['private_key'])
            private_key = paramiko.Ed25519Key.from_private_key(private_key_file)
            
            # Connect
            ssh.connect(
                hostname=ssh_config['hostname'],
                port=ssh_config['port'],
                username=ssh_config['username'],
                pkey=private_key,
                timeout=10
            )
            
            # Test basic command
            stdin, stdout, stderr = ssh.exec_command('echo "AI Agent Connection Test"')
            result = stdout.read().decode().strip()
            
            ssh.close()
            
            if result == "AI Agent Connection Test":
                print("✅ SSH connection successful")
                return True
            else:
                print(f"❌ SSH connection failed: unexpected output")
                return False
                
        except Exception as e:
            print(f"❌ SSH connection failed: {e}")
            return False
    
    async def test_system_access(self) -> bool:
        """Test system access capabilities"""
        print("🖥️ Testing system access...")
        
        ssh_config = self.connection_info['ssh_config']
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            import io
            private_key_file = io.StringIO(ssh_config['private_key'])
            private_key = paramiko.Ed25519Key.from_private_key(private_key_file)
            
            ssh.connect(
                hostname=ssh_config['hostname'],
                port=ssh_config['port'],
                username=ssh_config['username'],
                pkey=private_key,
                timeout=10
            )
            
            # Test various system commands
            test_commands = [
                ("System info", "uname -a"),
                ("Current user", "whoami"),
                ("Home directory", "pwd"),
                ("Python version", "python3 --version"),
                ("Disk space", "df -h /"),
                ("Memory info", "free -h"),
                ("Process list", "ps aux | head -5")
            ]
            
            results = []
            for test_name, command in test_commands:
                try:
                    stdin, stdout, stderr = ssh.exec_command(command, timeout=5)
                    output = stdout.read().decode().strip()
                    error = stderr.read().decode().strip()
                    
                    if output:
                        results.append(f"✅ {test_name}: {output[:50]}...")
                    elif error:
                        results.append(f"⚠️ {test_name}: {error[:50]}...")
                    else:
                        results.append(f"❌ {test_name}: No output")
                        
                except Exception as e:
                    results.append(f"❌ {test_name}: {str(e)[:50]}...")
            
            ssh.close()
            
            # Print results
            for result in results:
                print(f"  {result}")
            
            success_count = sum(1 for r in results if r.startswith("  ✅"))
            total_count = len(results)
            
            if success_count >= total_count * 0.7:  # 70% success rate
                print(f"✅ System access working ({success_count}/{total_count} tests passed)")
                return True
            else:
                print(f"❌ System access limited ({success_count}/{total_count} tests passed)")
                return False
                
        except Exception as e:
            print(f"❌ System access test failed: {e}")
            return False
    
    async def test_sudo_access(self) -> bool:
        """Test sudo access"""
        print("🔑 Testing sudo access...")
        
        ssh_config = self.connection_info['ssh_config']
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            import io
            private_key_file = io.StringIO(ssh_config['private_key'])
            private_key = paramiko.Ed25519Key.from_private_key(private_key_file)
            
            ssh.connect(
                hostname=ssh_config['hostname'],
                port=ssh_config['port'],
                username=ssh_config['username'],
                pkey=private_key,
                timeout=10
            )
            
            # Test sudo command
            stdin, stdout, stderr = ssh.exec_command('sudo echo "Sudo test successful"', timeout=10)
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            ssh.close()
            
            if "Sudo test successful" in output:
                print("✅ Sudo access confirmed")
                return True
            elif "password" in error.lower():
                print("⚠️ Sudo requires password (passwordless sudo not configured)")
                return False
            else:
                print(f"❌ Sudo access failed: {error}")
                return False
                
        except Exception as e:
            print(f"❌ Sudo access test failed: {e}")
            return False
    
    async def test_docker_access(self) -> bool:
        """Test Docker access"""
        print("🐳 Testing Docker access...")
        
        ssh_config = self.connection_info['ssh_config']
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            import io
            private_key_file = io.StringIO(ssh_config['private_key'])
            private_key = paramiko.Ed25519Key.from_private_key(private_key_file)
            
            ssh.connect(
                hostname=ssh_config['hostname'],
                port=ssh_config['port'],
                username=ssh_config['username'],
                pkey=private_key,
                timeout=10
            )
            
            # Test Docker command
            stdin, stdout, stderr = ssh.exec_command('docker --version', timeout=10)
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            ssh.close()
            
            if "Docker version" in output:
                print(f"✅ Docker available: {output}")
                return True
            else:
                print("⚠️ Docker not available (not critical)")
                return True  # Not critical for basic functionality
                
        except Exception as e:
            print(f"⚠️ Docker test failed: {e} (not critical)")
            return True  # Not critical for basic functionality
    
    def print_connection_summary(self):
        """Print connection information summary"""
        print("\n📋 Connection Information Summary")
        print("=" * 40)
        
        ssh_config = self.connection_info['ssh_config']
        system_info = self.connection_info['system_info']
        
        print(f"Hostname: {ssh_config['hostname']}")
        print(f"Port: {ssh_config['port']}")
        print(f"Username: {ssh_config['username']}")
        print(f"System: {system_info['os']} {system_info['architecture']}")
        print(f"Device: {system_info['hostname']}")
        
        print(f"\nCapabilities:")
        for capability in self.connection_info['capabilities']:
            print(f"  • {capability.replace('_', ' ').title()}")
        
        print(f"\nSecurity Settings:")
        security = self.connection_info['security']
        print(f"  • AI Agent Mode: {security['ai_agent_mode']}")
        print(f"  • Sudo Access: {security['sudo_access']}")
        print(f"  • Rate Limit: {security['rate_limit']}")
    
    async def run_all_tests(self) -> bool:
        """Run all connection tests"""
        
        print("🤖 AI Agent Connection Tester")
        print("=" * 40)
        
        if not self.load_connection_info():
            return False
        
        self.print_connection_summary()
        
        print(f"\n🧪 Running Connection Tests")
        print("-" * 30)
        
        tests = [
            ("SSH Connection", self.test_ssh_connection),
            ("System Access", self.test_system_access),
            ("Sudo Access", self.test_sudo_access),
            ("Docker Access", self.test_docker_access),
        ]
        
        results = []
        
        for test_name, test_func in tests:
            try:
                result = await test_func()
                results.append((test_name, result))
            except Exception as e:
                print(f"❌ {test_name} crashed: {e}")
                results.append((test_name, False))
        
        # Summary
        print(f"\n📊 Test Results")
        print("-" * 20)
        
        passed = sum(1 for _, result in results if result)
        total = len(results)
        
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{test_name}: {status}")
        
        print(f"\nOverall: {passed}/{total} tests passed ({(passed/total)*100:.1f}%)")
        
        if passed == total:
            print("\n🎉 All tests passed! AI agent can access this hardware.")
            print("\n🚀 Ready for AI agent operations:")
            print("  • Execute any system commands")
            print("  • Install and manage software")
            print("  • Access files and directories")
            print("  • Run development environments")
            print("  • Monitor system resources")
            return True
        elif passed >= total * 0.75:
            print("\n⚠️ Most tests passed. Some features may be limited.")
            return True
        else:
            print("\n❌ Multiple test failures. Check configuration.")
            return False

async def main():
    """Main testing function"""
    
    # Check for connection file
    connection_files = ["ai_agent_connection.json", "connection.json"]
    connection_file = None
    
    for file in connection_files:
        if Path(file).exists():
            connection_file = file
            break
    
    if not connection_file:
        print("❌ No connection file found.")
        print("Expected files: ai_agent_connection.json or connection.json")
        print("Run deploy_for_ai_agent.py first to create connection info.")
        return 1
    
    tester = AIAgentConnectionTester(connection_file)
    
    try:
        success = await tester.run_all_tests()
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\n\n⚠️ Testing interrupted by user.")
        return 1
    except Exception as e:
        print(f"\n❌ Testing failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
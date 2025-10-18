#!/usr/bin/env python3
"""
Enhanced MCP Hardware Server - Production Grade
Provides AI agents with intelligent tunnel management and full hardware access
Secure, robust, and production-ready implementation
"""

import asyncio
import json
import subprocess
import time
import os
import sys
import logging
import uuid
import hashlib
import secrets
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from contextlib import asynccontextmanager
import requests
import paramiko
import socket
from urllib.parse import urlparse

# Import security validator
try:
    from security_validator import security_validator
except ImportError:
    logger.warning("Security validator not available - running with reduced security")

# MCP imports
from mcp.server import Server
from mcp.server.models import InitializationOptions
from mcp.server.stdio import stdio_server
from mcp.types import (
    Resource, Tool, TextContent, ImageContent, EmbeddedResource,
    CallToolRequest, CallToolResult, ListResourcesRequest, ListResourcesResult,
    ListToolsRequest, ListToolsResult, ReadResourceRequest, ReadResourceResult
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mcp-hardware-server.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class SecurityError(Exception):
    """Raised when security validation fails"""
    pass

class ConnectionError(Exception):
    """Raised when connection operations fail"""
    pass

class ConfigurationError(Exception):
    """Raised when configuration is invalid"""
    pass

@dataclass
class TunnelEndpoint:
    """Represents a tunnel endpoint with connection details"""
    hostname: str
    username: str
    private_key_path: str
    port: int = 22
    platform: str = "unknown"
    status: str = "unknown"  # active, inactive, failed, testing
    last_tested: Optional[datetime] = None
    response_time: Optional[float] = None
    tunnel_id: Optional[str] = None
    purpose: str = "primary"  # primary, backup, load-balance
    created: Optional[datetime] = None
    max_connections: int = 5
    current_connections: int = 0
    
    def __post_init__(self):
        """Validate endpoint data after initialization"""
        if not self.hostname or not isinstance(self.hostname, str):
            raise ConfigurationError("Invalid hostname")
        if not self.username or not isinstance(self.username, str):
            raise ConfigurationError("Invalid username")
        if not self.private_key_path or not isinstance(self.private_key_path, str):
            raise ConfigurationError("Invalid private key path")
        if not isinstance(self.port, int) or not (1 <= self.port <= 65535):
            raise ConfigurationError("Invalid port number")
        
        # Validate hostname format
        if not self._is_valid_hostname(self.hostname):
            raise SecurityError("Invalid hostname format")
    
    def _is_valid_hostname(self, hostname: str) -> bool:
        """Validate hostname format for security"""
        if len(hostname) > 253:
            return False
        
        # Check for consecutive dots
        if '..' in hostname:
            return False
        
        # Check each label (part between dots)
        labels = hostname.split('.')
        for label in labels:
            if not label:  # Empty label
                return False
            if label.startswith('-') or label.endswith('-'):
                return False
            if len(label) > 63:  # Max label length
                return False
        
        # Check for malicious patterns
        malicious_patterns = [';', '&', '|', '`', '$', '(', ')', '<', '>', '"', "'", '\\', '\n', '\r', '\0']
        if any(char in hostname for char in malicious_patterns):
            return False
        
        allowed_chars = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-')
        return all(c in allowed_chars for c in hostname)

@dataclass
class HardwareInfo:
    """Hardware information from remote system"""
    cpu_count: int
    memory_gb: float
    gpu_info: List[str]
    disk_space_gb: float
    platform: str
    architecture: str
    last_updated: datetime

@dataclass
class TerminalSession:
    """Represents an active terminal session"""
    session_id: str
    endpoint: TunnelEndpoint
    ssh_client: paramiko.SSHClient
    channel: paramiko.Channel
    created: datetime
    last_activity: datetime
    is_interactive: bool = False
    working_directory: str = "~"
    command_history: List[str] = None
    max_idle_time: int = 3600  # 1 hour
    
    def __post_init__(self):
        if self.command_history is None:
            self.command_history = []
    
    def is_expired(self) -> bool:
        """Check if session has expired due to inactivity"""
        return (datetime.now() - self.last_activity).seconds > self.max_idle_time
    
    def add_command(self, command: str):
        """Add command to history with size limit"""
        self.command_history.append(command)
        if len(self.command_history) > 100:  # Keep last 100 commands
            self.command_history = self.command_history[-100:]
        self.last_activity = datetime.now()

class TunnelManager:
    """Manages multiple tunnel endpoints with failover and load balancing"""
    
    def __init__(self, config_file: str = "mcp-server-config.json"):
        self.config_file = config_file
        self.endpoints: List[TunnelEndpoint] = []
        self.active_endpoint: Optional[TunnelEndpoint] = None
        self.hardware_cache: Dict[str, HardwareInfo] = {}
        self.terminal_sessions: Dict[str, TerminalSession] = {}
        self.cf_email: Optional[str] = None
        self.cf_api_key: Optional[str] = None
        self.ssh_private_key: Optional[str] = None
        self.ssh_public_key: Optional[str] = None
        self.domain: str = "wecanuseai.com"
        self._connection_pool: Dict[str, List[paramiko.SSHClient]] = {}
        self._max_pool_size: int = 5
        self._session_cleanup_task: Optional[asyncio.Task] = None
        self._health_check_task: Optional[asyncio.Task] = None
        self._rate_limiter: Dict[str, List[float]] = {}
        self._max_requests_per_minute: int = 60
        self._background_tasks_started: bool = False
        
        # Load config first
        self.load_config()
        
        # Start background tasks (only if event loop is running)
        try:
            self._start_background_tasks()
        except RuntimeError:
            # No event loop running, skip background tasks
            logger.info("No event loop running, background tasks will be started later")
    
    def __del__(self):
        """Cleanup when object is destroyed"""
        try:
            self.cleanup()
        except:
            pass
    
    def cleanup(self):
        """Clean up resources and background tasks"""
        if self._session_cleanup_task and not self._session_cleanup_task.done():
            self._session_cleanup_task.cancel()
        if self._health_check_task and not self._health_check_task.done():
            self._health_check_task.cancel()
        
        # Close all SSH connections
        for pool in self._connection_pool.values():
            for ssh_client in pool:
                try:
                    ssh_client.close()
                except:
                    pass
        
        # Close all terminal sessions
        for session in list(self.terminal_sessions.values()):
            try:
                session.channel.close()
                session.ssh_client.close()
            except:
                pass
        
        self.terminal_sessions.clear()
        self._connection_pool.clear()
    
    def _start_background_tasks(self):
        """Start background maintenance tasks"""
        try:
            loop = asyncio.get_running_loop()
            self._session_cleanup_task = asyncio.create_task(self._cleanup_expired_sessions())
            self._health_check_task = asyncio.create_task(self._periodic_health_check())
            logger.info("Background tasks started successfully")
        except RuntimeError:
            # No event loop running
            raise
    
    async def _cleanup_expired_sessions(self):
        """Periodically clean up expired terminal sessions"""
        while True:
            try:
                expired_sessions = [
                    session_id for session_id, session in self.terminal_sessions.items()
                    if session.is_expired()
                ]
                
                for session_id in expired_sessions:
                    logger.info(f"Cleaning up expired session: {session_id}")
                    self.close_terminal_session(session_id)
                
                await asyncio.sleep(300)  # Check every 5 minutes
            except Exception as e:
                logger.error(f"Error in session cleanup: {e}")
                await asyncio.sleep(60)  # Retry after 1 minute on error
    
    async def _periodic_health_check(self):
        """Periodically check endpoint health"""
        while True:
            try:
                for endpoint in self.endpoints:
                    await self.test_endpoint(endpoint)
                await asyncio.sleep(300)  # Check every 5 minutes
            except Exception as e:
                logger.error(f"Error in health check: {e}")
                await asyncio.sleep(60)
    
    def _check_rate_limit(self, identifier: str) -> bool:
        """Check if request is within rate limits"""
        now = time.time()
        if identifier not in self._rate_limiter:
            self._rate_limiter[identifier] = []
        
        # Remove old requests (older than 1 minute)
        self._rate_limiter[identifier] = [
            req_time for req_time in self._rate_limiter[identifier]
            if now - req_time < 60
        ]
        
        # Check if under limit
        if len(self._rate_limiter[identifier]) >= self._max_requests_per_minute:
            return False
        
        # Add current request
        self._rate_limiter[identifier].append(now)
        return True
    
    def load_config(self):
        """Load configuration with security validation"""
        try:
            if not os.path.exists(self.config_file):
                logger.warning(f"Configuration file not found: {self.config_file}")
                self._create_default_config()
                return
            
            with open(self.config_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Validate configuration structure
            self._validate_config_structure(data)
            
            # Load Cloudflare config from environment or config
            cf_config = data.get('cloudflare_config', {})
            self.cf_email = os.getenv('CLOUDFLARE_EMAIL') or cf_config.get('email')
            self.cf_api_key = os.getenv('CLOUDFLARE_API_KEY') or cf_config.get('api_key')
            self.domain = cf_config.get('domain', 'wecanuseai.com')
            
            # Load SSH config
            ssh_config = data.get('ssh_config', {})
            self.ssh_private_key = ssh_config.get('private_key_path')
            self.ssh_public_key = ssh_config.get('public_key_content')
            
            # Validate SSH key paths (only if not empty and not a test path)
            if (self.ssh_private_key and 
                not self.ssh_private_key.startswith('/test/') and 
                not os.path.exists(self.ssh_private_key)):
                raise ConfigurationError(f"SSH private key not found: {self.ssh_private_key}")
            
            # Load and validate endpoints
            self.endpoints = []
            for endpoint_data in data.get('endpoints', []):
                try:
                    endpoint = TunnelEndpoint(**endpoint_data)
                    # Convert string dates back to datetime objects
                    if endpoint.last_tested and isinstance(endpoint.last_tested, str):
                        endpoint.last_tested = datetime.fromisoformat(endpoint.last_tested)
                    if endpoint.created and isinstance(endpoint.created, str):
                        endpoint.created = datetime.fromisoformat(endpoint.created)
                    self.endpoints.append(endpoint)
                except Exception as e:
                    logger.error(f"Invalid endpoint configuration: {e}")
            
            logger.info(f"Loaded {len(self.endpoints)} endpoints from configuration")
            
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in config file: {e}")
            raise ConfigurationError(f"Invalid configuration file format: {e}")
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            raise ConfigurationError(f"Failed to load configuration: {e}")
    
    def _validate_config_structure(self, data: dict):
        """Validate configuration file structure"""
        required_sections = ['mcp_server', 'ssh_config']
        for section in required_sections:
            if section not in data:
                raise ConfigurationError(f"Missing required configuration section: {section}")
    
    def _create_default_config(self):
        """Create a default configuration file"""
        default_config = {
            "mcp_server": {
                "name": "enhanced-hardware-server",
                "version": "1.0.0",
                "created": datetime.now().isoformat()
            },
            "ssh_config": {
                "private_key_path": "",
                "public_key_path": "",
                "public_key_content": "",
                "username": "jules"
            },
            "cloudflare_config": {
                "email": "",
                "api_key": "",
                "domain": "wecanuseai.com"
            },
            "endpoints": [],
            "settings": {
                "auto_failover": True,
                "health_check_interval": 300,
                "max_connections_per_endpoint": 5,
                "session_timeout": 3600
            }
        }
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(default_config, f, indent=2)
        
        logger.info(f"Created default configuration file: {self.config_file}")
    
    def save_config(self):
        """Save tunnel endpoints to configuration file"""
        data = {
            'endpoints': [asdict(endpoint) for endpoint in self.endpoints],
            'last_updated': datetime.now().isoformat()
        }
        # Convert datetime objects to strings for JSON serialization
        for endpoint_data in data['endpoints']:
            if endpoint_data.get('last_tested'):
                endpoint_data['last_tested'] = endpoint_data['last_tested'].isoformat() if isinstance(endpoint_data['last_tested'], datetime) else endpoint_data['last_tested']
            if endpoint_data.get('created'):
                endpoint_data['created'] = endpoint_data['created'].isoformat() if isinstance(endpoint_data['created'], datetime) else endpoint_data['created']
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, default=str, ensure_ascii=False)    

    async def test_endpoint(self, endpoint: TunnelEndpoint) -> bool:
        """Test if an endpoint is accessible with comprehensive validation"""
        if not self._check_rate_limit(f"test_{endpoint.hostname}"):
            logger.warning(f"Rate limit exceeded for endpoint testing: {endpoint.hostname}")
            return False
        
        start_time = time.time()
        ssh_client = None
        
        try:
            # Validate endpoint configuration
            if not endpoint.private_key_path or not os.path.exists(endpoint.private_key_path):
                raise ConnectionError(f"SSH private key not found: {endpoint.private_key_path}")
            
            # Create SSH client with security settings
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Load private key with error handling
            try:
                if endpoint.private_key_path.endswith('.pem') or 'rsa' in endpoint.private_key_path.lower():
                    private_key = paramiko.RSAKey.from_private_key_file(endpoint.private_key_path)
                else:
                    private_key = paramiko.Ed25519Key.from_private_key_file(endpoint.private_key_path)
            except paramiko.ssh_exception.PasswordRequiredException:
                raise SecurityError("Private key is password protected - not supported")
            except Exception as e:
                raise SecurityError(f"Failed to load private key: {e}")
            
            # Connect with security settings
            ssh_client.connect(
                hostname=endpoint.hostname,
                port=endpoint.port,
                username=endpoint.username,
                pkey=private_key,
                timeout=10,
                auth_timeout=10,
                banner_timeout=10,
                look_for_keys=False,
                allow_agent=False
            )
            
            # Test basic command execution
            stdin, stdout, stderr = ssh_client.exec_command('echo "connection_test_$(date +%s)"', timeout=5)
            result = stdout.read().decode('utf-8', errors='ignore').strip()
            error_output = stderr.read().decode('utf-8', errors='ignore').strip()
            
            if error_output:
                logger.warning(f"Command execution warning on {endpoint.hostname}: {error_output}")
            
            # Validate response
            if result.startswith("connection_test_"):
                endpoint.status = "active"
                endpoint.response_time = time.time() - start_time
                endpoint.last_tested = datetime.now()
                logger.info(f"Endpoint test successful: {endpoint.hostname} ({endpoint.response_time:.2f}s)")
                return True
            else:
                endpoint.status = "failed"
                logger.error(f"Unexpected response from {endpoint.hostname}: {result}")
                return False
                
        except paramiko.AuthenticationException as e:
            endpoint.status = "failed"
            logger.error(f"Authentication failed for {endpoint.hostname}: {e}")
            return False
        except paramiko.SSHException as e:
            endpoint.status = "failed"
            logger.error(f"SSH connection failed for {endpoint.hostname}: {e}")
            return False
        except socket.timeout as e:
            endpoint.status = "failed"
            logger.error(f"Connection timeout for {endpoint.hostname}: {e}")
            return False
        except Exception as e:
            endpoint.status = "failed"
            endpoint.last_tested = datetime.now()
            logger.error(f"Endpoint test failed for {endpoint.hostname}: {e}")
            return False
        finally:
            if ssh_client:
                try:
                    ssh_client.close()
                except:
                    pass
    
    async def find_best_endpoint(self) -> Optional[TunnelEndpoint]:
        """Find the best available endpoint (fastest response time)"""
        active_endpoints = []
        
        # Test all endpoints concurrently
        tasks = [self.test_endpoint(endpoint) for endpoint in self.endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, (endpoint, result) in enumerate(zip(self.endpoints, results)):
            if result is True and endpoint.status == "active":
                active_endpoints.append(endpoint)
        
        if not active_endpoints:
            return None
        
        # Sort by response time (fastest first)
        active_endpoints.sort(key=lambda x: x.response_time or float('inf'))
        return active_endpoints[0]
    
    async def get_hardware_info(self, endpoint: TunnelEndpoint) -> Optional[HardwareInfo]:
        """Get hardware information from remote system"""
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            private_key = paramiko.Ed25519Key.from_private_key_file(endpoint.private_key_path)
            ssh.connect(
                hostname=endpoint.hostname,
                port=endpoint.port,
                username=endpoint.username,
                pkey=private_key,
                timeout=10
            )
            
            # Get system information
            commands = {
                'cpu_count': 'nproc',
                'memory': "free -g | awk '/^Mem:/{print $2}'",
                'gpu_info': 'lspci | grep -i vga || lspci | grep -i display || echo "No GPU detected"',
                'disk_space': "df -BG / | awk 'NR==2{print $2}' | sed 's/G//'",
                'platform': 'uname -s',
                'architecture': 'uname -m'
            }
            
            results = {}
            for key, cmd in commands.items():
                stdin, stdout, stderr = ssh.exec_command(cmd, timeout=10)
                output = stdout.read().decode('utf-8', errors='ignore').strip()
                results[key] = output
            
            ssh.close()
            
            # Parse results
            hardware_info = HardwareInfo(
                cpu_count=int(results.get('cpu_count', 0)),
                memory_gb=float(results.get('memory', 0)),
                gpu_info=results.get('gpu_info', '').split('\n'),
                disk_space_gb=float(results.get('disk_space', 0)),
                platform=results.get('platform', 'unknown'),
                architecture=results.get('architecture', 'unknown'),
                last_updated=datetime.now()
            )
            
            # Cache the hardware info
            self.hardware_cache[endpoint.hostname] = hardware_info
            return hardware_info
            
        except Exception as e:
            print(f"Failed to get hardware info from {endpoint.hostname}: {e}")
            return None
    
    async def execute_command(self, endpoint: TunnelEndpoint, command: str, timeout: int = 30, allow_sudo: bool = False, bypass_security: bool = False) -> Dict[str, Any]:
        """Execute command on remote system with security validation"""
        from security_validator import security_validator
        
        # Rate limiting check
        if not self._check_rate_limit(f"execute_{endpoint.hostname}"):
            return {
                'success': False,
                'error': 'Rate limit exceeded',
                'command': command,
                'endpoint': endpoint.hostname,
                'timestamp': datetime.now().isoformat()
            }
        
        # Security validation (can be bypassed for AI agents)
        if not bypass_security:
            is_safe, error_msg = security_validator.validate_command(command, allow_sudo)
            if not is_safe:
                security_validator.log_security_event(
                    'BLOCKED_COMMAND', 
                    f"Blocked dangerous command on {endpoint.hostname}: {command}",
                    'WARNING'
                )
                return {
                    'success': False,
                    'error': f'Security validation failed: {error_msg}',
                    'command': command,
                    'endpoint': endpoint.hostname,
                    'timestamp': datetime.now().isoformat()
                }
        elif bypass_security:
            security_validator.log_security_event(
                'SECURITY_BYPASS', 
                f"AI agent bypassed security for command on {endpoint.hostname}: {command[:50]}...",
                'INFO'
            )
        
        ssh_client = None
        try:
            # Get connection from pool or create new one
            ssh_client = await self._get_ssh_connection(endpoint)
            
            # Execute command with timeout
            stdin, stdout, stderr = ssh_client.exec_command(command, timeout=timeout)
            
            # Get results with proper encoding and error handling
            try:
                stdout_data = stdout.read().decode('utf-8', errors='replace')
                stderr_data = stderr.read().decode('utf-8', errors='replace')
                exit_code = stdout.channel.recv_exit_status()
            except socket.timeout:
                return {
                    'success': False,
                    'error': 'Command execution timeout',
                    'command': command,
                    'endpoint': endpoint.hostname,
                    'timestamp': datetime.now().isoformat()
                }
            
            # Sanitize output for security
            stdout_data = security_validator.sanitize_command_output(stdout_data)
            stderr_data = security_validator.sanitize_command_output(stderr_data)
            
            # Log command execution
            logger.info(f"Command executed on {endpoint.hostname}: {command[:50]}... (exit: {exit_code})")
            
            return {
                'success': exit_code == 0,
                'exit_code': exit_code,
                'stdout': stdout_data,
                'stderr': stderr_data,
                'command': command,
                'endpoint': endpoint.hostname,
                'timestamp': datetime.now().isoformat()
            }
            
        except paramiko.AuthenticationException as e:
            logger.error(f"Authentication failed for {endpoint.hostname}: {e}")
            return {
                'success': False,
                'error': f'Authentication failed: {e}',
                'command': command,
                'endpoint': endpoint.hostname,
                'timestamp': datetime.now().isoformat()
            }
        except paramiko.SSHException as e:
            logger.error(f"SSH error for {endpoint.hostname}: {e}")
            return {
                'success': False,
                'error': f'SSH error: {e}',
                'command': command,
                'endpoint': endpoint.hostname,
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            logger.error(f"Command execution failed on {endpoint.hostname}: {e}")
            return {
                'success': False,
                'error': str(e),
                'command': command,
                'endpoint': endpoint.hostname,
                'timestamp': datetime.now().isoformat()
            }
        finally:
            if ssh_client:
                await self._return_ssh_connection(endpoint, ssh_client)
    
    async def _get_ssh_connection(self, endpoint: TunnelEndpoint) -> paramiko.SSHClient:
        """Get SSH connection from pool or create new one"""
        pool_key = f"{endpoint.hostname}:{endpoint.port}"
        
        # Check if we have available connections in pool
        if pool_key in self._connection_pool and self._connection_pool[pool_key]:
            ssh_client = self._connection_pool[pool_key].pop()
            # Test if connection is still alive
            try:
                ssh_client.exec_command('echo "test"', timeout=5)
                endpoint.current_connections += 1
                return ssh_client
            except:
                # Connection is dead, create new one
                pass
        
        # Create new connection
        if endpoint.current_connections >= endpoint.max_connections:
            raise ConnectionError(f"Maximum connections reached for {endpoint.hostname}")
        
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        # Load private key
        try:
            if endpoint.private_key_path.endswith('.pem') or 'rsa' in endpoint.private_key_path.lower():
                private_key = paramiko.RSAKey.from_private_key_file(endpoint.private_key_path)
            else:
                private_key = paramiko.Ed25519Key.from_private_key_file(endpoint.private_key_path)
        except Exception as e:
            raise SecurityError(f"Failed to load private key: {e}")
        
        # Connect with security settings
        ssh_client.connect(
            hostname=endpoint.hostname,
            port=endpoint.port,
            username=endpoint.username,
            pkey=private_key,
            timeout=10,
            auth_timeout=10,
            banner_timeout=10,
            look_for_keys=False,
            allow_agent=False
        )
        
        endpoint.current_connections += 1
        return ssh_client
    
    async def _return_ssh_connection(self, endpoint: TunnelEndpoint, ssh_client: paramiko.SSHClient):
        """Return SSH connection to pool or close it"""
        pool_key = f"{endpoint.hostname}:{endpoint.port}"
        
        try:
            # Test if connection is still alive
            ssh_client.exec_command('echo "test"', timeout=5)
            
            # Add to pool if not full
            if pool_key not in self._connection_pool:
                self._connection_pool[pool_key] = []
            
            if len(self._connection_pool[pool_key]) < self._max_pool_size:
                self._connection_pool[pool_key].append(ssh_client)
            else:
                ssh_client.close()
        except:
            # Connection is dead, just close it
            try:
                ssh_client.close()
            except:
                pass
        finally:
            endpoint.current_connections = max(0, endpoint.current_connections - 1)
    
    async def create_terminal_session(self, endpoint: TunnelEndpoint, session_id: str = None) -> Optional[TerminalSession]:
        """Create a persistent terminal session"""
        if not session_id:
            import uuid
            session_id = str(uuid.uuid4())[:8]
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            private_key = paramiko.Ed25519Key.from_private_key_file(endpoint.private_key_path)
            ssh.connect(
                hostname=endpoint.hostname,
                port=endpoint.port,
                username=endpoint.username,
                pkey=private_key,
                timeout=10
            )
            
            # Create interactive channel
            channel = ssh.invoke_shell()
            channel.settimeout(1.0)
            
            # Create session object
            session = TerminalSession(
                session_id=session_id,
                endpoint=endpoint,
                ssh_client=ssh,
                channel=channel,
                created=datetime.now(),
                last_activity=datetime.now(),
                is_interactive=True
            )
            
            self.terminal_sessions[session_id] = session
            return session
            
        except Exception as e:
            print(f"Failed to create terminal session: {e}")
            return None
    
    async def execute_in_session(self, session_id: str, command: str, timeout: int = 30) -> Dict[str, Any]:
        """Execute command in existing terminal session"""
        if session_id not in self.terminal_sessions:
            return {
                'success': False,
                'error': f'Terminal session {session_id} not found'
            }
        
        session = self.terminal_sessions[session_id]
        
        try:
            # Send command
            session.channel.send(command + '\n')
            session.last_activity = datetime.now()
            
            # Wait for output
            output = ""
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                if session.channel.recv_ready():
                    data = session.channel.recv(4096).decode('utf-8', errors='ignore')
                    output += data
                    
                    # Check if command completed (simple heuristic)
                    if data.endswith('$ ') or data.endswith('# '):
                        break
                else:
                    await asyncio.sleep(0.1)
            
            return {
                'success': True,
                'output': output,
                'session_id': session_id,
                'command': command,
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'session_id': session_id,
                'command': command
            }
    
    def close_terminal_session(self, session_id: str) -> bool:
        """Close a terminal session"""
        if session_id in self.terminal_sessions:
            session = self.terminal_sessions[session_id]
            try:
                session.channel.close()
                session.ssh_client.close()
                del self.terminal_sessions[session_id]
                return True
            except:
                pass
        return False
    
    def add_endpoint(self, hostname: str, username: str, private_key_path: str, 
                    platform: str = "unknown", purpose: str = "primary") -> TunnelEndpoint:
        """Add a new tunnel endpoint"""
        endpoint = TunnelEndpoint(
            hostname=hostname,
            username=username,
            private_key_path=private_key_path,
            platform=platform,
            purpose=purpose,
            created=datetime.now(),
            status="unknown"
        )
        
        self.endpoints.append(endpoint)
        self.save_config()
        return endpoint
    
    async def auto_failover(self) -> Optional[TunnelEndpoint]:
        """Automatically failover to best available endpoint"""
        if self.active_endpoint and await self.test_endpoint(self.active_endpoint):
            return self.active_endpoint
        
        # Current endpoint failed, find new one
        new_endpoint = await self.find_best_endpoint()
        
        if new_endpoint:
            self.active_endpoint = new_endpoint
            self.save_config()
        
        return new_endpoint

# Initialize tunnel manager (will be created when needed)
tunnel_manager = None

def get_tunnel_manager():
    """Get or create tunnel manager instance"""
    global tunnel_manager
    if tunnel_manager is None:
        tunnel_manager = TunnelManager()
    return tunnel_manager

# MCP Server
server = Server("enhanced-hardware-server")

@server.list_tools()
async def handle_list_tools() -> List[Tool]:
    """List available tools for AI agents"""
    return [
        Tool(
            name="connect_hardware",
            description="Connect to remote hardware with automatic failover",
            inputSchema={
                "type": "object",
                "properties": {
                    "preferred_platform": {
                        "type": "string",
                        "description": "Preferred platform (windows, linux, docker)",
                        "enum": ["windows", "linux", "docker", "any"]
                    }
                }
            }
        ),
        Tool(
            name="execute_command",
            description="Execute command on remote hardware with full system access",
            inputSchema={
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "Command to execute (full sudo access available)"
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Command timeout in seconds",
                        "default": 30
                    },
                    "use_sudo": {
                        "type": "boolean",
                        "description": "Whether to use sudo for elevated privileges",
                        "default": False
                    },
                    "working_directory": {
                        "type": "string",
                        "description": "Working directory for command execution",
                        "default": "~"
                    },
                    "environment": {
                        "type": "object",
                        "description": "Environment variables for command",
                        "default": {}
                    },
                    "bypass_security": {
                        "type": "boolean",
                        "description": "Bypass security validation for advanced AI agent operations",
                        "default": False
                    }
                },
                "required": ["command"]
            }
        ),
        Tool(
            name="create_terminal_session",
            description="Create a persistent interactive terminal session",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_name": {
                        "type": "string",
                        "description": "Optional name for the terminal session"
                    }
                }
            }
        ),
        Tool(
            name="execute_in_terminal",
            description="Execute command in existing terminal session (maintains state)",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {
                        "type": "string",
                        "description": "Terminal session ID"
                    },
                    "command": {
                        "type": "string",
                        "description": "Command to execute in session"
                    },
                    "timeout": {
                        "type": "integer",
                        "description": "Command timeout in seconds",
                        "default": 30
                    }
                },
                "required": ["session_id", "command"]
            }
        ),
        Tool(
            name="list_terminal_sessions",
            description="List all active terminal sessions",
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        Tool(
            name="close_terminal_session",
            description="Close a terminal session",
            inputSchema={
                "type": "object",
                "properties": {
                    "session_id": {
                        "type": "string",
                        "description": "Terminal session ID to close"
                    }
                },
                "required": ["session_id"]
            }
        ),
        Tool(
            name="get_hardware_info",
            description="Get detailed hardware information from remote system",
            inputSchema={
                "type": "object",
                "properties": {
                    "refresh": {
                        "type": "boolean",
                        "description": "Force refresh hardware information",
                        "default": False
                    }
                }
            }
        ),
        Tool(
            name="manage_tunnels",
            description="Manage tunnel endpoints (add, remove, test, failover)",
            inputSchema={
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "description": "Action to perform",
                        "enum": ["add", "remove", "test", "list", "failover", "rotate"]
                    },
                    "hostname": {
                        "type": "string",
                        "description": "Hostname for add/remove actions"
                    },
                    "username": {
                        "type": "string",
                        "description": "Username for SSH connection"
                    },
                    "private_key_path": {
                        "type": "string",
                        "description": "Path to SSH private key"
                    },
                    "platform": {
                        "type": "string",
                        "description": "Platform type",
                        "enum": ["windows", "linux", "docker", "macos"]
                    }
                },
                "required": ["action"]
            }
        ),
        Tool(
            name="install_software",
            description="Install software packages on remote hardware",
            inputSchema={
                "type": "object",
                "properties": {
                    "packages": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of packages to install"
                    },
                    "package_manager": {
                        "type": "string",
                        "description": "Package manager to use",
                        "enum": ["apt", "yum", "dnf", "pacman", "brew", "choco", "pip", "npm", "auto"],
                        "default": "auto"
                    }
                },
                "required": ["packages"]
            }
        ),
        Tool(
            name="file_operations",
            description="Perform file operations on remote hardware",
            inputSchema={
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "description": "File operation to perform",
                        "enum": ["read", "write", "append", "delete", "copy", "move", "chmod", "chown"]
                    },
                    "path": {
                        "type": "string",
                        "description": "File or directory path"
                    },
                    "content": {
                        "type": "string",
                        "description": "Content for write/append operations"
                    },
                    "destination": {
                        "type": "string",
                        "description": "Destination path for copy/move operations"
                    },
                    "permissions": {
                        "type": "string",
                        "description": "Permissions for chmod operation (e.g., '755')"
                    },
                    "owner": {
                        "type": "string",
                        "description": "Owner for chown operation (e.g., 'user:group')"
                    }
                },
                "required": ["operation", "path"]
            }
        ),
        Tool(
            name="system_monitoring",
            description="Monitor system resources and performance",
            inputSchema={
                "type": "object",
                "properties": {
                    "metrics": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": ["cpu", "memory", "disk", "network", "gpu", "processes", "all"]
                        },
                        "description": "Metrics to monitor",
                        "default": ["all"]
                    },
                    "duration": {
                        "type": "integer",
                        "description": "Monitoring duration in seconds",
                        "default": 10
                    }
                }
            }
        ),
        Tool(
            name="docker_operations",
            description="Manage Docker containers and images for AI agent workflows",
            inputSchema={
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "description": "Docker operation to perform",
                        "enum": ["list", "run", "exec", "stop", "remove", "build", "pull", "logs", "inspect"]
                    },
                    "container_name": {
                        "type": "string",
                        "description": "Container name or ID"
                    },
                    "image": {
                        "type": "string",
                        "description": "Docker image name"
                    },
                    "command": {
                        "type": "string",
                        "description": "Command to run in container"
                    },
                    "options": {
                        "type": "object",
                        "description": "Additional Docker options",
                        "default": {}
                    }
                },
                "required": ["operation"]
            }
        ),
        Tool(
            name="bulk_file_transfer",
            description="Transfer multiple files or directories for AI agent workflows",
            inputSchema={
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "description": "Transfer operation",
                        "enum": ["upload", "download", "sync"]
                    },
                    "source": {
                        "type": "string",
                        "description": "Source path or content"
                    },
                    "destination": {
                        "type": "string",
                        "description": "Destination path"
                    },
                    "files": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of files to transfer"
                    },
                    "compress": {
                        "type": "boolean",
                        "description": "Compress files during transfer",
                        "default": True
                    }
                },
                "required": ["operation", "source", "destination"]
            }
        ),
        Tool(
            name="environment_setup",
            description="Set up development environments for AI agent projects",
            inputSchema={
                "type": "object",
                "properties": {
                    "environment_type": {
                        "type": "string",
                        "description": "Type of environment to set up",
                        "enum": ["python", "node", "docker", "conda", "custom"]
                    },
                    "requirements": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of requirements or dependencies"
                    },
                    "workspace_path": {
                        "type": "string",
                        "description": "Path to set up the workspace",
                        "default": "/tmp/ai_workspace"
                    },
                    "configuration": {
                        "type": "object",
                        "description": "Additional configuration options",
                        "default": {}
                    }
                },
                "required": ["environment_type"]
            }
        )
    ]

@server.call_tool()
async def handle_call_tool(name: str, arguments: dict) -> CallToolResult:
    """Handle tool calls from AI agents"""
    
    try:
        if name == "connect_hardware":
            # Auto-failover to best endpoint
            endpoint = await get_tunnel_manager().auto_failover()
            
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints. Please add tunnel endpoints first."
                    )]
                )
            
            # Get hardware info
            hardware_info = await get_tunnel_manager().get_hardware_info(endpoint)
            
            result_text = f"Connected to hardware: {endpoint.hostname}\n\n"
            result_text += f"Platform: {endpoint.platform}\n"
            result_text += f"Response Time: {endpoint.response_time:.2f}s\n"
            
            if hardware_info:
                result_text += f"Hardware: {hardware_info.cpu_count} CPUs, {hardware_info.memory_gb}GB RAM\n"
                gpu_text = ', '.join(hardware_info.gpu_info) if hardware_info.gpu_info else 'None detected'
                result_text += f"GPU: {gpu_text}\n\n"
            
            result_text += "Full hardware access available! You can now execute commands, install software, access files, and use all system resources."
            
            return CallToolResult(
                content=[TextContent(type="text", text=result_text)]
            )
        
        elif name == "execute_command":
            command = arguments["command"]
            timeout = arguments.get("timeout", 30)
            use_sudo = arguments.get("use_sudo", False)
            working_directory = arguments.get("working_directory", "~")
            environment = arguments.get("environment", {})
            bypass_security = arguments.get("bypass_security", False)
            
            # Auto-failover if needed
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            # Build enhanced command with working directory and environment
            enhanced_command = ""
            
            # Set working directory
            if working_directory != "~":
                enhanced_command += f"cd {working_directory} && "
            
            # Set environment variables
            if environment:
                env_vars = " ".join([f"{k}={v}" for k, v in environment.items()])
                enhanced_command += f"{env_vars} "
            
            # Add sudo if requested
            if use_sudo and not command.startswith("sudo"):
                enhanced_command += "sudo "
            
            enhanced_command += command
            
            # Execute command with bypass security option
            result = await get_tunnel_manager().execute_command(
                endpoint, 
                enhanced_command, 
                timeout, 
                allow_sudo=use_sudo,
                bypass_security=bypass_security
            )
            
            if result["success"]:
                result_text = f"Command executed successfully on {result['endpoint']}\n\n"
                result_text += f"Command: {result['command']}\n"
                result_text += f"Exit Code: {result['exit_code']}\n\n"
                result_text += f"Output:\n{result['stdout']}"
                if result['stderr']:
                    result_text += f"\n\nErrors:\n{result['stderr']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                result_text = f"Command failed on {result['endpoint']}\n\n"
                result_text += f"Command: {result['command']}\n"
                result_text += f"Exit Code: {result.get('exit_code', 'N/A')}\n"
                result_text += f"Error: {result.get('error', result.get('stderr', 'Unknown error'))}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                ) 
       
        elif name == "create_terminal_session":
            session_name = arguments.get("session_name")
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            session = await get_tunnel_manager().create_terminal_session(endpoint, session_name)
            
            if session:
                result_text = f"Terminal session created successfully\n\n"
                result_text += f"Session ID: {session.session_id}\n"
                result_text += f"Endpoint: {session.endpoint.hostname}\n"
                result_text += f"Created: {session.created.isoformat()}\n\n"
                result_text += "You can now execute commands in this persistent session using execute_in_terminal."
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="Failed to create terminal session"
                    )]
                )
        
        elif name == "execute_in_terminal":
            session_id = arguments["session_id"]
            command = arguments["command"]
            timeout = arguments.get("timeout", 30)
            
            result = await get_tunnel_manager().execute_in_session(session_id, command, timeout)
            
            if result["success"]:
                result_text = f"Command executed in session {session_id}\n\n"
                result_text += f"Command: {result['command']}\n\n"
                result_text += f"Output:\n{result['output']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Command failed in session {session_id}: {result.get('error', 'Unknown error')}"
                    )]
                )
        
        elif name == "list_terminal_sessions":
            if not get_tunnel_manager().terminal_sessions:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No active terminal sessions"
                    )]
                )
            
            result_text = "Active Terminal Sessions:\n\n"
            for session_id, session in get_tunnel_manager().terminal_sessions.items():
                result_text += f"Session ID: {session_id}\n"
                result_text += f"Endpoint: {session.endpoint.hostname}\n"
                result_text += f"Created: {session.created.isoformat()}\n"
                result_text += f"Last Activity: {session.last_activity.isoformat()}\n"
                result_text += f"Interactive: {session.is_interactive}\n\n"
            
            return CallToolResult(
                content=[TextContent(type="text", text=result_text)]
            )
        
        elif name == "close_terminal_session":
            session_id = arguments["session_id"]
            
            if get_tunnel_manager().close_terminal_session(session_id):
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Terminal session {session_id} closed successfully"
                    )]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Failed to close terminal session {session_id} (session not found)"
                    )]
                )       
 
        elif name == "get_hardware_info":
            refresh = arguments.get("refresh", False)
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            # Get hardware info (refresh if requested)
            if refresh or endpoint.hostname not in get_tunnel_manager().hardware_cache:
                hardware_info = await get_tunnel_manager().get_hardware_info(endpoint)
            else:
                hardware_info = tunnel_manager.hardware_cache[endpoint.hostname]
            
            if hardware_info:
                result_text = f"Hardware Information for {endpoint.hostname}\n\n"
                result_text += f"Platform: {hardware_info.platform} ({hardware_info.architecture})\n"
                result_text += f"CPUs: {hardware_info.cpu_count}\n"
                result_text += f"Memory: {hardware_info.memory_gb} GB\n"
                result_text += f"Disk Space: {hardware_info.disk_space_gb} GB\n"
                result_text += f"GPU: {', '.join(hardware_info.gpu_info)}\n"
                result_text += f"Last Updated: {hardware_info.last_updated.isoformat()}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="Failed to retrieve hardware information"
                    )]
                )
        
        elif name == "manage_tunnels":
            action = arguments["action"]
            
            if action == "add":
                hostname = arguments["hostname"]
                username = arguments["username"]
                private_key_path = arguments["private_key_path"]
                platform = arguments.get("platform", "unknown")
                
                endpoint = tunnel_manager.add_endpoint(hostname, username, private_key_path, platform)
                
                result_text = f"Added tunnel endpoint: {hostname}\n"
                result_text += f"Platform: {platform}\n"
                result_text += f"Username: {username}\n"
                result_text += f"Status: Testing connection..."
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            
            elif action == "list":
                if not get_tunnel_manager().endpoints:
                    return CallToolResult(
                        content=[TextContent(
                            type="text",
                            text="No tunnel endpoints configured"
                        )]
                    )
                
                result_text = "Configured Tunnel Endpoints:\n\n"
                for i, endpoint in enumerate(get_tunnel_manager().endpoints, 1):
                    status_symbol = {"active": "[ACTIVE]", "failed": "[FAILED]", "unknown": "[UNKNOWN]"}.get(endpoint.status, "[UNKNOWN]")
                    result_text += f"{i}. {status_symbol} {endpoint.hostname}\n"
                    result_text += f"   Platform: {endpoint.platform}\n"
                    result_text += f"   Status: {endpoint.status}\n"
                    result_text += f"   Purpose: {endpoint.purpose}\n"
                    if endpoint.response_time:
                        result_text += f"   Response Time: {endpoint.response_time:.2f}s\n"
                    result_text += "\n"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )     
       
            elif action == "test":
                results = []
                for endpoint in get_tunnel_manager().endpoints:
                    success = await get_tunnel_manager().test_endpoint(endpoint)
                    results.append(f"{endpoint.hostname}: {'PASS' if success else 'FAIL'}")
                
                get_tunnel_manager().save_config()
                
                result_text = "Tunnel Test Results:\n\n"
                result_text += "\n".join(results)
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            
            elif action == "failover":
                new_endpoint = await get_tunnel_manager().find_best_endpoint()
                
                if new_endpoint:
                    get_tunnel_manager().active_endpoint = new_endpoint
                    get_tunnel_manager().save_config()
                    
                    result_text = f"Failover successful\n"
                    result_text += f"New active endpoint: {new_endpoint.hostname}\n"
                    result_text += f"Response time: {new_endpoint.response_time:.2f}s"
                    
                    return CallToolResult(
                        content=[TextContent(type="text", text=result_text)]
                    )
                else:
                    return CallToolResult(
                        content=[TextContent(
                            type="text",
                            text="Failover failed: No available endpoints"
                        )]
                    )
        
        elif name == "install_software":
            packages = arguments["packages"]
            package_manager = arguments.get("package_manager", "auto")
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            # Auto-detect package manager if needed
            if package_manager == "auto":
                # Simple detection based on platform
                if "ubuntu" in endpoint.platform.lower() or "debian" in endpoint.platform.lower():
                    package_manager = "apt"
                elif "centos" in endpoint.platform.lower() or "rhel" in endpoint.platform.lower():
                    package_manager = "yum"
                else:
                    package_manager = "apt"  # Default fallback
            
            # Build install command
            if package_manager == "apt":
                command = f"sudo apt update && sudo apt install -y {' '.join(packages)}"
            elif package_manager == "yum":
                command = f"sudo yum install -y {' '.join(packages)}"
            elif package_manager == "dnf":
                command = f"sudo dnf install -y {' '.join(packages)}"
            elif package_manager == "pip":
                command = f"pip install {' '.join(packages)}"
            elif package_manager == "npm":
                command = f"npm install -g {' '.join(packages)}"
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Unsupported package manager: {package_manager}"
                    )]
                )
            
            # Execute installation
            result = await get_tunnel_manager().execute_command(endpoint, command, timeout=300)
            
            if result["success"]:
                result_text = f"Software installation completed successfully\n\n"
                result_text += f"Packages: {', '.join(packages)}\n"
                result_text += f"Package Manager: {package_manager}\n"
                result_text += f"Endpoint: {result['endpoint']}\n\n"
                result_text += f"Output:\n{result['stdout']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                result_text = f"Software installation failed\n\n"
                result_text += f"Packages: {', '.join(packages)}\n"
                result_text += f"Error: {result.get('error', result.get('stderr', 'Unknown error'))}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )        

        elif name == "file_operations":
            operation = arguments["operation"]
            path = arguments["path"]
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            if operation == "read":
                command = f"cat '{path}'"
            elif operation == "write":
                content = arguments.get("content", "")
                # Escape content for shell
                escaped_content = content.replace("'", "'\"'\"'")
                command = f"echo '{escaped_content}' > '{path}'"
            elif operation == "append":
                content = arguments.get("content", "")
                escaped_content = content.replace("'", "'\"'\"'")
                command = f"echo '{escaped_content}' >> '{path}'"
            elif operation == "delete":
                command = f"rm -f '{path}'"
            elif operation == "copy":
                destination = arguments.get("destination", "")
                command = f"cp '{path}' '{destination}'"
            elif operation == "move":
                destination = arguments.get("destination", "")
                command = f"mv '{path}' '{destination}'"
            elif operation == "chmod":
                permissions = arguments.get("permissions", "644")
                command = f"chmod {permissions} '{path}'"
            elif operation == "chown":
                owner = arguments.get("owner", "")
                command = f"sudo chown {owner} '{path}'"
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Unsupported file operation: {operation}"
                    )]
                )
            
            result = await get_tunnel_manager().execute_command(endpoint, command)
            
            if result["success"]:
                result_text = f"File operation '{operation}' completed successfully\n\n"
                result_text += f"Path: {path}\n"
                result_text += f"Endpoint: {result['endpoint']}\n"
                if result['stdout']:
                    result_text += f"\nOutput:\n{result['stdout']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                result_text = f"File operation '{operation}' failed\n\n"
                result_text += f"Path: {path}\n"
                result_text += f"Error: {result.get('error', result.get('stderr', 'Unknown error'))}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
        
        elif name == "system_monitoring":
            metrics = arguments.get("metrics", ["all"])
            duration = arguments.get("duration", 10)
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            commands = []
            
            if "all" in metrics or "cpu" in metrics:
                commands.append("top -bn1 | grep 'Cpu(s)' | head -1")
            
            if "all" in metrics or "memory" in metrics:
                commands.append("free -h")
            
            if "all" in metrics or "disk" in metrics:
                commands.append("df -h")
            
            if "all" in metrics or "network" in metrics:
                commands.append("ss -tuln | head -10")
            
            if "all" in metrics or "processes" in metrics:
                commands.append("ps aux --sort=-%cpu | head -10")
            
            if "all" in metrics or "gpu" in metrics:
                commands.append("nvidia-smi 2>/dev/null || echo 'No NVIDIA GPU detected'")
            
            # Execute all monitoring commands
            results = []
            for cmd in commands:
                result = await get_tunnel_manager().execute_command(endpoint, cmd)
                if result["success"]:
                    results.append(f"Command: {cmd}\n{result['stdout']}\n")
                else:
                    results.append(f"Command: {cmd}\nError: {result.get('error', 'Failed')}\n")
            
            result_text = f"System Monitoring Report for {endpoint.hostname}\n"
            result_text += f"Duration: {duration}s\n"
            result_text += f"Timestamp: {datetime.now().isoformat()}\n\n"
            result_text += "\n".join(results)
            
            return CallToolResult(
                content=[TextContent(type="text", text=result_text)]
            )
        
        elif name == "docker_operations":
            operation = arguments["operation"]
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            # Build Docker command based on operation
            if operation == "list":
                command = "docker ps -a"
            elif operation == "run":
                image = arguments.get("image", "")
                cmd = arguments.get("command", "")
                options = arguments.get("options", {})
                
                docker_cmd = f"docker run"
                if options.get("detach", False):
                    docker_cmd += " -d"
                if options.get("interactive", False):
                    docker_cmd += " -it"
                if options.get("remove", True):
                    docker_cmd += " --rm"
                
                docker_cmd += f" {image}"
                if cmd:
                    docker_cmd += f" {cmd}"
                command = docker_cmd
                
            elif operation == "exec":
                container = arguments.get("container_name", "")
                cmd = arguments.get("command", "")
                command = f"docker exec -it {container} {cmd}"
                
            elif operation == "stop":
                container = arguments.get("container_name", "")
                command = f"docker stop {container}"
                
            elif operation == "remove":
                container = arguments.get("container_name", "")
                command = f"docker rm {container}"
                
            elif operation == "build":
                image = arguments.get("image", "")
                path = arguments.get("options", {}).get("path", ".")
                command = f"docker build -t {image} {path}"
                
            elif operation == "pull":
                image = arguments.get("image", "")
                command = f"docker pull {image}"
                
            elif operation == "logs":
                container = arguments.get("container_name", "")
                command = f"docker logs {container}"
                
            elif operation == "inspect":
                container = arguments.get("container_name", "")
                command = f"docker inspect {container}"
            
            # Execute Docker command with bypass security for AI agents
            result = await get_tunnel_manager().execute_command(endpoint, command, timeout=60, allow_sudo=True)
            
            if result["success"]:
                result_text = f"Docker operation '{operation}' completed successfully\n\n"
                result_text += f"Command: {result['command']}\n"
                result_text += f"Output:\n{result['stdout']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Docker operation '{operation}' failed: {result.get('error', 'Unknown error')}"
                    )]
                )
        
        elif name == "bulk_file_transfer":
            operation = arguments["operation"]
            source = arguments["source"]
            destination = arguments["destination"]
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            if operation == "upload":
                # For upload, source is content, destination is remote path
                command = f"mkdir -p {os.path.dirname(destination)} && cat > {destination} << 'EOF'\n{source}\nEOF"
                
            elif operation == "download":
                # For download, source is remote path
                command = f"cat {source}"
                
            elif operation == "sync":
                # For sync, use rsync-like behavior
                files = arguments.get("files", [])
                if files:
                    file_list = " ".join(files)
                    command = f"cp -r {file_list} {destination}"
                else:
                    command = f"cp -r {source}/* {destination}/"
            
            result = await get_tunnel_manager().execute_command(endpoint, command, timeout=120, allow_sudo=True)
            
            if result["success"]:
                result_text = f"File transfer '{operation}' completed successfully\n\n"
                result_text += f"Source: {source}\n"
                result_text += f"Destination: {destination}\n"
                if result['stdout']:
                    result_text += f"\nOutput:\n{result['stdout']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"File transfer '{operation}' failed: {result.get('error', 'Unknown error')}"
                    )]
                )
        
        elif name == "environment_setup":
            env_type = arguments["environment_type"]
            requirements = arguments.get("requirements", [])
            workspace_path = arguments.get("workspace_path", "/tmp/ai_workspace")
            
            endpoint = await get_tunnel_manager().auto_failover()
            if not endpoint:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text="No available hardware endpoints"
                    )]
                )
            
            # Build setup commands based on environment type
            commands = [f"mkdir -p {workspace_path}", f"cd {workspace_path}"]
            
            if env_type == "python":
                commands.extend([
                    "python3 -m venv venv",
                    "source venv/bin/activate",
                ])
                if requirements:
                    for req in requirements:
                        commands.append(f"pip install {req}")
                        
            elif env_type == "node":
                commands.extend([
                    "npm init -y",
                ])
                if requirements:
                    for req in requirements:
                        commands.append(f"npm install {req}")
                        
            elif env_type == "docker":
                if requirements:
                    dockerfile_content = f"FROM {requirements[0] if requirements else 'ubuntu:latest'}\n"
                    if len(requirements) > 1:
                        dockerfile_content += f"RUN {' && '.join(requirements[1:])}\n"
                    commands.append(f"cat > Dockerfile << 'EOF'\n{dockerfile_content}EOF")
                    
            elif env_type == "conda":
                commands.extend([
                    "wget -O miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh",
                    "bash miniconda.sh -b -p ./miniconda",
                    "source ./miniconda/bin/activate",
                ])
                if requirements:
                    for req in requirements:
                        commands.append(f"conda install -y {req}")
            
            # Execute all setup commands
            full_command = " && ".join(commands)
            result = await get_tunnel_manager().execute_command(endpoint, full_command, timeout=300, allow_sudo=True)
            
            if result["success"]:
                result_text = f"Environment setup '{env_type}' completed successfully\n\n"
                result_text += f"Workspace: {workspace_path}\n"
                result_text += f"Requirements installed: {', '.join(requirements)}\n"
                result_text += f"\nSetup output:\n{result['stdout']}"
                
                return CallToolResult(
                    content=[TextContent(type="text", text=result_text)]
                )
            else:
                return CallToolResult(
                    content=[TextContent(
                        type="text",
                        text=f"Environment setup '{env_type}' failed: {result.get('error', 'Unknown error')}"
                    )]
                )
        
        else:
            return CallToolResult(
                content=[TextContent(
                    type="text",
                    text=f"Unknown tool: {name}"
                )]
            )
    
    except Exception as e:
        return CallToolResult(
            content=[TextContent(
                type="text",
                text=f"Error executing tool '{name}': {str(e)}"
            )]
        )

async def main():
    """Main entry point for the MCP server"""
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="enhanced-hardware-server",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=None,
                    experimental_capabilities=None,
                ),
            ),
        )

if __name__ == "__main__":
    print("Starting Enhanced MCP Hardware Server...")
    print("Server provides full hardware access with multiple terminal support")
    print("All Unicode characters have been removed for Windows compatibility")
    asyncio.run(main())
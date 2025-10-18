#!/usr/bin/env python3
"""
Comprehensive Test Runner for Enhanced MCP Hardware Server
Runs all tests with proper reporting and coverage analysis
"""

import sys
import os
import subprocess
import argparse
import time
from pathlib import Path
from typing import List, Dict, Any

# Add project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def run_command(cmd: List[str], cwd: Path = None) -> Dict[str, Any]:
    """Run a command and return results"""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or project_root,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        return {
            'success': result.returncode == 0,
            'returncode': result.returncode,
            'stdout': result.stdout,
            'stderr': result.stderr
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'returncode': -1,
            'stdout': '',
            'stderr': 'Command timed out after 5 minutes'
        }
    except Exception as e:
        return {
            'success': False,
            'returncode': -1,
            'stdout': '',
            'stderr': str(e)
        }

def check_dependencies() -> bool:
    """Check if required dependencies are installed"""
    print("🔍 Checking dependencies...")
    
    required_packages = [
        'pytest',
        'pytest-asyncio',
        'pytest-cov',
        'paramiko',
        'requests'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        result = run_command([sys.executable, '-c', f'import {package.replace("-", "_")}'])
        if not result['success']:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"❌ Missing packages: {', '.join(missing_packages)}")
        print("Installing missing packages...")
        
        install_cmd = [sys.executable, '-m', 'pip', 'install'] + missing_packages
        result = run_command(install_cmd)
        
        if not result['success']:
            print(f"❌ Failed to install packages: {result['stderr']}")
            return False
        
        print("✅ Dependencies installed successfully")
    else:
        print("✅ All dependencies are available")
    
    return True

def run_unit_tests() -> Dict[str, Any]:
    """Run unit tests with pytest"""
    print("\n🧪 Running unit tests...")
    
    cmd = [
        sys.executable, '-m', 'pytest',
        'tests/test_mcp_server.py',
        '-v',
        '--tb=short',
        '--cov=enhanced_mcp_hardware_server',
        '--cov=security_validator',
        '--cov=config_manager',
        '--cov-report=term-missing',
        '--cov-report=html:htmlcov'
    ]
    
    result = run_command(cmd)
    
    if result['success']:
        print("✅ Unit tests passed")
    else:
        print("❌ Unit tests failed")
        print(f"Error: {result['stderr']}")
    
    return result

def run_security_tests() -> Dict[str, Any]:
    """Run security validation tests"""
    print("\n🔒 Running security tests...")
    
    # Create a simple security test
    security_test_code = '''
import sys
import os
sys.path.append(".")

from security_validator import SecurityValidator

def test_security_validation():
    validator = SecurityValidator()
    
    # Test hostname validation
    valid, msg = validator.validate_hostname("example.com")
    assert valid, f"Valid hostname rejected: {msg}"
    
    valid, msg = validator.validate_hostname("evil.com; rm -rf /")
    assert not valid, "Malicious hostname accepted"
    
    # Test command validation
    valid, msg = validator.validate_command("ls -la")
    assert valid, f"Safe command rejected: {msg}"
    
    valid, msg = validator.validate_command("rm -rf /")
    assert not valid, "Dangerous command accepted"
    
    # Test file path validation
    valid, msg = validator.validate_file_path("/home/user/file.txt")
    assert valid, f"Safe path rejected: {msg}"
    
    valid, msg = validator.validate_file_path("../../../etc/passwd")
    assert not valid, "Path traversal accepted"
    
    print("All security tests passed")

if __name__ == "__main__":
    test_security_validation()
'''
    
    # Write and run security test
    test_file = project_root / 'temp_security_test.py'
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(security_test_code)
    
    try:
        result = run_command([sys.executable, str(test_file)])
        
        if result['success']:
            print("✅ Security tests passed")
        else:
            print("❌ Security tests failed")
            print(f"Error: {result['stderr']}")
        
        return result
    finally:
        # Cleanup
        if test_file.exists():
            test_file.unlink()

def run_configuration_tests() -> Dict[str, Any]:
    """Run configuration management tests"""
    print("\n⚙️ Running configuration tests...")
    
    config_test_code = '''
import sys
import os
import tempfile
import json
sys.path.append(".")

from config_manager import ConfigManager

def test_config_management():
    # Test with temporary config file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        config_data = {
            "server_config": {
                "name": "test-server",
                "version": "1.0.0"
            },
            "ssh_config": {
                "username": "testuser",
                "private_key_path": "/test/key"
            },
            "cloudflare_config": {
                "domain": "test.com"
            },
            "security_config": {
                "enable_rate_limiting": True
            }
        }
        json.dump(config_data, f)
        f.flush()
        
        # Test config loading
        config_mgr = ConfigManager(f.name)
        assert config_mgr.load_config(), "Failed to load config"
        
        # Test config validation
        issues = config_mgr.validate_config()
        # Some issues expected due to missing files
        
        # Test config summary
        summary = config_mgr.get_config_summary()
        assert 'server' in summary, "Missing server config in summary"
        
        print("✅ Configuration tests passed")
        
        # Cleanup
        os.unlink(f.name)

if __name__ == "__main__":
    test_config_management()
'''
    
    # Write and run config test
    test_file = project_root / 'temp_config_test.py'
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(config_test_code)
    
    try:
        result = run_command([sys.executable, str(test_file)])
        
        if result['success']:
            print("✅ Configuration tests passed")
        else:
            print("❌ Configuration tests failed")
            print(f"Error: {result['stderr']}")
        
        return result
    finally:
        # Cleanup
        if test_file.exists():
            test_file.unlink()

def run_integration_tests() -> Dict[str, Any]:
    """Run integration tests"""
    print("\n🔗 Running integration tests...")
    
    # For now, just validate that the main server can be imported
    integration_test_code = '''
import sys
sys.path.append(".")

def test_server_import():
    try:
        # Test that we can import the main server without errors
        import enhanced_mcp_hardware_server
        print("✅ Server import successful")
        
        # Test that we can create a TunnelManager
        from enhanced_mcp_hardware_server import TunnelManager
        
        # Mock the background tasks to avoid actual execution
        import unittest.mock
        with unittest.mock.patch('enhanced_mcp_hardware_server.asyncio.create_task'):
            manager = TunnelManager()
            print("✅ TunnelManager creation successful")
        
        return True
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_server_import()
    sys.exit(0 if success else 1)
'''
    
    # Write and run integration test
    test_file = project_root / 'temp_integration_test.py'
    with open(test_file, 'w', encoding='utf-8') as f:
        f.write(integration_test_code)
    
    try:
        result = run_command([sys.executable, str(test_file)])
        
        if result['success']:
            print("✅ Integration tests passed")
        else:
            print("❌ Integration tests failed")
            print(f"Error: {result['stderr']}")
        
        return result
    finally:
        # Cleanup
        if test_file.exists():
            test_file.unlink()

def run_shell_tests() -> Dict[str, Any]:
    """Run existing shell-based tests"""
    print("\n🐚 Running shell tests...")
    
    shell_tests = [
        'test-diagnostics.sh',
        'tests/run-tests.sh'
    ]
    
    results = []
    
    for test_script in shell_tests:
        test_path = project_root / test_script
        if test_path.exists():
            print(f"Running {test_script}...")
            result = run_command(['bash', str(test_path)])
            results.append(result)
            
            if result['success']:
                print(f"✅ {test_script} passed")
            else:
                print(f"❌ {test_script} failed")
        else:
            print(f"⚠️ {test_script} not found, skipping")
    
    # Return overall result
    overall_success = all(r['success'] for r in results) if results else True
    return {
        'success': overall_success,
        'results': results
    }

def generate_test_report(results: Dict[str, Any]):
    """Generate a comprehensive test report"""
    print("\n📊 Test Report")
    print("=" * 50)
    
    total_tests = len(results)
    passed_tests = sum(1 for r in results.values() if r.get('success', False))
    failed_tests = total_tests - passed_tests
    
    print(f"Total test suites: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {failed_tests}")
    print(f"Success rate: {(passed_tests/total_tests)*100:.1f}%")
    
    print("\nDetailed Results:")
    for test_name, result in results.items():
        status = "✅ PASS" if result.get('success', False) else "❌ FAIL"
        print(f"  {test_name}: {status}")
        
        if not result.get('success', False) and result.get('stderr'):
            print(f"    Error: {result['stderr'][:200]}...")
    
    # Coverage information
    coverage_file = project_root / 'htmlcov' / 'index.html'
    if coverage_file.exists():
        print(f"\n📈 Coverage report generated: {coverage_file}")
    
    print("\n" + "=" * 50)

def main():
    """Main test runner function"""
    parser = argparse.ArgumentParser(description='Run comprehensive tests for MCP Hardware Server')
    parser.add_argument('--skip-deps', action='store_true', help='Skip dependency check')
    parser.add_argument('--unit-only', action='store_true', help='Run only unit tests')
    parser.add_argument('--security-only', action='store_true', help='Run only security tests')
    parser.add_argument('--config-only', action='store_true', help='Run only configuration tests')
    parser.add_argument('--integration-only', action='store_true', help='Run only integration tests')
    parser.add_argument('--shell-only', action='store_true', help='Run only shell tests')
    
    args = parser.parse_args()
    
    print("🚀 Enhanced MCP Hardware Server - Test Suite")
    print("=" * 50)
    
    # Check dependencies unless skipped
    if not args.skip_deps:
        if not check_dependencies():
            print("❌ Dependency check failed")
            return 1
    
    # Run tests based on arguments
    results = {}
    start_time = time.time()
    
    if args.unit_only:
        results['unit_tests'] = run_unit_tests()
    elif args.security_only:
        results['security_tests'] = run_security_tests()
    elif args.config_only:
        results['config_tests'] = run_configuration_tests()
    elif args.integration_only:
        results['integration_tests'] = run_integration_tests()
    elif args.shell_only:
        results['shell_tests'] = run_shell_tests()
    else:
        # Run all tests
        results['unit_tests'] = run_unit_tests()
        results['security_tests'] = run_security_tests()
        results['config_tests'] = run_configuration_tests()
        results['integration_tests'] = run_integration_tests()
        results['shell_tests'] = run_shell_tests()
    
    end_time = time.time()
    
    # Generate report
    generate_test_report(results)
    
    print(f"\n⏱️ Total execution time: {end_time - start_time:.2f} seconds")
    
    # Return exit code based on results
    all_passed = all(r.get('success', False) for r in results.values())
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
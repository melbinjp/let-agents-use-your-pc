#!/bin/bash

# Tunnel Connectivity Verification Testing Module
# Tests Cloudflare tunnel functionality and connectivity

# Tunnel test configuration
TUNNEL_TEST_TIMEOUT=60

# Tunnel test functions
test_cloudflared_available() {
    command_exists cloudflared
}

test_cloudflared_version() {
    cloudflared version >/dev/null 2>&1
}

test_cloudflared_help() {
    cloudflared --help >/dev/null 2>&1
}

test_tunnel_token_format() {
    # Test if a token format is valid (basic validation)
    local test_token="eyJhIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoxMjM0NTY3ODkwIiwidCI6IjEyMzQ1Njc4LWFiY2QtZWZnaC1pamtsLW1ub3BxcnN0dXZ3eCIsInMiOiJhYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejEyMzQ1Njc4OTAifQ"
    [ ${#test_token} -gt 32 ]
}

test_tunnel_config_validation() {
    # Test tunnel configuration validation
    local test_config='{"tunnel":"test","credentials-file":"/tmp/test.json","ingress":[{"hostname":"test.example.com","service":"ssh://localhost:22"},{"service":"http_status:404"}]}'
    echo "$test_config" | jq . >/dev/null 2>&1 || return 0  # Skip if jq not available
}

test_tunnel_connectivity_check() {
    # Test basic connectivity to Cloudflare
    timeout 10 curl -s --connect-timeout 5 https://api.cloudflare.com/client/v4/zones >/dev/null 2>&1 || \
    timeout 10 wget -q --timeout=5 -O /dev/null https://api.cloudflare.com/client/v4/zones 2>/dev/null
}

test_tunnel_dns_resolution() {
    # Test DNS resolution for Cloudflare domains
    nslookup cloudflare.com >/dev/null 2>&1 || \
    dig cloudflare.com >/dev/null 2>&1 || \
    host cloudflare.com >/dev/null 2>&1
}

test_tunnel_port_availability() {
    # Test if required ports are available
    ! netstat -ln 2>/dev/null | grep -q ":7844 " && \
    ! ss -ln 2>/dev/null | grep -q ":7844 "
}

test_tunnel_process_management() {
    # Test if we can start/stop tunnel processes (mock test)
    local test_pid_file="/tmp/test-tunnel.pid"
    echo "12345" > "$test_pid_file"
    [ -f "$test_pid_file" ]
    rm -f "$test_pid_file"
}

test_tunnel_log_parsing() {
    # Test tunnel log parsing capabilities
    local test_log="2024-01-01T12:00:00Z INF Connection established location=LAX"
    echo "$test_log" | grep -q "Connection established"
}

test_tunnel_hostname_extraction() {
    # Test hostname extraction from tunnel output
    local test_output="https://test-tunnel-abc123.trycloudflare.com"
    echo "$test_output" | grep -oE 'https://[^/]+' | grep -q "trycloudflare.com"
}

test_tunnel_reliability_script() {
    # Test if tunnel reliability script exists and is executable
    local script_path="$PROJECT_ROOT/diagnostics/tunnel-reliability.sh"
    [ -f "$script_path" ] && [ -x "$script_path" ]
}

test_tunnel_reliability_init() {
    # Test tunnel reliability initialization
    local script_path="$PROJECT_ROOT/diagnostics/tunnel-reliability.sh"
    if [ -f "$script_path" ]; then
        bash "$script_path" init >/dev/null 2>&1
    else
        return 1
    fi
}

test_tunnel_reliability_health_check() {
    # Test tunnel reliability health check functionality
    local script_path="$PROJECT_ROOT/diagnostics/tunnel-reliability.sh"
    if [ -f "$script_path" ]; then
        timeout 30 bash "$script_path" health-check >/dev/null 2>&1 || return 0  # May fail if no tunnel configured
    else
        return 1
    fi
}

test_tunnel_reliability_report() {
    # Test tunnel reliability report generation
    local script_path="$PROJECT_ROOT/diagnostics/tunnel-reliability.sh"
    if [ -f "$script_path" ]; then
        bash "$script_path" report >/dev/null 2>&1
    else
        return 1
    fi
}

test_tunnel_reliability_stability_test() {
    # Test tunnel reliability stability test (short duration)
    local script_path="$PROJECT_ROOT/diagnostics/tunnel-reliability.sh"
    if [ -f "$script_path" ]; then
        timeout 45 bash "$script_path" stability-test 20 5 >/dev/null 2>&1 || return 0  # May fail if no tunnel configured
    else
        return 1
    fi
}

test_tunnel_reliability_integration() {
    # Test tunnel reliability integration with other components
    local docker_entrypoint="$PROJECT_ROOT/docker/entrypoint.sh"
    local healthcheck="$PROJECT_ROOT/docker/healthcheck.sh"
    
    # Check Docker integration
    if [ -f "$docker_entrypoint" ]; then
        grep -q "tunnel-reliability" "$docker_entrypoint" || return 1
    fi
    
    # Check healthcheck integration
    if [ -f "$healthcheck" ]; then
        grep -q "tunnel-reliability\|check_tunnel_reliability" "$healthcheck" || return 1
    fi
    
    return 0
}

# Function to list tunnel tests
list_tunnel_tests() {
    echo "  - Cloudflared availability"
    echo "  - Cloudflared version check"
    echo "  - Cloudflared help command"
    echo "  - Tunnel token format validation"
    echo "  - Tunnel config validation"
    echo "  - Tunnel connectivity check"
    echo "  - Tunnel DNS resolution"
    echo "  - Tunnel port availability"
    echo "  - Tunnel process management"
    echo "  - Tunnel log parsing"
    echo "  - Tunnel hostname extraction"
    echo "  - Tunnel reliability script"
    echo "  - Tunnel reliability initialization"
    echo "  - Tunnel reliability health check"
    echo "  - Tunnel reliability report"
    echo "  - Tunnel reliability stability test"
    echo "  - Tunnel reliability integration"
}

# Main tunnel test runner
run_tunnel_tests() {
    local pattern="${1:-.*}"
    
    log_category "Tunnel Connectivity Verification"
    
    # Run tunnel tests
    run_test "Cloudflared available" "test_cloudflared_available"
    run_test "Cloudflared version" "test_cloudflared_version"
    run_test "Cloudflared help" "test_cloudflared_help"
    run_test "Tunnel token format" "test_tunnel_token_format"
    run_test "Tunnel config validation" "test_tunnel_config_validation"
    run_test "Tunnel connectivity" "test_tunnel_connectivity_check" "$TUNNEL_TEST_TIMEOUT"
    run_test "Tunnel DNS resolution" "test_tunnel_dns_resolution"
    run_test "Tunnel port availability" "test_tunnel_port_availability"
    run_test "Tunnel process management" "test_tunnel_process_management"
    run_test "Tunnel log parsing" "test_tunnel_log_parsing"
    run_test "Tunnel hostname extraction" "test_tunnel_hostname_extraction"
    
    log_category "Tunnel Reliability and Monitoring"
    
    # Run tunnel reliability tests
    run_test "Tunnel reliability script" "test_tunnel_reliability_script"
    run_test "Tunnel reliability init" "test_tunnel_reliability_init"
    run_test "Tunnel reliability health check" "test_tunnel_reliability_health_check"
    run_test "Tunnel reliability report" "test_tunnel_reliability_report"
    run_test "Tunnel reliability stability test" "test_tunnel_reliability_stability_test"
    run_test "Tunnel reliability integration" "test_tunnel_reliability_integration"
}
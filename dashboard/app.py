#!/usr/bin/env python3
"""
Gasclaw Management Dashboard - Backend API
Monitors containers, gateways, agents, beads issues, and minimax service
"""

import json
import subprocess
import os
import re
import urllib.request
from datetime import datetime
from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Configuration
CONTAINERS = [
    {"name": "gasclaw-dev", "port": 18794, "bot": "@gasclaw_master_bot", "repo": "gasclaw"},
    {"name": "gasclaw-minimax", "port": 18793, "bot": "@minimax_gastown_publish_bot", "repo": "minimax"},
    {"name": "gasclaw-gasskill", "port": 18796, "bot": "@gasskill_agent_bot", "repo": "gasskill"},
    {"name": "gasclaw-mgmt", "port": None, "bot": None, "repo": "gasclaw-management"},
]

SERVICES = [
    {"name": "LiteLLM", "port": 4000, "type": "proxy"},
    {"name": "vLLM", "port": 8080, "type": "inference"},
]

# Store historical metrics for rate calculation
_metrics_history = {
    "tokens_per_second": [],
    "requests_per_second": [],
    "last_tokens_total": 0,
    "last_requests_total": 0,
    "last_update": None
}


def run_cmd(cmd, timeout=10):
    """Run shell command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout", 1
    except Exception as e:
        return "", str(e), 1


def get_docker_status():
    """Get Docker container status"""
    containers = []
    stdout, _, rc = run_cmd('docker ps --format "{{.Names}}|{{.Status}}|{{.Ports}}"')
    
    if rc != 0:
        return {"error": "Docker not available", "containers": []}
    
    running_containers = {}
    for line in stdout.split('\n'):
        if '|' in line:
            parts = line.split('|')
            if len(parts) >= 2:
                running_containers[parts[0]] = {
                    "status": parts[1],
                    "ports": parts[2] if len(parts) > 2 else ""
                }
    
    for cfg in CONTAINERS:
        name = cfg["name"]
        # Find matching container (exact match or suffix match for renamed containers)
        matched_name = None
        if name in running_containers:
            matched_name = name
        else:
            # Check if any running container name ends with our expected name
            for running_name in running_containers:
                if running_name.endswith(name):
                    matched_name = running_name
                    break
        
        if matched_name:
            info = running_containers[matched_name]
            containers.append({
                "name": name,
                "state": "running",
                "status": info["status"],
                "ports": info["ports"],
                "port": cfg["port"],
                "bot": cfg["bot"],
                "repo": cfg["repo"],
                "healthy": True
            })
        else:
            # Check if container exists but is stopped
            stdout, _, _ = run_cmd(f'docker ps -a --filter "name={name}" --format "{{{{.Status}}}}"')
            if stdout:
                containers.append({
                    "name": name,
                    "state": "stopped",
                    "status": stdout,
                    "ports": "",
                    "port": cfg["port"],
                    "bot": cfg["bot"],
                    "repo": cfg["repo"],
                    "healthy": False
                })
            else:
                containers.append({
                    "name": name,
                    "state": "not_found",
                    "status": "Container not found",
                    "ports": "",
                    "port": cfg["port"],
                    "bot": cfg["bot"],
                    "repo": cfg["repo"],
                    "healthy": False
                })
    
    return {"containers": containers}


def get_gateway_health():
    """Check OpenClaw gateway health for each container"""
    gateways = []
    for cfg in CONTAINERS:
        if cfg["port"] is None:
            continue
            
        port = cfg["port"]
        name = cfg["name"]
        
        try:
            req = urllib.request.Request(
                f"http://localhost:{port}/health",
                headers={"Accept": "application/json"},
                method="GET"
            )
            with urllib.request.urlopen(req, timeout=5) as response:
                data = json.loads(response.read().decode())
                gateways.append({
                    "container": name,
                    "port": port,
                    "healthy": data.get("ok", False),
                    "status": data.get("status", "unknown"),
                    "response_time_ms": 0,
                    "error": None
                })
        except Exception as e:
            gateways.append({
                "container": name,
                "port": port,
                "healthy": False,
                "status": "down",
                "response_time_ms": None,
                "error": str(e)
            })
    
    return {"gateways": gateways}


def get_service_health():
    """Check core services (LiteLLM, vLLM)"""
    services = []
    for svc in SERVICES:
        port = svc["port"]
        name = svc["name"]
        
        try:
            if name == "LiteLLM":
                req = urllib.request.Request(
                    f"http://localhost:{port}/health",
                    headers={"Accept": "application/json"},
                    method="GET"
                )
                with urllib.request.urlopen(req, timeout=5) as response:
                    data = json.loads(response.read().decode())
                    services.append({
                        "name": name,
                        "port": port,
                        "healthy": True,
                        "status": "healthy",
                        "details": data
                    })
            elif name == "vLLM":
                req = urllib.request.Request(
                    f"http://localhost:{port}/health",
                    method="GET"
                )
                with urllib.request.urlopen(req, timeout=5) as response:
                    services.append({
                        "name": name,
                        "port": port,
                        "healthy": response.status == 200,
                        "status": "healthy" if response.status == 200 else "unhealthy",
                        "details": {}
                    })
        except Exception as e:
            services.append({
                "name": name,
                "port": port,
                "healthy": False,
                "status": "down",
                "details": {"error": str(e)}
            })
    
    return {"services": services}


def parse_prometheus_metrics(metrics_text):
    """Parse Prometheus-style metrics from vLLM"""
    result = {}
    
    for line in metrics_text.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        # Parse gauge metrics
        match = re.match(r'(\w+):?(\w+)?\{([^}]+)\}\s+([\d.eE+-]+)', line)
        if match:
            metric_base = match.group(1) or ""
            metric_name = match.group(2) or ""
            labels_str = match.group(3)
            value = float(match.group(4))
            
            # Parse labels
            labels = {}
            for label_match in re.finditer(r'(\w+)="([^"]*)"', labels_str):
                labels[label_match.group(1)] = label_match.group(2)
            
            full_name = f"{metric_base}:{metric_name}" if metric_name else metric_base
            
            if full_name not in result:
                result[full_name] = []
            result[full_name].append({"labels": labels, "value": value})
        
        # Parse simple metrics without labels
        match = re.match(r'(\w+)\s+([\d.eE+-]+)', line)
        if match and not line.startswith('}'):
            metric_name = match.group(1)
            value = float(match.group(2))
            if metric_name not in result:
                result[metric_name] = []
            result[metric_name].append({"labels": {}, "value": value})
    
    return result


def get_minimax_metrics():
    """Get MiniMax (vLLM) service detailed metrics"""
    global _metrics_history
    
    try:
        req = urllib.request.Request(
            "http://localhost:8080/metrics",
            headers={"Accept": "text/plain"},
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            metrics_text = response.read().decode()
            parsed = parse_prometheus_metrics(metrics_text)
        
        # Extract key metrics
        now = datetime.now()
        
        # Running requests per engine
        running_requests = []
        waiting_requests = []
        total_running = 0
        total_waiting = 0
        
        if "vllm:num_requests_running" in parsed:
            for entry in parsed["vllm:num_requests_running"]:
                engine = entry["labels"].get("engine", "unknown")
                count = entry["value"]
                total_running += count
                running_requests.append({"engine": engine, "count": int(count)})
        
        if "vllm:num_requests_waiting" in parsed:
            for entry in parsed["vllm:num_requests_waiting"]:
                engine = entry["labels"].get("engine", "unknown")
                count = entry["value"]
                total_waiting += count
                waiting_requests.append({"engine": engine, "count": int(count)})
        
        # Token counts
        prompt_tokens_total = 0
        generation_tokens_total = 0
        
        if "vllm:request_prompt_tokens" in parsed:
            for entry in parsed["vllm:request_prompt_tokens"]:
                if "sum" in str(entry.get("labels", {})):
                    continue
                # Sum across engines
                prompt_tokens_total += entry["value"]
        
        if "vllm:request_generation_tokens" in parsed:
            for entry in parsed["vllm:request_generation_tokens"]:
                generation_tokens_total += entry["value"]
        
        # KV cache usage
        kv_cache_usage = []
        if "vllm:kv_cache_usage_perc" in parsed:
            for entry in parsed["vllm:kv_cache_usage_perc"]:
                engine = entry["labels"].get("engine", "unknown")
                usage = entry["value"]
                kv_cache_usage.append({"engine": engine, "usage_percent": round(usage * 100, 2)})
        
        # Engine states
        engine_states = []
        if "vllm:engine_sleep_state" in parsed:
            for entry in parsed["vllm:engine_sleep_state"]:
                engine = entry["labels"].get("engine", "unknown")
                state_type = entry["labels"].get("sleep_state", "unknown")
                value = entry["value"]
                engine_states.append({
                    "engine": engine, 
                    "state": state_type, 
                    "value": int(value)
                })
        
        # Calculate rates if we have history
        tokens_per_second = 0
        requests_per_second = 0
        
        if _metrics_history["last_update"]:
            time_diff = (now - _metrics_history["last_update"]).total_seconds()
            if time_diff > 0:
                current_total = prompt_tokens_total + generation_tokens_total
                prev_total = _metrics_history["last_tokens_total"]
                tokens_diff = current_total - prev_total
                tokens_per_second = tokens_diff / time_diff
                
                # Estimate requests from token rate
                # This is approximate since we don't have direct request count
                requests_per_second = tokens_per_second / 500  # rough estimate
        
        # Update history
        _metrics_history["last_update"] = now
        _metrics_history["last_tokens_total"] = prompt_tokens_total + generation_tokens_total
        
        # Keep last 60 seconds of history
        _metrics_history["tokens_per_second"].append({
            "time": now.isoformat(),
            "value": round(tokens_per_second, 2)
        })
        if len(_metrics_history["tokens_per_second"]) > 60:
            _metrics_history["tokens_per_second"].pop(0)
        
        return {
            "status": "healthy",
            "model": "minimax-m2.5",
            "parallel_sessions": {
                "running": total_running,
                "waiting": total_waiting,
                "total": total_running + total_waiting,
                "per_engine": running_requests
            },
            "tokens": {
                "prompt_total": int(prompt_tokens_total),
                "generation_total": int(generation_tokens_total),
                "total": int(prompt_tokens_total + generation_tokens_total),
                "per_second": round(tokens_per_second, 2),
                "history": _metrics_history["tokens_per_second"][-20:]  # Last 20 readings
            },
            "kv_cache": kv_cache_usage,
            "engine_states": engine_states,
            "raw_metrics": parsed
        }
        
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "parallel_sessions": {"running": 0, "waiting": 0, "total": 0, "per_engine": []},
            "tokens": {"prompt_total": 0, "generation_total": 0, "total": 0, "per_second": 0, "history": []},
            "kv_cache": [],
            "engine_states": []
        }


def get_beads_issues():
    """Get issues from beads tracking system"""
    issues = []
    
    stdout, stderr, rc = run_cmd("bd list --json 2>/dev/null", timeout=15)
    
    if rc == 0 and stdout:
        try:
            data = json.loads(stdout)
            for item in data:
                issues.append({
                    "id": item.get("id"),
                    "title": item.get("title"),
                    "status": item.get("status"),
                    "priority": item.get("priority"),
                    "type": item.get("issue_type"),
                    "owner": item.get("owner"),
                    "created_at": item.get("created_at"),
                    "description": item.get("description", "")[:100]
                })
        except json.JSONDecodeError:
            pass
    
    # Count by status and priority
    summary = {
        "total": len(issues),
        "open": len([i for i in issues if i["status"] == "open"]),
        "closed": len([i for i in issues if i["status"] == "closed"]),
        "critical": len([i for i in issues if i["priority"] == 0]),
        "high": len([i for i in issues if i["priority"] == 1]),
        "medium": len([i for i in issues if i["priority"] == 2]),
        "low": len([i for i in issues if i["priority"] >= 3])
    }
    
    return {"issues": issues, "summary": summary}


def get_agent_status():
    """Get agent status from each container"""
    agents = []
    
    # Define expected agents per container
    agent_map = {
        "gasclaw-dev": ["main", "crew-1", "crew-2"],
        "gasclaw-minimax": ["main", "coordinator", "developer", "devops", "tester", "reviewer"],
        "gasclaw-gasskill": ["main", "skill-dev", "skill-tester"],
    }
    
    for container_pattern, agent_list in agent_map.items():
        # Check if container is running and get actual container name
        stdout, _, rc = run_cmd(f'docker ps --filter "name={container_pattern}" --format "{{{{.Names}}}}"')
        actual_container = stdout.strip() if stdout else ""
        is_running = container_pattern in actual_container and actual_container != ""
        
        # Get list of configured agents from the container
        configured_agents = set()
        if is_running and actual_container:
            stdout, _, rc = run_cmd(
                f'docker exec {actual_container} openclaw agents list 2>/dev/null',
                timeout=10
            )
            if stdout:
                # Parse agent names from output like "- main (default)"
                for line in stdout.split('\n'):
                    if line.strip().startswith('- '):
                        agent_name = line.strip()[2:].split()[0]
                        configured_agents.add(agent_name)
        
        for agent in agent_list:
            if not is_running:
                status = "offline"
            elif agent in configured_agents and actual_container:
                # Agent is configured - check if it has recent activity via sessions
                stdout, _, rc = run_cmd(
                    f'docker exec {actual_container} bash -c "stat -c %Y ~/.openclaw/agents/{agent}/sessions/sessions.json 2>/dev/null || echo 0"',
                    timeout=5
                )
                try:
                    last_modified = int(stdout.strip()) if stdout.strip().isdigit() else 0
                    import time
                    age_seconds = time.time() - last_modified
                    # If sessions file was modified in last hour, consider active
                    status = "active" if age_seconds < 3600 else "idle"
                except:
                    status = "idle"
            else:
                status = "unknown"
            
            agents.append({
                "name": agent,
                "container": container_pattern,
                "status": status,
                "container_running": is_running
            })
    
    return {"agents": agents}


def get_system_metrics():
    """Get basic system metrics"""
    metrics = {}
    
    # GPU info (if nvidia-smi available)
    stdout, _, rc = run_cmd("nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null", timeout=5)
    if rc == 0:
        gpus = []
        for line in stdout.split('\n'):
            if line.strip():
                parts = [p.strip() for p in line.split(',')]
                if len(parts) >= 5:
                    gpus.append({
                        "name": parts[0],
                        "temperature_c": parts[1],
                        "utilization_percent": parts[2].replace(" %", ""),
                        "memory_used": parts[3],
                        "memory_total": parts[4]
                    })
        metrics["gpus"] = gpus
    
    # Load average
    stdout, _, rc = run_cmd("uptime | awk -F'load average:' '{print $2}'")
    if rc == 0:
        metrics["load_average"] = stdout.strip()
    
    # Memory
    stdout, _, rc = run_cmd("free -h | awk '/^Mem:/ {print $3 \"/\" $2}'")
    if rc == 0:
        metrics["memory_used"] = stdout.strip()
    
    return metrics


@app.route('/api/health')
def health():
    """API health check"""
    return jsonify({"ok": True, "time": datetime.now().isoformat()})


@app.route('/api/overview')
def overview():
    """Get overview of entire system"""
    return jsonify({
        "time": datetime.now().isoformat(),
        "docker": get_docker_status(),
        "gateways": get_gateway_health(),
        "services": get_service_health(),
        "minimax": get_minimax_metrics(),
        "beads": get_beads_issues(),
        "agents": get_agent_status(),
        "metrics": get_system_metrics()
    })


@app.route('/api/containers')
def containers():
    """Get Docker container status"""
    return jsonify(get_docker_status())


@app.route('/api/gateways')
def gateways():
    """Get gateway health"""
    return jsonify(get_gateway_health())


@app.route('/api/services')
def services():
    """Get service health"""
    return jsonify(get_service_health())


@app.route('/api/minimax')
def minimax():
    """Get MiniMax service metrics"""
    return jsonify(get_minimax_metrics())


@app.route('/api/issues')
def issues():
    """Get beads issues"""
    return jsonify(get_beads_issues())


@app.route('/api/agents')
def agents():
    """Get agent status"""
    return jsonify(get_agent_status())


@app.route('/api/metrics')
def metrics():
    """Get system metrics"""
    return jsonify(get_system_metrics())


@app.route('/')
def index():
    """Serve the dashboard UI"""
    return send_from_directory('static', 'index.html')


@app.route('/<path:path>')
def static_files(path):
    """Serve static files"""
    return send_from_directory('static', path)


if __name__ == '__main__':
    print("🚀 Starting Gasclaw Management Dashboard...")
    print("📊 Open http://localhost:5000 in your browser")
    app.run(host='0.0.0.0', port=5000, debug=True)

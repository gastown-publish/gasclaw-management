#!/usr/bin/env python3
"""Demo mode for Gasclaw TUI - shows UI without API dependency"""

import sys
import time
from datetime import datetime

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.layout import Layout
    from rich.live import Live
    from rich import box
    from rich.columns import Columns
    HAS_RICH = True
except ImportError:
    HAS_RICH = False
    print("This demo requires 'rich'. Install: pip install rich")
    sys.exit(1)

console = Console()

# Demo data
DEMO_CONTAINERS = [
    {"name": "gasclaw-dev", "status": "running", "uptime": "3 days", "image": "gasclaw:latest"},
    {"name": "gasclaw-minimax", "status": "running", "uptime": "3 days", "image": "gasclaw:latest"},
    {"name": "gasclaw-gasskill", "status": "running", "uptime": "2 days", "image": "gasclaw:latest"},
]

DEMO_AGENTS = [
    {"name": "main", "container": "gasclaw-dev", "status": "active", "type": "coordinator"},
    {"name": "crew-1", "container": "gasclaw-dev", "status": "active", "type": "worker"},
    {"name": "crew-2", "container": "gasclaw-dev", "status": "idle", "type": "worker"},
    {"name": "coordinator", "container": "gasclaw-minimax", "status": "active", "type": "vllm"},
    {"name": "developer", "container": "gasclaw-minimax", "status": "active", "type": "coder"},
    {"name": "devops", "container": "gasclaw-minimax", "status": "active", "type": "infra"},
]

DEMO_GATEWAYS = [
    {"container": "gasclaw-dev", "port": 18794, "healthy": True, "response_time_ms": 12},
    {"container": "gasclaw-minimax", "port": 18793, "healthy": True, "response_time_ms": 8},
    {"container": "gasclaw-gasskill", "port": 18796, "healthy": True, "response_time_ms": 15},
]

DEMO_ISSUES = [
    {"id": "gasclaw-management-abc", "title": "Update vLLM to latest version", "priority": 1, "status": "open", "assignee": "Agent"},
    {"id": "gasclaw-management-def", "title": "Optimize KV cache usage", "priority": 2, "status": "in_progress", "assignee": "Agent"},
    {"id": "gasclaw-management-ghi", "title": "Add monitoring alerts", "priority": 2, "status": "open", "assignee": None},
]

DEMO_GPUS = [
    {"index": 0, "name": "NVIDIA H100 80GB HBM3", "temperature": 45, "utilization": 78, "memory_used": 45000, "memory_total": 80000, "power": 320},
    {"index": 1, "name": "NVIDIA H100 80GB HBM3", "temperature": 42, "utilization": 65, "memory_used": 38000, "memory_total": 80000, "power": 290},
]

DEMO_MINIMAX = {
    "status": "healthy",
    "tokens_per_sec": 1250.5,
    "active_sessions": 3,
    "max_parallel": 8,
}


def generate_layout():
    """Generate the full TUI layout"""
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=3),
        Layout(name="main"),
        Layout(name="footer", size=3)
    )
    layout["main"].split_row(
        Layout(name="left"),
        Layout(name="right")
    )
    
    # Header
    status = "🟢 OPERATIONAL"
    layout["header"].update(Panel(
        f"[bold cyan]Gasclaw Management[/] | {status} | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", 
        border_style="cyan"
    ))
    
    # Left column - Containers and Agents
    # Containers table
    c_table = Table(box=box.SIMPLE, title="Containers", expand=True)
    c_table.add_column("Name", style="cyan")
    c_table.add_column("Status")
    c_table.add_column("Uptime")
    for c in DEMO_CONTAINERS:
        status_color = "green" if c["status"] == "running" else "red"
        c_table.add_row(c["name"], f"[{status_color}]{c['status']}[/]", c["uptime"])
    
    # Agents table
    active_count = sum(1 for a in DEMO_AGENTS if a["status"] == "active")
    a_table = Table(box=box.SIMPLE, title=f"Agents ({active_count}/{len(DEMO_AGENTS)})", expand=True)
    a_table.add_column("Agent", style="cyan")
    a_table.add_column("Container")
    a_table.add_column("Status")
    for a in DEMO_AGENTS:
        status_color = "green" if a["status"] == "active" else "yellow"
        a_table.add_row(a["name"], a["container"], f"[{status_color}]{a['status']}[/]")
    
    layout["left"].update(Panel(Columns([c_table, a_table]), border_style="blue"))
    
    # Right column - Issues and MiniMax
    # Issues table
    i_table = Table(box=box.SIMPLE, title=f"Issues ({len(DEMO_ISSUES)})", expand=True)
    i_table.add_column("ID", style="cyan")
    i_table.add_column("Title")
    i_table.add_column("Priority")
    priority_colors = {0: "red", 1: "yellow", 2: "blue", 3: "white", 4: "dim"}
    priority_names = {0: "Critical", 1: "High", 2: "Medium", 3: "Low", 4: "Backlog"}
    for i in DEMO_ISSUES:
        p = i["priority"]
        i_table.add_row(i["id"][:20], i["title"][:25], f"[{priority_colors.get(p,'white')}]{priority_names.get(p,'?')}[/]")
    
    # MiniMax panel
    mm_text = f"""[bold]MiniMax vLLM[/]
Status: [green]✓ healthy[/green]
Tokens/sec: [cyan]{DEMO_MINIMAX['tokens_per_sec']:.1f}[/cyan]
Sessions: {DEMO_MINIMAX['active_sessions']}/{DEMO_MINIMAX['max_parallel']}
KV Cache: [green]68%[/green]"""
    
    # Gateways mini-table
    g_table = Table(box=box.SIMPLE, title=f"Gateways ({len(DEMO_GATEWAYS)})", expand=True)
    g_table.add_column("Container", style="cyan")
    g_table.add_column("Port")
    g_table.add_column("Latency")
    for g in DEMO_GATEWAYS:
        g_table.add_row(g["container"], str(g["port"]), f"{g['response_time_ms']}ms")
    
    layout["right"].update(Panel(Columns([i_table, Panel(mm_text), g_table]), border_style="green"))
    
    # Footer
    layout["footer"].update(Panel(
        "[dim]Press Ctrl+C to exit | Commands: [s]tatus [c]ontainers [a]gents [i]ssues [g]ateways [m]etrics [q]uit[/dim]", 
        border_style="dim"
    ))
    
    return layout


def demo_static():
    """Show static demo"""
    console.print(generate_layout())
    
    # Also show GPU metrics
    console.print("\n")
    gpu_table = Table(box=box.ROUNDED, title=f"GPU Metrics ({len(DEMO_GPUS)}x H100)")
    gpu_table.add_column("GPU", style="cyan")
    gpu_table.add_column("Name")
    gpu_table.add_column("Temp", style="yellow")
    gpu_table.add_column("Util", style="green")
    gpu_table.add_column("Memory")
    gpu_table.add_column("Power")
    
    for g in DEMO_GPUS:
        temp_color = "red" if g["temperature"] > 80 else "yellow" if g["temperature"] > 70 else "green"
        util_color = "red" if g["utilization"] > 95 else "yellow" if g["utilization"] > 80 else "green"
        gpu_table.add_row(
            f"GPU {g['index']}",
            g["name"][:25],
            f"[{temp_color}]{g['temperature']}°C[/]",
            f"[{util_color}]{g['utilization']}%[/]",
            f"{g['memory_used']/1000:.1f}/{g['memory_total']/1000:.1f} GB",
            f"{g['power']}W"
        )
    console.print(Panel(gpu_table, border_style="magenta"))


def demo_live():
    """Show live updating demo"""
    try:
        with Live(generate_layout(), refresh_per_second=0.5, screen=True) as live:
            while True:
                time.sleep(2)
                live.update(generate_layout())
    except KeyboardInterrupt:
        console.print("\n[dim]Demo ended[/dim]")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Gasclaw TUI Demo")
    parser.add_argument("--live", "-l", action="store_true", help="Live updating mode")
    args = parser.parse_args()
    
    if args.live:
        demo_live()
    else:
        demo_static()

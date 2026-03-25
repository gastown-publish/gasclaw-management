#!/usr/bin/env python3
"""
Gasclaw Management TUI - AI-Optimized Terminal Interface

A terminal user interface for managing Gasclaw infrastructure,
designed for both human and AI agent interaction.

Usage:
    gasclaw status              # Show system status
    gasclaw status --json       # Machine-readable output
    gasclaw containers          # List containers
    gasclaw agents --watch      # Watch agent status
    gasclaw issues --filter=open # Filter issues
    gasclaw tui                 # Interactive TUI mode
"""

import sys
import json
import time
import click
import requests
from datetime import datetime
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict

# Optional rich import for beautiful output
try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.layout import Layout
    from rich.live import Live
    from rich import box
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

# Exit codes for automation
EXIT_SUCCESS = 0
EXIT_WARNING = 1
EXIT_ERROR = 2

DEFAULT_API_URL = "https://status.gpu.villamarket.ai"


@dataclass
class StatusSummary:
    """System status summary for AI parsing"""
    healthy: bool
    containers_running: int
    containers_total: int
    agents_active: int
    agents_total: int
    gateways_healthy: int
    gateways_total: int
    critical_issues: int
    high_issues: int
    timestamp: str
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class GasclawAPI:
    """API client for dashboard backend"""
    
    def __init__(self, base_url: str = DEFAULT_API_URL):
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'Accept': 'application/json',
            'User-Agent': 'gasclaw-tui/1.0'
        })
    
    def health(self) -> Dict[str, Any]:
        """Get health status"""
        try:
            resp = self.session.get(f"{self.base_url}/api/health", timeout=5)
            return resp.json()
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    def overview(self) -> Dict[str, Any]:
        """Get system overview"""
        try:
            resp = self.session.get(f"{self.base_url}/api/overview", timeout=30)
            return resp.json()
        except Exception as e:
            return {"status": "error", "error": str(e)}
    
    def containers(self) -> List[Dict[str, Any]]:
        """Get container list"""
        try:
            resp = self.session.get(f"{self.base_url}/api/containers", timeout=5)
            return resp.json().get('containers', [])
        except Exception as e:
            return []
    
    def gateways(self) -> Dict[str, Any]:
        """Get gateway status"""
        try:
            resp = self.session.get(f"{self.base_url}/api/gateways", timeout=5)
            return resp.json()
        except Exception as e:
            return {"gateways": [], "error": str(e)}
    
    def agents(self) -> Dict[str, Any]:
        """Get agent status"""
        try:
            resp = self.session.get(f"{self.base_url}/api/agents", timeout=15)
            return resp.json()
        except Exception as e:
            return {"agents": [], "error": str(e)}
    
    def issues(self) -> List[Dict[str, Any]]:
        """Get beads issues"""
        try:
            resp = self.session.get(f"{self.base_url}/api/issues", timeout=5)
            return resp.json().get('issues', [])
        except Exception as e:
            return []
    
    def metrics(self) -> Dict[str, Any]:
        """Get GPU metrics"""
        try:
            resp = self.session.get(f"{self.base_url}/api/metrics", timeout=5)
            return resp.json()
        except Exception as e:
            return {"gpus": [], "error": str(e)}


def format_status(status: str) -> str:
    """Format status with emoji for terminal"""
    icons = {
        'running': '🟢',
        'healthy': '🟢',
        'active': '🟢',
        'up': '🟢',
        'stopped': '🔴',
        'unhealthy': '🔴',
        'down': '🔴',
        'idle': '🟡',
        'unknown': '⚪',
        'open': '🔵',
        'in_progress': '🟠',
        'closed': '✅'
    }
    return f"{icons.get(status.lower(), '⚪')} {status}"


def get_exit_code(data: Dict[str, Any]) -> int:
    """Determine exit code from response data"""
    if data.get('status') == 'error':
        return EXIT_ERROR
    
    # Check for unhealthy components
    if isinstance(data, dict):
        if data.get('status') == 'unhealthy':
            return EXIT_ERROR
        
        # Check containers
        docker_data = data.get('docker', {})
        containers = docker_data.get('containers', []) if isinstance(docker_data, dict) else []
        if any(c.get('status') != 'running' for c in containers):
            return EXIT_WARNING
        
        # Check gateways
        gateways_data = data.get('gateways', {})
        gateways = gateways_data.get('gateways', []) if isinstance(gateways_data, dict) else gateways_data
        if any(not g.get('healthy', False) for g in gateways):
            return EXIT_WARNING
    
    return EXIT_SUCCESS


@click.group()
@click.option('--api-url', default=DEFAULT_API_URL, help='Dashboard API URL')
@click.option('--json', 'output_json', is_flag=True, help='Output JSON (AI mode)')
@click.option('--yaml', 'output_yaml', is_flag=True, help='Output YAML (AI mode)')
@click.pass_context
def cli(ctx, api_url: str, output_json: bool, output_yaml: bool):
    """Gasclaw Management TUI - AI-Optimized"""
    ctx.ensure_object(dict)
    ctx.obj['api'] = GasclawAPI(api_url)
    ctx.obj['output_json'] = output_json
    ctx.obj['output_yaml'] = output_yaml
    ctx.obj['console'] = Console() if HAS_RICH else None


@cli.command()
@click.pass_context
def status(ctx):
    """Show overall system status"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    output_yaml = ctx.obj['output_yaml']
    console = ctx.obj['console']
    
    data = api.overview()
    
    if output_json:
        click.echo(json.dumps(data, indent=2))
        sys.exit(get_exit_code(data))
    
    if output_yaml:
        try:
            import yaml
            click.echo(yaml.dump(data, default_flow_style=False))
        except ImportError:
            click.echo("# YAML output requires PyYAML: pip install pyyaml", err=True)
            click.echo(json.dumps(data, indent=2))
        sys.exit(get_exit_code(data))
    
    # Rich terminal output
    if HAS_RICH and console:
        layout = Layout()
        
        # Health status
        health = data.get('health', {})
        health_text = f"[green]●[/green] Healthy" if health.get('status') == 'healthy' else f"[red]●[/red] Issues Detected"
        
        # Summary table
        summary = Table(box=box.ROUNDED, title="System Overview")
        summary.add_column("Component", style="cyan")
        summary.add_column("Status", style="green")
        summary.add_column("Details")
        
        docker_data = data.get('docker', {})
        containers = docker_data.get('containers', []) if isinstance(docker_data, dict) else []
        running = sum(1 for c in containers if c.get('state') == 'running')
        summary.add_row("Containers", f"{running}/{len(containers)} running", 
                       "✓ All operational" if running == len(containers) else "⚠ Some stopped")
        
        gateways_data = data.get('gateways', {})
        gateways = gateways_data.get('gateways', []) if isinstance(gateways_data, dict) else gateways_data
        healthy = sum(1 for g in gateways if g.get('healthy', False))
        summary.add_row("Gateways", f"{healthy}/{len(gateways)} healthy",
                       "✓ All healthy" if healthy == len(gateways) else "⚠ Some unhealthy")
        
        agents_data = data.get('agents', {})
        agents_list = agents_data.get('agents', []) if isinstance(agents_data, dict) else []
        active = sum(1 for a in agents_list if a.get('status') == 'active')
        total = len(agents_list)
        summary.add_row("Agents", f"{active}/{total} active",
                       "✓ All active" if active == total else "⚠ Some inactive")
        
        beads_data = data.get('beads', {})
        issues = beads_data.get('issues', []) if isinstance(beads_data, dict) else []
        critical = sum(1 for i in issues if i.get('priority') == 0)
        high = sum(1 for i in issues if i.get('priority') == 1)
        issue_status = f"[red]{critical} critical[/red], [yellow]{high} high[/yellow]" if (critical + high) > 0 else "[green]✓ No urgent issues[/green]"
        summary.add_row("Issues", f"{len(issues)} total", issue_status)
        
        console.print(Panel(summary, title="[bold cyan]Gasclaw Status[/bold cyan]", border_style="cyan"))
        
        # MiniMax status
        minimax = data.get('minimax', {})
        if minimax:
            mm_table = Table(box=box.SIMPLE)
            mm_table.add_column("Service")
            mm_table.add_column("Status")
            mm_table.add_row("MiniMax vLLM", format_status(minimax.get('status', 'unknown')))
            mm_table.add_row("Tokens/sec", str(minimax.get('tokens_per_sec', 0)))
            mm_table.add_row("Active Sessions", f"{minimax.get('active_sessions', 0)}/{minimax.get('max_parallel', 0)}")
            console.print(Panel(mm_table, title="[bold]MiniMax Service[/bold]"))
    else:
        # Plain text output
        click.echo("=== Gasclaw System Status ===\n")
        
        containers = data.get('containers', [])
        click.echo(f"Containers: {sum(1 for c in containers if c.get('status') == 'running')}/{len(containers)} running")
        
        gateways = data.get('gateways', [])
        click.echo(f"Gateways: {sum(1 for g in gateways if g.get('status') == 'healthy')}/{len(gateways)} healthy")
        
        agents = data.get('agents', {})
        click.echo(f"Agents: {agents.get('active', 0)}/{agents.get('total', 0)} active")
        
        issues = data.get('issues', [])
        critical = sum(1 for i in issues if i.get('priority') == 0)
        high = sum(1 for i in issues if i.get('priority') == 1)
        click.echo(f"Issues: {len(issues)} total ({critical} critical, {high} high)")
    
    sys.exit(get_exit_code(data))


@cli.command()
@click.option('--watch', '-w', is_flag=True, help='Watch mode (auto-refresh)')
@click.option('--interval', '-i', default=5, help='Refresh interval in seconds')
@click.pass_context
def containers(ctx, watch: bool, interval: int):
    """Show container status"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    console = ctx.obj['console']
    
    def fetch():
        return api.containers()
    
    def render(data):
        if output_json:
            return json.dumps(data, indent=2)
        
        if HAS_RICH and console:
            table = Table(box=box.ROUNDED, title="Docker Containers")
            table.add_column("Name", style="cyan")
            table.add_column("Status", style="green")
            table.add_column("Uptime")
            table.add_column("Image")
            
            for c in data:
                status_color = "green" if c.get('status') == 'running' else "red"
                table.add_row(
                    c.get('name', 'unknown'),
                    f"[{status_color}]{c.get('status', 'unknown')}[/]",
                    c.get('uptime', 'N/A'),
                    c.get('image', 'unknown')[:40]
                )
            return table
        else:
            lines = ["=== Containers ==="]
            for c in data:
                lines.append(f"{c.get('name', 'unknown')}: {c.get('status', 'unknown')}")
            return "\n".join(lines)
    
    if watch:
        if HAS_RICH and console and not output_json:
            with Live(render(fetch()), refresh_per_second=1/interval) as live:
                while True:
                    time.sleep(interval)
                    live.update(render(fetch()))
        else:
            while True:
                click.clear()
                click.echo(render(fetch()))
                time.sleep(interval)
    else:
        output = render(fetch())
        if isinstance(output, str):
            click.echo(output)
        else:
            console.print(output)


@cli.command()
@click.option('--watch', '-w', is_flag=True, help='Watch mode')
@click.option('--interval', '-i', default=5, help='Refresh interval')
@click.pass_context
def agents(ctx, watch: bool, interval: int):
    """Show agent status"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    console = ctx.obj['console']
    
    def fetch():
        return api.agents()
    
    def render(data):
        if output_json:
            return json.dumps(data, indent=2)
        
        agents_list = data.get('agents', [])
        active_count = sum(1 for a in agents_list if a.get('status') == 'active')
        total_count = len(agents_list)
        
        if HAS_RICH and console:
            table = Table(box=box.ROUNDED, title=f"Agents ({active_count}/{total_count} active)")
            table.add_column("Agent", style="cyan")
            table.add_column("Container")
            table.add_column("Status", style="green")
            table.add_column("Type")
            
            for a in agents_list:
                status = a.get('status', 'unknown')
                status_color = "green" if status == 'active' else "yellow" if status == 'idle' else "red"
                table.add_row(
                    a.get('name', 'unknown'),
                    a.get('container', 'unknown'),
                    f"[{status_color}]{status}[/]",
                    a.get('type', 'unknown')
                )
            return table
        else:
            lines = [f"=== Agents ({active_count}/{total_count} active) ==="]
            for a in agents_list:
                lines.append(f"{a.get('name', 'unknown')}: {a.get('status', 'unknown')} ({a.get('container', 'unknown')})")
            return "\n".join(lines)
    
    if watch:
        if HAS_RICH and console and not output_json:
            with Live(render(fetch()), refresh_per_second=1/interval) as live:
                while True:
                    time.sleep(interval)
                    live.update(render(fetch()))
        else:
            while True:
                click.clear()
                click.echo(render(fetch()))
                time.sleep(interval)
    else:
        output = render(fetch())
        if isinstance(output, str):
            click.echo(output)
        else:
            console.print(output)


@cli.command()
@click.option('--filter', '-f', type=click.Choice(['open', 'in_progress', 'closed', 'all']), default='open')
@click.option('--priority', '-p', type=int, help='Filter by priority (0-4)')
@click.pass_context
def issues(ctx, filter: str, priority: Optional[int]):
    """Show beads issues"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    console = ctx.obj['console']
    
    data = api.issues()
    
    # Apply filters
    if filter != 'all':
        data = [i for i in data if i.get('status') == filter]
    if priority is not None:
        data = [i for i in data if i.get('priority') == priority]
    
    # Priority names
    priority_names = {0: 'Critical', 1: 'High', 2: 'Medium', 3: 'Low', 4: 'Backlog'}
    
    if output_json:
        click.echo(json.dumps(data, indent=2))
        return
    
    if HAS_RICH and console:
        table = Table(box=box.ROUNDED, title=f"Issues ({len(data)})")
        table.add_column("ID", style="cyan")
        table.add_column("Title")
        table.add_column("Priority")
        table.add_column("Status", style="green")
        table.add_column("Assignee")
        
        for i in data:
            p = i.get('priority', 2)
            p_color = {0: 'red', 1: 'yellow', 2: 'blue', 3: 'white', 4: 'dim'}.get(p, 'white')
            table.add_row(
                i.get('id', 'unknown'),
                i.get('title', 'Untitled')[:50],
                f"[{p_color}]{priority_names.get(p, 'Unknown')}[/]",
                i.get('status', 'unknown'),
                i.get('assignee', 'Unassigned')[:20]
            )
        console.print(table)
    else:
        click.echo(f"=== Issues ({len(data)}) ===")
        for i in data:
            p = priority_names.get(i.get('priority', 2), 'Unknown')
            click.echo(f"[{i.get('id', 'unknown')}] {i.get('title', 'Untitled')[:50]} ({p}, {i.get('status', 'unknown')})")


@cli.command()
@click.pass_context
def gateways(ctx):
    """Show gateway status"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    console = ctx.obj['console']
    
    data = api.gateways()
    gateways_list = data.get('gateways', [])
    
    if output_json:
        click.echo(json.dumps(data, indent=2))
        return
    
    if HAS_RICH and console:
        table = Table(box=box.ROUNDED, title=f"OpenClaw Gateways ({len(gateways_list)})")
        table.add_column("Container", style="cyan")
        table.add_column("Port")
        table.add_column("Status", style="green")
        table.add_column("Latency")
        
        for g in gateways_list:
            healthy = g.get('healthy', False)
            status_color = "green" if healthy else "red"
            status_text = "healthy" if healthy else "unhealthy"
            table.add_row(
                g.get('container', 'unknown'),
                str(g.get('port', 'N/A')),
                f"[{status_color}]{status_text}[/]",
                f"{g.get('response_time_ms', 0)}ms"
            )
        console.print(table)
    else:
        click.echo(f"=== Gateways ({len(gateways_list)}) ===")
        for g in gateways_list:
            status = "healthy" if g.get('healthy') else "unhealthy"
            click.echo(f"{g.get('container', 'unknown')}: {status} (port {g.get('port', 'N/A')})")


@cli.command()
@click.pass_context
def metrics(ctx):
    """Show GPU metrics"""
    api = ctx.obj['api']
    output_json = ctx.obj['output_json']
    console = ctx.obj['console']
    
    data = api.metrics()
    gpus = data.get('gpus', [])
    
    if output_json:
        click.echo(json.dumps(data, indent=2))
        return
    
    if HAS_RICH and console:
        table = Table(box=box.ROUNDED, title=f"GPU Metrics ({len(gpus)} GPUs)")
        table.add_column("GPU", style="cyan")
        table.add_column("Name")
        table.add_column("Temp", style="yellow")
        table.add_column("Util", style="green")
        table.add_column("Memory")
        table.add_column("Power")
        
        for g in gpus:
            temp = g.get('temperature', 0)
            temp_color = "red" if temp > 80 else "yellow" if temp > 70 else "green"
            util = g.get('utilization', 0)
            util_color = "red" if util > 95 else "yellow" if util > 80 else "green"
            
            table.add_row(
                f"GPU {g.get('index', 0)}",
                g.get('name', 'Unknown')[:25],
                f"[{temp_color}]{temp}°C[/]",
                f"[{util_color}]{util}%[/]",
                f"{g.get('memory_used', 0)}/{g.get('memory_total', 0)} MB",
                f"{g.get('power', 0)}W"
            )
        console.print(table)
    else:
        click.echo(f"=== GPU Metrics ({len(gpus)} GPUs) ===")
        for g in gpus:
            click.echo(f"GPU {g.get('index', 0)}: {g.get('name', 'Unknown')}")
            click.echo(f"  Temp: {g.get('temperature', 0)}°C | Util: {g.get('utilization', 0)}%")
            click.echo(f"  Memory: {g.get('memory_used', 0)}/{g.get('memory_total', 0)} MB")


@cli.command()
@click.pass_context
def tui(ctx):
    """Interactive TUI mode (requires rich)"""
    if not HAS_RICH:
        click.echo("Interactive TUI requires 'rich'. Install with: pip install rich", err=True)
        sys.exit(EXIT_ERROR)
    
    api = ctx.obj['api']
    console = ctx.obj['console']
    
    from rich.layout import Layout
    from rich.live import Live
    
    def generate_layout():
        data = api.overview()
        
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
        health = data.get('health', {})
        status = "🟢 OPERATIONAL" if health.get('status') == 'healthy' else "🔴 DEGRADED"
        layout["header"].update(Panel(f"[bold cyan]Gasclaw Management[/] | {status} | {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", 
                                     border_style="cyan"))
        
        # Left panel - Containers & Agents
        left_content = ""
        
        containers = data.get('containers', [])
        c_table = Table(box=box.SIMPLE, title="Containers")
        c_table.add_column("Name", style="cyan")
        c_table.add_column("Status")
        for c in containers[:5]:
            status_color = "green" if c.get('status') == 'running' else "red"
            c_table.add_row(c.get('name', '?'), f"[{status_color}]{c.get('status', '?')}[/]")
        
        agents = data.get('agents', {})
        a_table = Table(box=box.SIMPLE, title=f"Agents ({agents.get('active', 0)}/{agents.get('total', 0)})")
        a_table.add_column("Agent", style="cyan")
        a_table.add_column("Status")
        for a in agents.get('agents', [])[:5]:
            status_color = "green" if a.get('status') == 'active' else "yellow"
            a_table.add_row(a.get('name', '?'), f"[{status_color}]{a.get('status', '?')}[/]")
        
        from rich.columns import Columns
        layout["left"].update(Panel(Columns([c_table, a_table]), border_style="blue"))
        
        # Right panel - Issues & MiniMax
        issues = data.get('issues', [])
        i_table = Table(box=box.SIMPLE, title=f"Issues ({len(issues)})")
        i_table.add_column("ID", style="cyan")
        i_table.add_column("Title")
        for i in issues[:5]:
            p_color = {0: 'red', 1: 'yellow'}.get(i.get('priority', 2), 'white')
            i_table.add_row(i.get('id', '?'), f"[{p_color}]{i.get('title', '?')[:30]}[/]")
        
        minimax = data.get('minimax', {})
        mm_text = f"""[bold]MiniMax vLLM[/]
Status: {'[green]✓[/green]' if minimax.get('status') == 'healthy' else '[red]✗[/red]'}
Tokens/sec: {minimax.get('tokens_per_sec', 0)}
Sessions: {minimax.get('active_sessions', 0)}/{minimax.get('max_parallel', 0)}"""
        
        layout["right"].update(Panel(Columns([i_table, Panel(mm_text)]), border_style="green"))
        
        # Footer
        layout["footer"].update(Panel("[dim]Press Ctrl+C to exit | Commands: gasclaw [status|containers|agents|issues|gateways|metrics][/dim]", 
                                     border_style="dim"))
        
        return layout
    
    try:
        with Live(generate_layout(), refresh_per_second=0.5) as live:
            while True:
                time.sleep(2)
                live.update(generate_layout())
    except KeyboardInterrupt:
        console.print("\n[dim]Exiting...[/dim]")


@cli.command()
def version():
    """Show version info"""
    click.echo("gasclaw-tui 1.0.0")
    click.echo("AI-Optimized Terminal Interface for Gasclaw Management")


if __name__ == '__main__':
    cli()

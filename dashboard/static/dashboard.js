/**
 * Gasclaw Management Dashboard - Frontend
 * Real-time monitoring dashboard for Gasclaw infrastructure
 */

// Configuration
const API_BASE = '';  // Same origin (CloudFront handles routing)
const REFRESH_INTERVAL = 5000;  // 5 seconds

// State
let throughputHistory = [];
let refreshTimer = null;

// Utility functions
const formatNumber = (num) => {
    if (num === null || num === undefined) return '--';
    if (num >= 1000000) return (num / 1000000).toFixed(2) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toLocaleString();
};

const formatDate = (dateString) => {
    if (!dateString) return '--';
    const date = new Date(dateString);
    return date.toLocaleTimeString();
};

const getPriorityLabel = (p) => {
    const labels = ['Critical', 'High', 'Medium', 'Low', 'Backlog'];
    return labels[p] || 'Unknown';
};

const getPriorityClass = (p) => {
    const classes = ['priority-critical', 'priority-high', 'priority-medium', 'priority-low', 'priority-backlog'];
    return classes[p] || 'priority-medium';
};

const getStatusClass = (status) => {
    if (!status) return 'status-unknown';
    status = status.toLowerCase();
    if (['running', 'active', 'healthy', 'live', 'online', 'open'].includes(status)) return 'status-healthy';
    if (['stopped', 'down', 'error', 'offline', 'closed'].includes(status)) return 'status-error';
    if (['waiting', 'idle', 'unknown'].includes(status)) return 'status-warning';
    return 'status-neutral';
};

// API functions
async function fetchAPI(endpoint) {
    try {
        const response = await fetch(`${API_BASE}/api/${endpoint}`);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.json();
    } catch (error) {
        console.error(`API error (${endpoint}):`, error);
        return null;
    }
}

async function fetchOverview() {
    return await fetchAPI('overview');
}

async function fetchMinimax() {
    return await fetchAPI('minimax');
}

// Render functions
function renderOverview(data) {
    if (!data) return;

    // Update timestamp
    document.getElementById('last-updated').textContent = formatDate(data.time);

    // Containers stat
    const containers = data.docker?.containers || [];
    const runningContainers = containers.filter(c => c.state === 'running').length;
    document.getElementById('containers-count').textContent = `${runningContainers}/${containers.length}`;

    // Gateways stat
    const gateways = data.gateways?.gateways || [];
    const healthyGateways = gateways.filter(g => g.healthy).length;
    document.getElementById('gateways-count').textContent = `${healthyGateways}/${gateways.length}`;

    // Agents stat
    const agents = data.agents?.agents || [];
    const activeAgents = agents.filter(a => a.status === 'active').length;
    document.getElementById('agents-count').textContent = `${activeAgents}/${agents.length}`;

    // Issues stat
    const issues = data.beads?.summary || {};
    document.getElementById('issues-count').textContent = issues.open || 0;

    // Render containers table
    renderContainers(containers);

    // Render gateways table
    renderGateways(gateways);

    // Render agents
    renderAgents(agents);

    // Render issues
    renderIssues(data.beads);

    // Render GPU metrics
    renderGPUs(data.metrics?.gpus);
}

function renderContainers(containers) {
    const tbody = document.getElementById('containers-table');
    if (!containers.length) {
        tbody.innerHTML = '<tr><td colspan="4" class="empty">No containers found</td></tr>';
        return;
    }

    tbody.innerHTML = containers.map(c => `
        <tr>
            <td><strong>${c.name}</strong></td>
            <td><span class="badge ${getStatusClass(c.state)}">${c.state}</span></td>
            <td>${c.bot || '-'}</td>
            <td><span class="badge ${c.healthy ? 'status-healthy' : 'status-error'}">${c.healthy ? '✓' : '✗'}</span></td>
        </tr>
    `).join('');
}

function renderGateways(gateways) {
    const tbody = document.getElementById('gateways-table');
    if (!gateways.length) {
        tbody.innerHTML = '<tr><td colspan="3" class="empty">No gateways found</td></tr>';
        return;
    }

    tbody.innerHTML = gateways.map(g => `
        <tr>
            <td>${g.container}</td>
            <td><code>${g.port}</code></td>
            <td><span class="badge ${getStatusClass(g.status)}">${g.status}</span></td>
        </tr>
    `).join('');
}

function renderAgents(agents) {
    const grid = document.getElementById('agents-grid');
    if (!agents.length) {
        grid.innerHTML = '<div class="empty">No agents found</div>';
        return;
    }

    // Group by container
    const byContainer = agents.reduce((acc, a) => {
        if (!acc[a.container]) acc[a.container] = [];
        acc[a.container].push(a);
        return acc;
    }, {});

    grid.innerHTML = Object.entries(byContainer).map(([container, containerAgents]) => `
        <div class="agent-group">
            <h4>${container}</h4>
            <div class="agent-list">
                ${containerAgents.map(a => `
                    <div class="agent-item">
                        <span class="agent-name">${a.name}</span>
                        <span class="agent-status ${getStatusClass(a.status)}">${a.status}</span>
                    </div>
                `).join('')}
            </div>
        </div>
    `).join('');
}

function renderIssues(beads) {
    const summary = beads?.summary || {};
    const issues = beads?.issues || [];

    // Update summary
    const summaryDiv = document.getElementById('issue-summary');
    summaryDiv.innerHTML = `
        <span class="issue-stat critical">${summary.critical || 0} Critical</span>
        <span class="issue-stat high">${summary.high || 0} High</span>
        <span class="issue-stat medium">${summary.medium || 0} Medium</span>
        <span class="issue-stat">${summary.open || 0} Open</span>
    `;

    // Render table
    const tbody = document.getElementById('issues-table');
    const openIssues = issues.filter(i => i.status === 'open').slice(0, 10);

    if (!openIssues.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="empty">No open issues</td></tr>';
        return;
    }

    tbody.innerHTML = openIssues.map(i => `
        <tr>
            <td><code>${i.id}</code></td>
            <td class="issue-title" title="${i.description || ''}">${i.title}</td>
            <td><span class="badge">${i.type}</span></td>
            <td><span class="badge ${getPriorityClass(i.priority)}">${getPriorityLabel(i.priority)}</span></td>
            <td><span class="badge ${getStatusClass(i.status)}">${i.status}</span></td>
            <td>${i.owner || '-'}</td>
        </tr>
    `).join('');
}

function renderGPUs(gpus) {
    const section = document.getElementById('gpu-section');
    const grid = document.getElementById('gpu-grid');

    if (!gpus || !gpus.length) {
        section.style.display = 'none';
        return;
    }

    section.style.display = 'block';
    grid.innerHTML = gpus.map((gpu, i) => `
        <div class="gpu-card">
            <div class="gpu-header">
                <span class="gpu-name">GPU ${i}</span>
                <span class="gpu-temp">${gpu.temperature_c}°C</span>
            </div>
            <div class="gpu-model">${gpu.name}</div>
            <div class="gpu-stats">
                <div class="gpu-stat">
                    <span class="gpu-stat-value">${gpu.utilization_percent}%</span>
                    <span class="gpu-stat-label">Util</span>
                </div>
                <div class="gpu-stat">
                    <span class="gpu-stat-value">${gpu.memory_used}</span>
                    <span class="gpu-stat-label">VRAM</span>
                </div>
            </div>
            <div class="gpu-bar">
                <div class="gpu-bar-fill" style="width: ${gpu.utilization_percent}"></div>
            </div>
        </div>
    `).join('');
}

// MiniMax specific rendering
function renderMinimax(data) {
    if (!data) return;

    // Update status badge
    const statusBadge = document.getElementById('minimax-status');
    statusBadge.textContent = data.status === 'healthy' ? 'Healthy' : 'Error';
    statusBadge.className = `status-badge ${data.status === 'healthy' ? 'status-healthy' : 'status-error'}`;

    // Throughput stats
    document.getElementById('tokens-per-sec').textContent = formatNumber(data.tokens?.per_second);
    document.getElementById('total-tokens').textContent = formatNumber(data.tokens?.total);
    document.getElementById('prompt-tokens').textContent = formatNumber(data.tokens?.prompt_total);
    document.getElementById('gen-tokens').textContent = formatNumber(data.tokens?.generation_total);

    // Update throughput history for chart
    if (data.tokens?.history) {
        throughputHistory = data.tokens.history.map(h => h.value);
    }
    drawThroughputChart();

    // Parallel sessions
    const sessions = data.parallel_sessions || {};
    document.getElementById('sessions-running').textContent = sessions.running || 0;
    document.getElementById('sessions-waiting').textContent = sessions.waiting || 0;
    document.getElementById('sessions-total').textContent = sessions.total || 0;

    // Engine list
    const engineList = document.getElementById('engine-list');
    if (sessions.per_engine) {
        engineList.innerHTML = sessions.per_engine.map(e => `
            <div class="engine-item">
                <span class="engine-name">Engine ${e.engine}</span>
                <span class="engine-count">${e.count} running</span>
            </div>
        `).join('');
    }

    // KV Cache
    const kvCacheList = document.getElementById('kv-cache-list');
    if (data.kv_cache) {
        kvCacheList.innerHTML = data.kv_cache.map(kv => `
            <div class="kv-item">
                <span class="kv-engine">Engine ${kv.engine}</span>
                <div class="kv-bar-container">
                    <div class="kv-bar" style="width: ${kv.usage_percent}%"></div>
                    <span class="kv-value">${kv.usage_percent}%</span>
                </div>
            </div>
        `).join('');
    }

    // Engine states
    const engineStates = document.getElementById('engine-states');
    if (data.engine_states) {
        const states = data.engine_states.reduce((acc, es) => {
            if (!acc[es.engine]) acc[es.engine] = {};
            acc[es.engine][es.state] = es.value;
            return acc;
        }, {});

        engineStates.innerHTML = Object.entries(states).map(([engine, state]) => {
            const isAwake = state.awake === 1;
            const hasWeights = state.weights_offloaded === 1;
            return `
                <div class="engine-state-item">
                    <span class="state-engine">Engine ${engine}</span>
                    <span class="state-badge ${isAwake ? 'awake' : 'asleep'}">${isAwake ? 'Awake' : 'Sleeping'}</span>
                    ${hasWeights ? '<span class="state-badge weights-offloaded">Weights Offloaded</span>' : ''}
                </div>
            `;
        }).join('');
    }
}

// Canvas chart for throughput
function drawThroughputChart() {
    const canvas = document.getElementById('throughput-chart');
    if (!canvas || throughputHistory.length < 2) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Calculate scale
    const maxVal = Math.max(...throughputHistory, 1);
    const minVal = Math.min(...throughputHistory, 0);
    const range = maxVal - minVal || 1;

    // Draw grid lines
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.1)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = height - (i * height / 4);
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
    }

    // Draw line
    ctx.strokeStyle = '#3b82f6';
    ctx.lineWidth = 2;
    ctx.beginPath();

    throughputHistory.forEach((val, i) => {
        const x = (i / (throughputHistory.length - 1)) * width;
        const y = height - ((val - minVal) / range) * height * 0.8 - height * 0.1;

        if (i === 0) {
            ctx.moveTo(x, y);
        } else {
            ctx.lineTo(x, y);
        }
    });

    ctx.stroke();

    // Fill area under line
    ctx.fillStyle = 'rgba(59, 130, 246, 0.1)';
    ctx.lineTo(width, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    ctx.fill();
}

// Refresh functions
async function refreshAll() {
    console.log('Refreshing dashboard...');

    const [overview, minimax] = await Promise.all([
        fetchOverview(),
        fetchMinimax()
    ]);

    if (overview) renderOverview(overview);
    if (minimax) renderMinimax(minimax);
}

function startAutoRefresh() {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(refreshAll, REFRESH_INTERVAL);
}

function stopAutoRefresh() {
    if (refreshTimer) {
        clearInterval(refreshTimer);
        refreshTimer = null;
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Gasclaw Dashboard initialized');

    // Initial load
    refreshAll();

    // Start auto-refresh
    startAutoRefresh();

    // Handle visibility change (pause refresh when tab hidden)
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
            stopAutoRefresh();
        } else {
            refreshAll();
            startAutoRefresh();
        }
    });
});

// Export for global access
window.refreshAll = refreshAll;

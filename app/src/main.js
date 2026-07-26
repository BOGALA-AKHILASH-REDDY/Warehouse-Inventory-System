import Chart from 'chart.js/auto';
import { createIcons, icons } from 'lucide';
import { initMockDatabase, dbState, getDashboardMetrics, getABCAnalysis } from './sqlEngine.js';
import { SQL_PRESETS, SCHEMA_DICTIONARY } from './schemaData.js';

let activeCharts = {};

document.addEventListener('DOMContentLoaded', () => {
  createIcons({ icons });
  initMockDatabase();
  renderOverviewMetrics();
  setupTabs();
  setupInventoryTab();
  setupExpiryTab();
  setupABCTab();
  setupSupplierTab();
  setupSQLSandboxTab();
  setupSchemaTab();
});

// Render Top KPI Cards
function renderOverviewMetrics() {
  const metrics = getDashboardMetrics();
  document.getElementById('val-total-valuation').textContent = metrics.totalValuation;
  document.getElementById('val-total-skus').textContent = metrics.totalSkus;
  document.getElementById('val-reorder-count').textContent = metrics.reorderCount;
  document.getElementById('val-expiry-count').textContent = metrics.expiryCount;
}

// Setup Main Tab Navigation
function setupTabs() {
  const tabLinks = document.querySelectorAll('.tab-link');
  tabLinks.forEach(link => {
    link.addEventListener('click', () => {
      tabLinks.forEach(l => l.classList.remove('active'));
      link.classList.add('active');

      const targetTab = link.dataset.tab;
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      document.getElementById(`tab-${targetTab}`).classList.add('active');
    });
  });
}

// Tab 1: Live Inventory
function setupInventoryTab() {
  const selectWh = document.getElementById('select-warehouse');
  const inputSearch = document.getElementById('input-search-sku');

  const render = () => {
    const whFilter = selectWh.value;
    const searchQuery = inputSearch.value.toLowerCase().trim();

    const filtered = dbState.inventory.filter(item => {
      const matchWh = (whFilter === 'ALL' || item.warehouseId === parseInt(whFilter, 10));
      const matchSearch = (!searchQuery || item.sku.toLowerCase().includes(searchQuery) || item.name.toLowerCase().includes(searchQuery));
      return matchWh && matchSearch;
    });

    const tbody = document.getElementById('tbody-inventory');
    tbody.innerHTML = filtered.slice(0, 100).map(item => `
      <tr>
        <td><strong>${item.sku}</strong></td>
        <td>${item.name}</td>
        <td>${item.category}</td>
        <td>${item.warehouseName}</td>
        <td>${item.onHand}</td>
        <td>${item.available}</td>
        <td>${item.min} / ${item.max}</td>
        <td><code>${item.location}</code></td>
        <td><span class="badge ${getStatusBadgeClass(item.status)}">${item.status}</span></td>
      </tr>
    `).join('');
  };

  selectWh.addEventListener('change', render);
  inputSearch.addEventListener('input', render);
  render();
}

function getStatusBadgeClass(status) {
  switch (status) {
    case 'OUT_OF_STOCK': return 'badge-danger';
    case 'CRITICAL_LOW': return 'badge-danger';
    case 'REORDER_NEEDED': return 'badge-warning';
    case 'OVERSTOCKED': return 'badge-info';
    default: return 'badge-success';
  }
}

// Tab 2: Product Expiry Tracker
function setupExpiryTab() {
  const tbody = document.getElementById('tbody-expiry');
  tbody.innerHTML = dbState.expiryBatches.map(b => `
    <tr>
      <td><code>${b.batchNumber}</code></td>
      <td><strong>${b.sku}</strong></td>
      <td>${b.name}</td>
      <td>${b.warehouseName}</td>
      <td>${b.quantity}</td>
      <td>${b.expiryDate}</td>
      <td><strong>${b.daysRemaining} days</strong></td>
      <td><span class="badge ${b.daysRemaining <= 7 ? 'badge-danger' : b.daysRemaining <= 15 ? 'badge-warning' : 'badge-info'}">${b.urgency}</span></td>
    </tr>
  `).join('');

  // Expiry Risk Chart
  const ctx = document.getElementById('expiryChart').getContext('2d');
  const counts = { '7 Days': 0, '15 Days': 0, '30 Days': 0, 'Safe (>30d)': 0 };
  dbState.expiryBatches.forEach(b => {
    if (b.daysRemaining <= 7) counts['7 Days']++;
    else if (b.daysRemaining <= 15) counts['15 Days']++;
    else if (b.daysRemaining <= 30) counts['30 Days']++;
    else counts['Safe (>30d)']++;
  });

  activeCharts.expiry = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: Object.keys(counts),
      datasets: [{
        data: Object.values(counts),
        backgroundColor: ['#ff0055', '#ffb703', '#00f2fe', '#10b981']
      }]
    },
    options: { responsive: true, maintainAspectRatio: false }
  });
}

// Tab 3: ABC Analysis
function setupABCTab() {
  const data = getABCAnalysis();
  const tbody = document.getElementById('tbody-abc');
  tbody.innerHTML = data.map(item => `
    <tr>
      <td><strong>${item.sku}</strong></td>
      <td>${item.name}</td>
      <td>${item.revenue}</td>
      <td>${item.cumPct}</td>
      <td><span class="badge ${item.paretoClass === 'Class A' ? 'badge-success' : item.paretoClass === 'Class B' ? 'badge-info' : 'badge-warning'}">${item.paretoClass}</span></td>
    </tr>
  `).join('');

  // ABC Chart
  const ctx = document.getElementById('abcChart').getContext('2d');
  activeCharts.abc = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.slice(0, 10).map(d => d.sku),
      datasets: [{
        label: 'Revenue ($)',
        data: data.slice(0, 10).map(d => parseFloat(d.revenue.replace(/[^0-9.-]+/g, ''))),
        backgroundColor: 'rgba(0, 242, 254, 0.6)'
      }]
    },
    options: { responsive: true, maintainAspectRatio: false }
  });
}

// Tab 4: Supplier Performance
function setupSupplierTab() {
  const tbody = document.getElementById('tbody-suppliers');
  tbody.innerHTML = dbState.suppliers.map((s, idx) => `
    <tr>
      <td><strong>#${idx + 1}</strong></td>
      <td>${s.name}</td>
      <td>⭐ ${s.rating}</td>
      <td>${s.orders}</td>
      <td><span class="badge badge-success">${s.on_time}%</span></td>
      <td>${s.lead_time} days</td>
      <td>${s.spend.toLocaleString('en-US', { style: 'currency', currency: 'USD' })}</td>
    </tr>
  `).join('');
}

// Tab 5: SQL Sandbox
function setupSQLSandboxTab() {
  const editor = document.getElementById('sql-editor');
  editor.value = SQL_PRESETS.abc;

  document.querySelectorAll('.preset-sql').forEach(btn => {
    btn.addEventListener('click', () => {
      const presetKey = btn.dataset.sql;
      editor.value = SQL_PRESETS[presetKey] || '';
    });
  });

  document.getElementById('btn-run-sql').addEventListener('click', runSandboxQuery);
  document.getElementById('btn-copy-query').addEventListener('click', () => {
    navigator.clipboard.writeText(editor.value);
    alert('SQL Query copied to clipboard!');
  });

  runSandboxQuery();
}

function runSandboxQuery() {
  const thead = document.getElementById('thead-sql-results');
  const tbody = document.getElementById('tbody-sql-results');
  const rowCount = document.getElementById('sql-row-count');

  const data = getABCAnalysis().slice(0, 8);
  rowCount.textContent = data.length;

  thead.innerHTML = `
    <tr>
      <th>SKU</th>
      <th>Product Name</th>
      <th>Total Revenue</th>
      <th>Cumulative %</th>
      <th>Pareto Class</th>
    </tr>
  `;

  tbody.innerHTML = data.map(r => `
    <tr>
      <td><strong>${r.sku}</strong></td>
      <td>${r.name}</td>
      <td>${r.revenue}</td>
      <td>${r.cumPct}</td>
      <td><span class="badge badge-success">${r.paretoClass}</span></td>
    </tr>
  `).join('');
}

// Tab 6: Schema Dictionary
function setupSchemaTab() {
  const container = document.getElementById('schema-dictionary-container');
  container.innerHTML = SCHEMA_DICTIONARY.map(table => `
    <div class="schema-table-card">
      <div class="schema-table-title">TABLE: ${table.table.toUpperCase()}</div>
      <p class="panel-subtitle" style="margin-bottom: 0.5rem;">${table.description}</p>
      <table class="data-table">
        <thead>
          <tr>
            <th>Column Name</th>
            <th>Data Type</th>
            <th>Constraints / Foreign Keys</th>
          </tr>
        </thead>
        <tbody>
          ${table.columns.map(c => `
            <tr>
              <td><code>${c.name}</code></td>
              <td>${c.type}</td>
              <td><code>${c.constraint}</code></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `).join('');
}

// In-Memory Database Simulator for NexSupply WMS Interactive Dashboard

export const dbState = {
  warehouses: [
    { id: 1, name: 'Chicago Central Superhub', code: 'ORD-WH01', capacity: 250000, pallets: 10000, utilization: 78.5 },
    { id: 2, name: 'Dallas Logistics Depot', code: 'DFW-WH02', capacity: 180000, pallets: 7500, utilization: 64.2 },
    { id: 3, name: 'Atlanta Distribution Center', code: 'ATL-WH03', capacity: 200000, pallets: 8500, utilization: 82.1 },
    { id: 4, name: 'Seattle Port Fulfillment', code: 'SEA-WH04', capacity: 150000, pallets: 6000, utilization: 59.8 },
    { id: 5, name: 'New Jersey Metro Regional', code: 'EWR-WH05', capacity: 220000, pallets: 9000, utilization: 71.4 }
  ],

  categories: [
    'Electronics & IT', 'Computers & Laptops', 'Mobile & Accessories',
    'Industrial & Tools', 'Power Tools', 'Pharmaceuticals & Medical',
    'Perishable Foods', 'Apparel & Footwear', 'Automotive Parts', 'Office Supplies'
  ],

  suppliers: [
    { id: 1, name: 'Apex Electronics Corp', rating: 4.85, lead_time: 5, orders: 42, on_time: 97.5, spend: 485000 },
    { id: 2, name: 'Global Micro Components', rating: 4.60, lead_time: 7, orders: 35, on_time: 91.4, spend: 320000 },
    { id: 3, name: 'Titan Industrial Hardware', rating: 4.90, lead_time: 4, orders: 58, on_time: 98.2, spend: 610000 },
    { id: 4, name: 'PharmaHealth Global Inc', rating: 4.95, lead_time: 3, orders: 64, on_time: 99.1, spend: 890000 },
    { id: 5, name: 'FreshGrid Foods Logistics', rating: 4.40, lead_time: 2, orders: 50, on_time: 88.0, spend: 410000 }
  ],

  inventory: [],
  expiryBatches: []
};

// Seed 100 Products across 5 Warehouses
export function initMockDatabase() {
  const inventoryList = [];
  const expiryList = [];

  const today = new Date();

  for (let p = 1; p <= 100; p++) {
    const category = dbState.categories[(p - 1) % 10];
    const cost = parseFloat((15 + p * 8.50).toFixed(2));
    const price = parseFloat((cost * 1.45).toFixed(2));
    const sku = `SKU-PRD-${String(p).padStart(4, '0')}`;
    const name = `Enterprise Product Grade-${p} (${category})`;

    for (let w = 1; w <= 5; w++) {
      const warehouse = dbState.warehouses[w - 1];
      const qty = (p % 7 === 0) ? 5 : (p % 11 === 0) ? 0 : (p % 5 === 0) ? 350 : 80 + ((p * w) % 120);
      const allocated = Math.min(qty, p % 15);
      
      let status = 'OPTIMAL';
      if (qty === 0) status = 'OUT_OF_STOCK';
      else if (qty <= 15) status = 'CRITICAL_LOW';
      else if (qty <= 30) status = 'REORDER_NEEDED';
      else if (qty > 300) status = 'OVERSTOCKED';

      inventoryList.push({
        sku,
        name,
        category,
        warehouseId: w,
        warehouseName: warehouse.name,
        cost,
        price,
        onHand: qty,
        allocated,
        available: qty - allocated,
        min: 15,
        max: 300,
        reorderPoint: 30,
        location: `Aisle-${String((p % 12) + 1).padStart(2, '0')} / Bin-${String.fromCharCode(65 + (p % 6))}-${(p % 20) + 1}`,
        status
      });
    }

    // Perishable Expiry Batches for Category 6 & 7
    if (p % 10 === 6 || p % 10 === 7) {
      const daysLeft = (p % 4 === 0) ? 4 : (p % 4 === 1) ? 12 : (p % 4 === 2) ? 25 : 120;
      const expDate = new Date(today.getTime() + daysLeft * 86400000).toISOString().split('T')[0];

      expiryList.push({
        batchNumber: `LOT-2026-${String(p).padStart(3, '0')}`,
        sku,
        name,
        warehouseName: dbState.warehouses[p % 5].name,
        quantity: 50 + (p % 30),
        expiryDate: expDate,
        daysRemaining: daysLeft,
        urgency: daysLeft <= 7 ? 'EXPIRING_7_DAYS' : daysLeft <= 15 ? 'EXPIRING_15_DAYS' : daysLeft <= 30 ? 'EXPIRING_30_DAYS' : 'SAFE'
      });
    }
  }

  dbState.inventory = inventoryList;
  dbState.expiryBatches = expiryList;
}

// Compute Metrics
export function getDashboardMetrics() {
  let totalValuation = 0;
  let reorderCount = 0;
  let expiryCount = 0;

  dbState.inventory.forEach(item => {
    totalValuation += item.onHand * item.cost;
    if (item.onHand <= item.reorderPoint) reorderCount++;
  });

  dbState.expiryBatches.forEach(b => {
    if (b.daysRemaining <= 15) expiryCount++;
  });

  return {
    totalValuation: totalValuation.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
    totalSkus: 100,
    reorderCount,
    expiryCount
  };
}

// ABC Pareto Analysis Generator
export function getABCAnalysis() {
  const sorted = [...dbState.inventory].sort((a, b) => (b.onHand * b.price) - (a.onHand * a.price));
  let grandTotal = sorted.reduce((acc, i) => acc + (i.onHand * i.price), 0);
  let running = 0;

  return sorted.slice(0, 30).map(item => {
    const rev = item.onHand * item.price;
    running += rev;
    const cumPct = ((running / grandTotal) * 100).toFixed(2);
    let classType = 'Class A';
    if (cumPct > 70 && cumPct <= 90) classType = 'Class B';
    else if (cumPct > 90) classType = 'Class C';

    return {
      sku: item.sku,
      name: item.name,
      revenue: rev.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
      cumPct: `${cumPct}%`,
      paretoClass: classType
    };
  });
}

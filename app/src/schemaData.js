export const SQL_PRESETS = {
  abc: `-- ABC Inventory Pareto Analysis (Top 70% Revenue = Class A)
WITH ProductRevenue AS (
    SELECT 
        p.product_id,
        p.sku,
        p.product_name,
        COALESCE(SUM(soi.line_total), 0) AS total_revenue
    FROM products p
    LEFT JOIN sales_order_items soi ON p.product_id = soi.product_id
    GROUP BY p.product_id, p.sku, p.product_name
),
Cumulative AS (
    SELECT 
        product_id,
        sku,
        product_name,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS running_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM ProductRevenue
)
SELECT 
    sku,
    product_name,
    total_revenue,
    ROUND((running_revenue / NULLIF(grand_total, 0)) * 100, 2) AS cumulative_pct,
    CASE 
        WHEN (running_revenue / NULLIF(grand_total, 0)) * 100 <= 70 THEN 'Class A'
        WHEN (running_revenue / NULLIF(grand_total, 0)) * 100 <= 90 THEN 'Class B'
        ELSE 'Class C'
    END AS pareto_class
FROM Cumulative
ORDER BY total_revenue DESC;`,

  expiry: `-- Products Expiring Within 15 Days
SELECT 
    pe.batch_number,
    w.warehouse_name,
    p.sku,
    p.product_name,
    pe.quantity,
    pe.expiry_date,
    (pe.expiry_date - CURRENT_DATE) AS days_remaining,
    pe.status
FROM product_expiry pe
JOIN products p ON pe.product_id = p.product_id
JOIN warehouses w ON pe.warehouse_id = w.warehouse_id
WHERE pe.expiry_date <= CURRENT_DATE + INTERVAL '15 days'
ORDER BY pe.expiry_date ASC;`,

  reorder: `-- Automatic Reorder Alerts (Stock <= Reorder Point)
SELECT 
    ra.alert_id,
    w.warehouse_name,
    p.sku,
    p.product_name,
    s.supplier_name,
    ra.current_stock,
    ra.min_stock_level,
    ra.recommended_reorder_qty,
    ra.alert_status
FROM reorder_alerts ra
JOIN products p ON ra.product_id = p.product_id
JOIN warehouses w ON ra.warehouse_id = w.warehouse_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE ra.alert_status IN ('PENDING', 'PO_CREATED')
ORDER BY ra.current_stock ASC;`,

  deadstock: `-- Dead Stock Detection (>180 Days No Sales)
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    SUM(i.quantity_on_hand) AS stock_on_hand,
    MAX(so.order_date) AS last_sale_date,
    COALESCE(CURRENT_DATE - MAX(so.order_date), 999) AS days_since_last_sale
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN sales_order_items soi ON p.product_id = soi.product_id
LEFT JOIN sales_orders so ON soi.so_id = so.so_id
GROUP BY p.product_id, p.sku, p.product_name, c.category_name
HAVING MAX(so.order_date) IS NULL OR MAX(so.order_date) < CURRENT_DATE - INTERVAL '180 days'
ORDER BY days_since_last_sale DESC;`
};

export const SCHEMA_DICTIONARY = [
  {
    table: 'categories',
    description: 'Product categories hierarchy with parent-child tree relationship',
    columns: [
      { name: 'category_id', type: 'INT (PK)', constraint: 'SERIAL PRIMARY KEY' },
      { name: 'category_name', type: 'VARCHAR(100)', constraint: 'UNIQUE NOT NULL' },
      { name: 'parent_category_id', type: 'INT (FK)', constraint: 'REFERENCES categories(category_id)' }
    ]
  },
  {
    table: 'suppliers',
    description: 'Vendor master data with lead time ratings and on-time scores',
    columns: [
      { name: 'supplier_id', type: 'INT (PK)', constraint: 'SERIAL PRIMARY KEY' },
      { name: 'supplier_name', type: 'VARCHAR(150)', constraint: 'UNIQUE NOT NULL' },
      { name: 'rating', type: 'DECIMAL(3,2)', constraint: 'CHECK (rating BETWEEN 0 AND 5)' },
      { name: 'avg_lead_time_days', type: 'INT', constraint: 'DEFAULT 7' }
    ]
  },
  {
    table: 'products',
    description: 'Product master catalog (SKU, barcode, min/max thresholds, cost, price)',
    columns: [
      { name: 'product_id', type: 'INT (PK)', constraint: 'SERIAL PRIMARY KEY' },
      { name: 'sku', type: 'VARCHAR(50)', constraint: 'UNIQUE NOT NULL' },
      { name: 'unit_cost', type: 'DECIMAL(10,2)', constraint: 'CHECK (unit_cost >= 0)' },
      { name: 'unit_price', type: 'DECIMAL(10,2)', constraint: 'CHECK (unit_price >= unit_cost)' },
      { name: 'reorder_point', type: 'INT', constraint: 'NOT NULL DEFAULT 20' }
    ]
  },
  {
    table: 'inventory',
    description: 'Warehouse-specific stock balances, aisle/bin allocations',
    columns: [
      { name: 'inventory_id', type: 'INT (PK)', constraint: 'SERIAL PRIMARY KEY' },
      { name: 'warehouse_id', type: 'INT (FK)', constraint: 'REFERENCES warehouses(warehouse_id)' },
      { name: 'product_id', type: 'INT (FK)', constraint: 'REFERENCES products(product_id)' },
      { name: 'quantity_on_hand', type: 'INT', constraint: 'CHECK (quantity_on_hand >= 0)' }
    ]
  },
  {
    table: 'stock_transactions',
    description: 'Audit log of Stock In, Stock Out, Transfer, Return, Damaged',
    columns: [
      { name: 'transaction_id', type: 'INT (PK)', constraint: 'SERIAL PRIMARY KEY' },
      { name: 'transaction_type', type: 'VARCHAR(20)', constraint: 'CHECK IN (STOCK_IN, STOCK_OUT, TRANSFER, ...)' },
      { name: 'quantity', type: 'INT', constraint: 'CHECK (quantity > 0)' }
    ]
  }
];

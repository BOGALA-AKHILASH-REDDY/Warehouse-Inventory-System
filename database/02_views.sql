-- =============================================================================
-- NEXSUPPLY WMS - BUSINESS VIEWS & MATERIALIZED VIEWS
-- =============================================================================

-- 1. VIEW: Current Inventory Status & Stock Health Indicator
CREATE OR REPLACE VIEW v_current_inventory AS
SELECT 
    w.warehouse_name,
    w.location_code,
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    i.quantity_on_hand,
    i.quantity_allocated,
    (i.quantity_on_hand - i.quantity_allocated) AS quantity_available,
    p.min_stock_level,
    p.max_stock_level,
    p.reorder_point,
    CASE 
        WHEN i.quantity_on_hand = 0 THEN 'OUT_OF_STOCK'
        WHEN i.quantity_on_hand <= p.min_stock_level THEN 'CRITICAL_LOW'
        WHEN i.quantity_on_hand <= p.reorder_point THEN 'REORDER_NEEDED'
        WHEN i.quantity_on_hand > p.max_stock_level THEN 'OVERSTOCKED'
        ELSE 'OPTIMAL'
    END AS stock_status,
    i.aisle_location,
    i.bin_location,
    i.last_updated
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id;


-- 2. VIEW: Inventory Asset Valuation (Cost vs. Potential Retail Value)
CREATE OR REPLACE VIEW v_inventory_valuation AS
SELECT 
    w.warehouse_name,
    c.category_name,
    COUNT(DISTINCT i.product_id) AS total_skus,
    SUM(i.quantity_on_hand) AS total_units,
    SUM(i.quantity_on_hand * p.unit_cost) AS total_cost_value,
    SUM(i.quantity_on_hand * p.unit_price) AS total_retail_value,
    SUM(i.quantity_on_hand * (p.unit_price - p.unit_cost)) AS potential_gross_profit
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
JOIN products p ON i.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY w.warehouse_name, c.category_name;


-- 3. VIEW: Supplier Performance & Delivery Reliability Analytics
CREATE OR REPLACE VIEW v_supplier_performance AS
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.rating,
    COUNT(po.po_id) AS total_purchase_orders,
    COUNT(CASE WHEN po.status = 'RECEIVED' THEN 1 END) AS fulfilled_orders,
    COUNT(CASE WHEN po.delivery_date > po.expected_date THEN 1 END) AS late_deliveries,
    ROUND(
        (COUNT(CASE WHEN po.status = 'RECEIVED' AND (po.delivery_date IS NULL OR po.delivery_date <= po.expected_date) THEN 1 END)::DECIMAL / 
        NULLIF(COUNT(CASE WHEN po.status = 'RECEIVED' THEN 1 END), 0)) * 100, 2
    ) AS on_time_delivery_pct,
    ROUND(AVG(COALESCE(po.delivery_date - po.order_date, s.avg_lead_time_days)), 1) AS actual_avg_lead_time_days,
    SUM(po.total_cost) AS total_spend
FROM suppliers s
LEFT JOIN purchase_orders po ON s.supplier_id = po.supplier_id
GROUP BY s.supplier_id, s.supplier_name, s.rating;


-- 4. VIEW: Warehouse Utilization & Capacity Overview
CREATE OR REPLACE VIEW v_warehouse_utilization AS
SELECT 
    w.warehouse_id,
    w.warehouse_name,
    w.city,
    w.capacity_sqft,
    w.max_pallet_capacity,
    COUNT(DISTINCT i.product_id) AS active_skus,
    SUM(i.quantity_on_hand) AS total_items_stored,
    COALESCE(SUM(i.quantity_on_hand * p.unit_cost), 0) AS total_inventory_cost_value,
    ROUND((SUM(i.quantity_on_hand)::DECIMAL / w.max_pallet_capacity) * 100, 2) AS calculated_utilization_pct
FROM warehouses w
LEFT JOIN inventory i ON w.warehouse_id = i.warehouse_id
LEFT JOIN products p ON i.product_id = p.product_id
GROUP BY w.warehouse_id, w.warehouse_name, w.city, w.capacity_sqft, w.max_pallet_capacity;


-- 5. VIEW: Product Expiry Risk Summary (Categorized by Urgency)
CREATE OR REPLACE VIEW v_expiry_risk_summary AS
SELECT 
    pe.expiry_id,
    w.warehouse_name,
    p.sku,
    p.product_name,
    pe.batch_number,
    pe.quantity,
    pe.expiry_date,
    (pe.expiry_date - CURRENT_DATE) AS days_remaining,
    CASE 
        WHEN pe.expiry_date <= CURRENT_DATE THEN 'EXPIRED'
        WHEN pe.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'EXPIRING_7_DAYS'
        WHEN pe.expiry_date <= CURRENT_DATE + INTERVAL '15 days' THEN 'EXPIRING_15_DAYS'
        WHEN pe.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_30_DAYS'
        ELSE 'SAFE'
    END AS expiry_urgency
FROM product_expiry pe
JOIN products p ON pe.product_id = p.product_id
JOIN warehouses w ON pe.warehouse_id = w.warehouse_id
WHERE pe.status != 'DISPOSED' AND pe.expiry_date <= CURRENT_DATE + INTERVAL '30 days';


-- 6. VIEW: Pending Reorder Alerts Summary
CREATE OR REPLACE VIEW v_reorder_summary AS
SELECT 
    ra.alert_id,
    w.warehouse_name,
    p.sku,
    p.product_name,
    s.supplier_name,
    ra.current_stock,
    ra.min_stock_level,
    ra.recommended_reorder_qty,
    (ra.recommended_reorder_qty * p.unit_cost) AS estimated_po_cost,
    ra.alert_status,
    ra.created_at
FROM reorder_alerts ra
JOIN products p ON ra.product_id = p.product_id
JOIN warehouses w ON ra.warehouse_id = w.warehouse_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE ra.alert_status IN ('PENDING', 'PO_CREATED');


-- 7. MATERIALIZED VIEW: Monthly Sales & Profit Analytics
CREATE MATERIALIZED VIEW mv_monthly_sales_analytics AS
SELECT 
    DATE_TRUNC('month', so.order_date)::DATE AS sales_month,
    w.warehouse_name,
    c.category_name,
    COUNT(DISTINCT so.so_id) AS total_orders,
    SUM(soi.quantity) AS total_units_sold,
    SUM(soi.line_total) AS total_revenue,
    SUM(soi.quantity * p.unit_cost) AS total_cogs,
    SUM(soi.line_total - (soi.quantity * p.unit_cost)) AS gross_profit,
    ROUND(
        (SUM(soi.line_total - (soi.quantity * p.unit_cost)) / NULLIF(SUM(soi.line_total), 0)) * 100, 2
    ) AS gross_profit_margin_pct
FROM sales_orders so
JOIN sales_order_items soi ON so.so_id = soi.so_id
JOIN products p ON soi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN warehouses w ON so.warehouse_id = w.warehouse_id
WHERE so.status IN ('SHIPPED', 'DELIVERED')
GROUP BY DATE_TRUNC('month', so.order_date), w.warehouse_name, c.category_name;

-- Unique Index on Materialized View to support CONCURRENTLY refreshes
CREATE UNIQUE INDEX idx_mv_monthly_sales ON mv_monthly_sales_analytics(sales_month, warehouse_name, category_name);

# SQL Interview Questions & Business Solutions - NexSupply WMS

This document contains 15 real-world database interview questions commonly asked by top-tier tech and enterprise companies (Amazon, Walmart, Flipkart, FedEx).

---

### Q1: Which products are about to expire within 15 days, and in which warehouse are they stored?

```sql
SELECT 
    pe.expiry_id,
    w.warehouse_name,
    p.sku,
    p.product_name,
    pe.batch_number,
    pe.quantity,
    pe.expiry_date,
    (pe.expiry_date - CURRENT_DATE) AS days_remaining
FROM product_expiry pe
JOIN products p ON pe.product_id = p.product_id
JOIN warehouses w ON pe.warehouse_id = w.warehouse_id
WHERE pe.status != 'DISPOSED' 
  AND pe.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '15 days'
ORDER BY pe.expiry_date ASC;
```

---

### Q2: Which supplier has the highest on-time delivery percentage and fastest lead time?

```sql
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.rating,
    COUNT(po.po_id) AS total_orders,
    ROUND(
        (COUNT(CASE WHEN po.status = 'RECEIVED' AND (po.delivery_date IS NULL OR po.delivery_date <= po.expected_date) THEN 1 END)::DECIMAL / 
        NULLIF(COUNT(CASE WHEN po.status = 'RECEIVED' THEN 1 END), 0)) * 100, 2
    ) AS on_time_delivery_pct,
    ROUND(AVG(po.delivery_date - po.order_date), 1) AS avg_actual_lead_time_days
FROM suppliers s
JOIN purchase_orders po ON s.supplier_id = po.supplier_id
WHERE po.status = 'RECEIVED'
GROUP BY s.supplier_id, s.supplier_name, s.rating
HAVING COUNT(po.po_id) >= 3
ORDER BY on_time_delivery_pct DESC, avg_actual_lead_time_days ASC;
```

---

### Q3: Which warehouse holds the highest inventory value, and what is its capacity utilization percentage?

```sql
SELECT 
    w.warehouse_id,
    w.warehouse_name,
    w.capacity_sqft,
    w.max_pallet_capacity,
    SUM(i.quantity_on_hand) AS total_units_stored,
    SUM(i.quantity_on_hand * p.unit_cost) AS total_inventory_cost_value,
    ROUND((SUM(i.quantity_on_hand)::DECIMAL / w.max_pallet_capacity) * 100, 2) AS capacity_utilization_pct,
    DENSE_RANK() OVER (ORDER BY SUM(i.quantity_on_hand * p.unit_cost) DESC) AS valuation_rank
FROM warehouses w
JOIN inventory i ON w.warehouse_id = i.warehouse_id
JOIN products p ON i.product_id = p.product_id
GROUP BY w.warehouse_id, w.warehouse_name, w.capacity_sqft, w.max_pallet_capacity
ORDER BY total_inventory_cost_value DESC;
```

---

### Q4: Which products currently require immediate reordering across all warehouses?

```sql
SELECT 
    w.warehouse_name,
    p.sku,
    p.product_name,
    s.supplier_name,
    i.quantity_on_hand,
    p.min_stock_level,
    p.reorder_point,
    p.max_stock_level,
    (p.max_stock_level - i.quantity_on_hand) AS suggested_order_qty
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE i.quantity_on_hand <= p.reorder_point
ORDER BY (p.reorder_point - i.quantity_on_hand) DESC;
```

---

### Q5: Which products have not had a single sale in the last 180 days (Dead Stock)?

```sql
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    SUM(i.quantity_on_hand) AS total_stock,
    SUM(i.quantity_on_hand * p.unit_cost) AS total_capital_trapped,
    MAX(so.order_date) AS last_sale_date
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN sales_order_items soi ON p.product_id = soi.product_id
LEFT JOIN sales_orders so ON soi.so_id = so.so_id
GROUP BY p.product_id, p.sku, p.product_name, c.category_name
HAVING MAX(so.order_date) IS NULL OR MAX(so.order_date) < CURRENT_DATE - INTERVAL '180 days'
ORDER BY total_capital_trapped DESC;
```

---

### Q6: Calculate the annual Inventory Turnover Ratio for every product.

```sql
WITH COGS_Data AS (
    SELECT 
        soi.product_id,
        SUM(soi.quantity * p.unit_cost) AS total_cogs
    FROM sales_order_items soi
    JOIN sales_orders so ON soi.so_id = so.so_id
    JOIN products p ON soi.product_id = p.product_id
    WHERE so.order_date >= CURRENT_DATE - INTERVAL '1 year'
      AND so.status IN ('SHIPPED', 'DELIVERED')
    GROUP BY soi.product_id
),
AvgInv_Data AS (
    SELECT 
        product_id,
        AVG(quantity_on_hand) AS avg_qty
    FROM inventory
    GROUP BY product_id
)
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    COALESCE(c.total_cogs, 0) AS annual_cogs,
    ROUND(a.avg_qty * p.unit_cost, 2) AS avg_inventory_value,
    ROUND(COALESCE(c.total_cogs, 0) / NULLIF(a.avg_qty * p.unit_cost, 0), 2) AS turnover_ratio
FROM products p
LEFT JOIN COGS_Data c ON p.product_id = c.product_id
LEFT JOIN AvgInv_Data a ON p.product_id = a.product_id
ORDER BY turnover_ratio DESC NULLS LAST;
```

---

### Q7: Who are the Top 10 Customers by total revenue generated?

```sql
SELECT 
    c.customer_id,
    c.customer_name,
    c.company_name,
    c.city,
    COUNT(DISTINCT so.so_id) AS total_orders,
    SUM(so.total_amount) AS total_spent,
    DENSE_RANK() OVER (ORDER BY SUM(so.total_amount) DESC) AS customer_rank
FROM customers c
JOIN sales_orders so ON c.customer_id = so.customer_id
WHERE so.status IN ('SHIPPED', 'DELIVERED')
GROUP BY c.customer_id, c.customer_name, c.company_name, c.city
ORDER BY total_spent DESC
LIMIT 10;
```

---

### Q8: Perform an ABC Inventory Classification (Pareto Analysis).

```sql
WITH ProductRev AS (
    SELECT 
        p.product_id,
        p.sku,
        p.product_name,
        SUM(soi.line_total) AS revenue
    FROM products p
    JOIN sales_order_items soi ON p.product_id = soi.product_id
    JOIN sales_orders so ON soi.so_id = so.so_id
    WHERE so.status IN ('SHIPPED', 'DELIVERED')
    GROUP BY p.product_id, p.sku, p.product_name
),
Cumulative AS (
    SELECT 
        product_id,
        sku,
        product_name,
        revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS running_rev,
        SUM(revenue) OVER () AS grand_total
    FROM ProductRev
)
SELECT 
    product_id,
    sku,
    product_name,
    revenue,
    ROUND((running_rev / grand_total) * 100, 2) AS cumulative_pct,
    CASE 
        WHEN (running_rev / grand_total) * 100 <= 70 THEN 'Class A'
        WHEN (running_rev / grand_total) * 100 <= 90 THEN 'Class B'
        ELSE 'Class C'
    END AS abc_category
FROM Cumulative
ORDER BY revenue DESC;
```

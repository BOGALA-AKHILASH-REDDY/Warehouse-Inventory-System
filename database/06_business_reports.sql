-- =============================================================================
-- NEXSUPPLY WMS - ADVANCED BUSINESS REPORTS & COMPLEX ANALYTICS
-- Demonstrates Window Functions, CTEs, Recursive CTEs, Subqueries, ABC/XYZ
-- =============================================================================

-- 1. REPORT: ABC INVENTORY ANALYSIS (PARETO 80/20 PRINCIPLE)
-- Uses SUM() OVER () window functions to calculate cumulative revenue %
WITH ProductRevenue AS (
    SELECT 
        p.product_id,
        p.sku,
        p.product_name,
        c.category_name,
        COALESCE(SUM(soi.line_total), 0) AS total_revenue,
        SUM(SUM(soi.line_total)) OVER () AS grand_total_revenue
    FROM products p
    JOIN categories c ON p.category_id = c.category_id
    LEFT JOIN sales_order_items soi ON p.product_id = soi.product_id
    LEFT JOIN sales_orders so ON soi.so_id = so.so_id AND so.status IN ('SHIPPED', 'DELIVERED')
    GROUP BY p.product_id, p.sku, p.product_name, c.category_name
),
CumulativeRevenue AS (
    SELECT 
        product_id,
        sku,
        product_name,
        category_name,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC, product_id) AS running_revenue,
        ROUND((SUM(total_revenue) OVER (ORDER BY total_revenue DESC, product_id) / NULLIF(grand_total_revenue, 0)) * 100, 2) AS cumulative_pct
    FROM ProductRevenue
)
SELECT 
    product_id,
    sku,
    product_name,
    category_name,
    total_revenue,
    cumulative_pct,
    CASE 
        WHEN cumulative_pct <= 70.00 THEN 'Class A (High Value - Top 70% Revenue)'
        WHEN cumulative_pct <= 90.00 THEN 'Class B (Medium Value - Next 20% Revenue)'
        ELSE 'Class C (Low Value - Bottom 10% Revenue)'
    END AS abc_classification
FROM CumulativeRevenue
ORDER BY total_revenue DESC;


-- 2. REPORT: WINDOW FUNCTIONS SHOWCASE - SUPPLIER RANKING
-- Demonstrates ROW_NUMBER(), RANK(), DENSE_RANK(), and NTILE(4)
SELECT 
    supplier_id,
    supplier_name,
    rating,
    total_spend,
    on_time_delivery_pct,
    ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS row_num,
    RANK() OVER (ORDER BY on_time_delivery_pct DESC) AS delivery_rank,
    DENSE_RANK() OVER (ORDER BY rating DESC) AS rating_dense_rank,
    NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
FROM v_supplier_performance
ORDER BY total_spend DESC;


-- 3. REPORT: MONTH-OVER-MONTH SALES TREND & DEMAND FORECASTING
-- Demonstrates LAG() and LEAD() window functions
WITH MonthlyRevenue AS (
    SELECT 
        DATE_TRUNC('month', order_date)::DATE AS sales_month,
        SUM(total_amount) AS monthly_revenue,
        COUNT(so_id) AS total_orders
    FROM sales_orders
    WHERE status IN ('SHIPPED', 'DELIVERED')
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT 
    sales_month,
    monthly_revenue,
    LAG(monthly_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        ((monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY sales_month)) / 
        NULLIF(LAG(monthly_revenue, 1) OVER (ORDER BY sales_month), 0)) * 100, 2
    ) AS mom_growth_pct,
    LEAD(monthly_revenue, 1) OVER (ORDER BY sales_month) AS projected_next_month_revenue
FROM MonthlyRevenue
ORDER BY sales_month ASC;


-- 4. REPORT: DEAD STOCK & SLOW-MOVING INVENTORY DETECTION (>180 DAYS NO SALES)
-- Correlated subquery & LEFT JOIN strategy
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    SUM(i.quantity_on_hand) AS total_stock_on_hand,
    SUM(i.quantity_on_hand * p.unit_cost) AS capital_tied_up,
    MAX(so.order_date) AS last_sold_date,
    COALESCE(CURRENT_DATE - MAX(so.order_date), 999) AS days_since_last_sale,
    CASE 
        WHEN MAX(so.order_date) IS NULL THEN 'DEAD_STOCK_NEVER_SOLD'
        WHEN CURRENT_DATE - MAX(so.order_date) > 180 THEN 'DEAD_STOCK_CRITICAL'
        WHEN CURRENT_DATE - MAX(so.order_date) > 90 THEN 'SLOW_MOVING'
        ELSE 'ACTIVE'
    END AS stock_movement_status
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN sales_order_items soi ON p.product_id = soi.product_id
LEFT JOIN sales_orders so ON soi.so_id = so.so_id
GROUP BY p.product_id, p.sku, p.product_name, c.category_name
HAVING MAX(so.order_date) IS NULL OR CURRENT_DATE - MAX(so.order_date) > 90
ORDER BY capital_tied_up DESC;


-- 5. REPORT: RECURSIVE CTE - CATEGORY HIERARCHY TREE & AGGREGATE INVENTORY VALUE
WITH RECURSIVE CategoryTree AS (
    -- Anchor Member: Root Categories
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        1 AS depth_level,
        category_name::TEXT AS category_path
    FROM categories
    WHERE parent_category_id IS NULL

    UNION ALL

    -- Recursive Member: Subcategories
    SELECT 
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ct.depth_level + 1,
        CONCAT(ct.category_path, ' > ', c.category_name)
    FROM categories c
    JOIN CategoryTree ct ON c.parent_category_id = ct.category_id
)
SELECT 
    ct.category_id,
    ct.category_path,
    ct.depth_level,
    COUNT(DISTINCT p.product_id) AS total_products,
    COALESCE(SUM(i.quantity_on_hand), 0) AS total_quantity_stored,
    COALESCE(SUM(i.quantity_on_hand * p.unit_cost), 0) AS total_category_inventory_value
FROM CategoryTree ct
LEFT JOIN products p ON ct.category_id = p.category_id
LEFT JOIN inventory i ON p.product_id = i.product_id
GROUP BY ct.category_id, ct.category_path, ct.depth_level
ORDER BY ct.category_path;


-- 6. REPORT: INVENTORY TURNOVER RATIO & AGING ANALYSIS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    c.category_name,
    SUM(i.quantity_on_hand) AS total_units,
    ROUND(SUM(i.quantity_on_hand * p.unit_cost), 2) AS inventory_asset_value,
    fn_calculate_turnover_ratio(p.product_id, CURRENT_DATE - INTERVAL '1 year', CURRENT_DATE) AS turnover_ratio_1yr,
    NTILE(4) OVER (ORDER BY fn_calculate_turnover_ratio(p.product_id, CURRENT_DATE - INTERVAL '1 year', CURRENT_DATE) DESC) AS turnover_quartile
FROM products p
JOIN categories c ON p.category_id = c.category_id
JOIN inventory i ON p.product_id = i.product_id
GROUP BY p.product_id, p.sku, p.product_name, c.category_name
ORDER BY turnover_ratio_1yr DESC;

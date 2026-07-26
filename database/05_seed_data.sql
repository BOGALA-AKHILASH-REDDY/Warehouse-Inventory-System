-- =============================================================================
-- NEXSUPPLY WMS - ENTERPRISE SEED DATASET
-- 100+ Products, 20 Suppliers, 50 Customers, 5 Warehouses, 1000+ Transactions
-- =============================================================================

-- 1. CATEGORIES (Parent-Child Hierarchy)
INSERT INTO categories (category_id, category_name, parent_category_id, description) VALUES
(1, 'Electronics & IT', NULL, 'Consumer electronics, IT hardware, networking gear'),
(2, 'Computers & Laptops', 1, 'Laptops, desktop PCs, workstations'),
(3, 'Mobile & Accessories', 1, 'Smartphones, tablets, power banks'),
(4, 'Industrial & Tools', NULL, 'Power tools, safety gear, industrial hardware'),
(5, 'Power Tools', 4, 'Drills, saws, grinders, pneumatic tools'),
(6, 'Pharmaceuticals & Medical', NULL, 'Prescription drugs, medical supplies, PPE'),
(7, 'Perishable Foods', NULL, 'Refrigerated and frozen food products'),
(8, 'Apparel & Footwear', NULL, 'Garments, protective workwear, footwear'),
(9, 'Automotive Parts', NULL, 'Engine parts, lubricants, tires, batteries'),
(10, 'Office Supplies', NULL, 'Paper, stationery, furniture, ink cartridges')
ON CONFLICT (category_name) DO NOTHING;

SELECT setval('categories_category_id_seq', (SELECT MAX(category_id) FROM categories));

-- 2. SUPPLIERS (20 Suppliers)
INSERT INTO suppliers (supplier_id, supplier_name, contact_name, email, phone, city, country, rating, avg_lead_time_days) VALUES
(1, 'Apex Electronics Corp', 'David Miller', 'sales@apexelectronics.com', '+1-555-0101', 'San Jose', 'USA', 4.85, 5),
(2, 'Global Micro Components', 'Sarah Jenkins', 'orders@gmc-micro.com', '+1-555-0102', 'Austin', 'USA', 4.60, 7),
(3, 'Titan Industrial Hardware', 'Robert Chen', 'contact@titanhardware.com', '+1-555-0103', 'Chicago', 'USA', 4.90, 4),
(4, 'PharmaHealth Global Inc', 'Emily Watson', 'supply@pharmahealth.org', '+1-555-0104', 'Boston', 'USA', 4.95, 3),
(5, 'FreshGrid Foods Logistics', 'Carlos Rivera', 'logistics@freshgrid.com', '+1-555-0105', 'Fresno', 'USA', 4.40, 2),
(6, 'Vanguard Industrial Supply', 'Michael Chang', 'mchang@vanguard.com', '+1-555-0106', 'Detroit', 'USA', 4.75, 6),
(7, 'NextGen Tech Components', 'Lisa Ray', 'lisa@nextgentech.io', '+1-555-0107', 'Seattle', 'USA', 4.50, 8),
(8, 'Precision Tooling LLC', 'Mark Thompson', 'sales@precisiontool.com', '+1-555-0108', 'Cleveland', 'USA', 4.80, 5),
(9, 'MedSafe Systems Ltd', 'Karen Taylor', 'orders@medsafesystems.com', '+1-555-0109', 'Philadelphia', 'USA', 4.90, 4),
(10, 'ColdChain Logistics Ltd', 'James Wilson', 'jwilson@coldchain.com', '+1-555-0110', 'Minneapolis', 'USA', 4.30, 3),
(11, 'ProGear Apparel Group', 'Amanda Martinez', 'amanda@progear.com', '+1-555-0111', 'Los Angeles', 'USA', 4.70, 10),
(12, 'AutoPart Dynamics Inc', 'Brian Scott', 'bscott@autopartdyn.com', '+1-555-0112', 'Indianapolis', 'USA', 4.65, 6),
(13, 'OfficeZone Wholesale', 'Rachel Green', 'rgreen@officezone.com', '+1-555-0113', 'Atlanta', 'USA', 4.80, 4),
(14, 'Silicon Power Tech', 'Kevin Zhang', 'kz@siliconpower.com', '+1-555-0114', 'San Francisco', 'USA', 4.85, 7),
(15, 'SteelCraft Engineering', 'Daniel Harris', 'dharris@steelcraft.com', '+1-555-0115', 'Pittsburgh', 'USA', 4.55, 9),
(16, 'BioHealth Solutions', 'Jessica Adams', 'jadams@biohealth.com', '+1-555-0116', 'San Diego', 'USA', 4.92, 3),
(17, 'Nordic Cold Foods', 'Lars Anderson', 'landerson@nordicfood.com', '+1-555-0117', 'Green Bay', 'USA', 4.25, 4),
(18, 'Metro Safety Equipment', 'Patricia White', 'pwhite@metrosafety.com', '+1-555-0118', 'Houston', 'USA', 4.78, 5),
(19, 'TransWorld Lubricants', 'Steven King', 'sking@transworld.com', '+1-555-0119', 'Dallas', 'USA', 4.60, 6),
(20, 'OmniPaper Products', 'Laura Bennett', 'lbennett@omnipaper.com', '+1-555-0120', 'Memphis', 'USA', 4.88, 3)
ON CONFLICT (supplier_name) DO NOTHING;

SELECT setval('suppliers_supplier_id_seq', (SELECT MAX(supplier_id) FROM suppliers));

-- 3. EMPLOYEES (Staff & Managers)
INSERT INTO employees (employee_id, first_name, last_name, email, role, salary, hire_date) VALUES
(1, 'Marcus', 'Vance', 'mvance@nexsupply.com', 'Warehouse Manager', 95000.00, '2021-03-15'),
(2, 'Samantha', 'Reed', 'sreed@nexsupply.com', 'Warehouse Manager', 92000.00, '2021-06-01'),
(3, 'Anthony', 'Davis', 'adavis@nexsupply.com', 'Inventory Specialist', 62000.00, '2022-01-10'),
(4, 'Elena', 'Rostova', 'erostova@nexsupply.com', 'Procurement Officer', 78000.00, '2020-11-20'),
(5, 'Derek', 'Stone', 'dstone@nexsupply.com', 'Logistics Coordinator', 68000.00, '2022-08-14')
ON CONFLICT (email) DO NOTHING;

SELECT setval('employees_employee_id_seq', (SELECT MAX(employee_id) FROM employees));

-- 4. WAREHOUSES (5 Warehouses)
INSERT INTO warehouses (warehouse_id, warehouse_name, location_code, address, city, capacity_sqft, max_pallet_capacity, current_utilization_pct, manager_id) VALUES
(1, 'Chicago Central Superhub', 'ORD-WH01', '4500 Logistics Way', 'Chicago', 250000, 10000, 78.50, 1),
(2, 'Dallas Logistics Depot', 'DFW-WH02', '1200 Cargo Parkway', 'Dallas', 180000, 7500, 64.20, 2),
(3, 'Atlanta Distribution Center', 'ATL-WH03', '880 Freight Boulevard', 'Atlanta', 200000, 8500, 82.10, 1),
(4, 'Seattle Port Fulfillment', 'SEA-WH04', '300 Harbor Avenue', 'Seattle', 150000, 6000, 59.80, 2),
(5, 'New Jersey Metro Regional', 'EWR-WH05', '95 Port Street', 'Newark', 220000, 9000, 71.40, 1)
ON CONFLICT (warehouse_name) DO NOTHING;

SELECT setval('warehouses_warehouse_id_seq', (SELECT MAX(warehouse_id) FROM warehouses));

-- Update Employees with assigned Warehouse IDs
UPDATE employees SET warehouse_id = 1 WHERE employee_id IN (1, 3);
UPDATE employees SET warehouse_id = 2 WHERE employee_id IN (2, 4);
UPDATE employees SET warehouse_id = 3 WHERE employee_id = 5;

-- 5. CUSTOMERS (50 Customers - Truncated for seed brevity but representative)
INSERT INTO customers (customer_id, customer_name, company_name, email, phone, city, credit_limit) VALUES
(1, 'Johnathan Vance', 'Apex Retail Solutions', 'jvance@apexretail.com', '+1-555-2001', 'Chicago', 50000.00),
(2, 'Sarah Jenkins', 'Metro Dynamics', 'sjenkins@metrodyn.com', '+1-555-2002', 'Dallas', 75000.00),
(3, 'Robert Sterling', 'Sterling Tech Systems', 'rsterling@sterling.com', '+1-555-2003', 'Atlanta', 100000.00),
(4, 'Maria Garcia', 'Garcia Enterprise Supply', 'mgarcia@garciasupply.com', '+1-555-2004', 'Houston', 35000.00),
(5, 'William Thorne', 'Thorne Industrial Parts', 'wthorne@thorneind.com', '+1-555-2005', 'Seattle', 60000.00)
ON CONFLICT (email) DO NOTHING;

-- Generate remaining 45 Customers automatically
DO $$
BEGIN
    FOR i IN 6..50 LOOP
        INSERT INTO customers (customer_id, customer_name, company_name, email, phone, city, credit_limit)
        VALUES (
            i, 
            CONCAT('Customer ', i), 
            CONCAT('Company ', i, ' LLC'), 
            CONCAT('customer', i, '@enterprise-client.com'),
            CONCAT('+1-555-20', LPAD(i::text, 2, '0')),
            (ARRAY['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'])[MOD(i, 10) + 1],
            (20000 + (i * 1500))::DECIMAL(12,2)
        ) ON CONFLICT (email) DO NOTHING;
    END LOOP;
END $$;

SELECT setval('customers_customer_id_seq', (SELECT MAX(customer_id) FROM customers));

-- 6. PRODUCTS (100 Products across 10 Categories)
DO $$
DECLARE
    v_cat INT;
    v_sup INT;
    v_cost DECIMAL(10,2);
    v_price DECIMAL(10,2);
    v_perishable BOOLEAN;
    v_sku VARCHAR(50);
BEGIN
    FOR i IN 1..100 LOOP
        v_cat := MOD(i, 10) + 1;
        v_sup := MOD(i, 20) + 1;
        v_cost := (15 + (i * 8.50))::DECIMAL(10,2);
        v_price := (v_cost * 1.45)::DECIMAL(10,2);
        v_perishable := (v_cat IN (6, 7)); -- Medical and Perishable Foods are perishable
        v_sku := CONCAT('SKU-PRD-', LPAD(i::text, 4, '0'));

        INSERT INTO products (
            product_id, sku, barcode, product_name, category_id, supplier_id,
            unit_cost, unit_price, min_stock_level, max_stock_level, reorder_point, is_perishable
        ) VALUES (
            i,
            v_sku,
            CONCAT('BAR-', 789000000000 + i),
            CONCAT('Enterprise Product Grade-', i, ' (Cat-', v_cat, ')'),
            v_cat,
            v_sup,
            v_cost,
            v_price,
            15 + MOD(i, 10),
            200 + (i * 5),
            30 + MOD(i, 15),
            v_perishable
        ) ON CONFLICT (sku) DO NOTHING;
    END LOOP;
END $$;

SELECT setval('products_product_id_seq', (SELECT MAX(product_id) FROM products));

-- 7. INVENTORY SEED (Seed stock levels across 5 Warehouses)
DO $$
DECLARE
    w INT;
    p INT;
    v_qty INT;
BEGIN
    FOR w IN 1..5 LOOP
        FOR p IN 1..100 LOOP
            -- Alternate stock levels to trigger low stock, optimal, and overstocked
            v_qty := CASE 
                WHEN MOD(p, 7) = 0 THEN 5 -- Critical Low Stock
                WHEN MOD(p, 11) = 0 THEN 0 -- Out of Stock
                WHEN MOD(p, 5) = 0 THEN 350 -- Overstocked
                ELSE 80 + MOD(p * w, 120) -- Normal Stock
            END;

            INSERT INTO inventory (
                warehouse_id, product_id, quantity_on_hand, quantity_allocated, aisle_location, bin_location
            ) VALUES (
                w, p, v_qty, LEAST(v_qty, MOD(p, 15)),
                CONCAT('Aisle-', LPAD((MOD(p, 12) + 1)::text, 2, '0')),
                CONCAT('Bin-', CHAR(65 + MOD(p, 6)), '-', MOD(p, 20) + 1)
            ) ON CONFLICT (warehouse_id, product_id) DO UPDATE SET quantity_on_hand = EXCLUDED.quantity_on_hand;
        END LOOP;
    END LOOP;
END $$;

-- 8. PRODUCT EXPIRY SEED DATA
INSERT INTO product_expiry (product_id, warehouse_id, batch_number, manufacturing_date, expiry_date, quantity)
SELECT 
    p.product_id,
    w.warehouse_id,
    CONCAT('LOT-2026-', LPAD(p.product_id::text, 3, '0')),
    CURRENT_DATE - INTERVAL '6 months',
    CURRENT_DATE + (ARRAY[INTERVAL '4 days', INTERVAL '12 days', INTERVAL '25 days', INTERVAL '120 days'])[MOD(p.product_id, 4) + 1],
    50 + MOD(p.product_id, 30)
FROM products p
CROSS JOIN (SELECT warehouse_id FROM warehouses WHERE warehouse_id <= 3) w
WHERE p.is_perishable = TRUE;

-- 9. HISTORICAL STOCK TRANSACTIONS (1000+ Transactions)
DO $$
DECLARE
    i INT;
    v_type VARCHAR(20);
    v_prod INT;
    v_src INT;
    v_dst INT;
    v_qty INT;
BEGIN
    FOR i IN 1..1050 LOOP
        v_prod := MOD(i, 100) + 1;
        v_src := MOD(i, 5) + 1;
        v_dst := MOD(i + 2, 5) + 1;
        IF v_src = v_dst THEN v_dst := (v_src % 5) + 1; END IF;
        
        v_type := (ARRAY['STOCK_IN', 'STOCK_OUT', 'TRANSFER', 'RETURN', 'DAMAGED', 'ADJUSTMENT'])[MOD(i, 6) + 1];
        v_qty := 5 + MOD(i, 45);

        INSERT INTO stock_transactions (
            transaction_type, product_id, source_warehouse_id, dest_warehouse_id,
            quantity, reference_id, transaction_date, employee_id, notes
        ) VALUES (
            v_type,
            v_prod,
            CASE WHEN v_type IN ('STOCK_OUT', 'TRANSFER', 'DAMAGED') THEN v_src ELSE NULL END,
            CASE WHEN v_type IN ('STOCK_IN', 'TRANSFER', 'RETURN') THEN v_dst ELSE NULL END,
            v_qty,
            CONCAT('TX-REF-', 100000 + i),
            CURRENT_TIMESTAMP - (i || ' hours')::INTERVAL,
            MOD(i, 5) + 1,
            CONCAT('Historical transaction audit log #', i)
        );
    END LOOP;
END $$;

-- 10. PURCHASE ORDERS & ITEMS
DO $$
DECLARE
    po INT;
BEGIN
    FOR po IN 1..30 LOOP
        INSERT INTO purchase_orders (
            po_id, po_number, supplier_id, warehouse_id, order_date, expected_date, delivery_date, status, total_cost, created_by
        ) VALUES (
            po,
            CONCAT('PO-2026-', LPAD(po::text, 4, '0')),
            MOD(po, 20) + 1,
            MOD(po, 5) + 1,
            CURRENT_DATE - (po * 3 || ' days')::INTERVAL,
            CURRENT_DATE - (po * 3 - 5 || ' days')::INTERVAL,
            CASE WHEN MOD(po, 4) != 0 THEN CURRENT_DATE - (po * 3 - 4 || ' days')::INTERVAL ELSE NULL END,
            CASE WHEN MOD(po, 4) != 0 THEN 'RECEIVED' ELSE 'ISSUED' END,
            (5000 + po * 450)::DECIMAL(12,2),
            MOD(po, 5) + 1
        ) ON CONFLICT (po_number) DO NOTHING;

        -- PO Items
        INSERT INTO purchase_order_items (po_id, product_id, quantity_ordered, quantity_received, unit_cost)
        VALUES 
        (po, MOD(po * 2, 100) + 1, 100, CASE WHEN MOD(po, 4) != 0 THEN 100 ELSE 0 END, 45.00),
        (po, MOD(po * 3, 100) + 1, 50, CASE WHEN MOD(po, 4) != 0 THEN 50 ELSE 0 END, 85.00);
    END LOOP;
END $$;

SELECT setval('purchase_orders_po_id_seq', (SELECT MAX(po_id) FROM purchase_orders));

-- 11. SALES ORDERS & ITEMS
DO $$
DECLARE
    so INT;
BEGIN
    FOR so IN 1..50 LOOP
        INSERT INTO sales_orders (
            so_id, so_number, customer_id, warehouse_id, order_date, shipping_date, status, total_amount, employee_id
        ) VALUES (
            so,
            CONCAT('SO-2026-', LPAD(so::text, 4, '0')),
            MOD(so, 50) + 1,
            MOD(so, 5) + 1,
            CURRENT_DATE - (so * 2 || ' days')::INTERVAL,
            CURRENT_DATE - (so * 2 - 1 || ' days')::INTERVAL,
            'DELIVERED',
            (1200 + so * 320)::DECIMAL(12,2),
            MOD(so, 5) + 1
        ) ON CONFLICT (so_number) DO NOTHING;

        -- SO Items
        INSERT INTO sales_order_items (so_id, product_id, quantity, unit_price, discount_pct)
        VALUES 
        (so, MOD(so * 2 + 1, 100) + 1, 10 + MOD(so, 5), 120.00, 5.00),
        (so, MOD(so * 3 + 2, 100) + 1, 5 + MOD(so, 3), 250.00, 0.00);
    END LOOP;
END $$;

SELECT setval('sales_orders_so_id_seq', (SELECT MAX(so_id) FROM sales_orders));

-- Refresh Materialized View
REFRESH MATERIALIZED VIEW mv_monthly_sales_analytics;

-- =============================================================================
-- NEXSUPPLY WMS - STORED PROCEDURES & CUSTOM FUNCTIONS
-- =============================================================================

-- 1. FUNCTION: Calculate Product Inventory Turnover Ratio
CREATE OR REPLACE FUNCTION fn_calculate_turnover_ratio(
    p_product_id INT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS DECIMAL(8, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cogs DECIMAL(12, 2) := 0;
    v_avg_inventory DECIMAL(12, 2) := 0;
    v_turnover DECIMAL(8, 2) := 0;
BEGIN
    -- Calculate Cost of Goods Sold (COGS) for the product within date range
    SELECT COALESCE(SUM(soi.quantity * p.unit_cost), 0)
    INTO v_cogs
    FROM sales_order_items soi
    JOIN sales_orders so ON soi.so_id = so.so_id
    JOIN products p ON soi.product_id = p.product_id
    WHERE soi.product_id = p_product_id
      AND so.order_date BETWEEN p_start_date AND p_end_date
      AND so.status IN ('SHIPPED', 'DELIVERED');

    -- Calculate Average Quantity on Hand
    SELECT COALESCE(AVG(quantity_on_hand), 1)
    INTO v_avg_inventory
    FROM inventory
    WHERE product_id = p_product_id;

    -- Turnover Ratio = COGS / Avg Inventory Cost
    IF v_avg_inventory > 0 THEN
        v_turnover := ROUND(v_cogs / (v_avg_inventory * (SELECT unit_cost FROM products WHERE product_id = p_product_id)), 2);
    END IF;

    RETURN v_turnover;
END;
$$;


-- 2. FUNCTION: Calculate Supplier On-Time Delivery Percentage
CREATE OR REPLACE FUNCTION fn_supplier_on_time_pct(
    p_supplier_id INT
)
RETURNS DECIMAL(5, 2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pct DECIMAL(5, 2) := 0.00;
BEGIN
    SELECT COALESCE(
        ROUND(
            (COUNT(CASE WHEN status = 'RECEIVED' AND (delivery_date IS NULL OR delivery_date <= expected_date) THEN 1 END)::DECIMAL / 
            NULLIF(COUNT(CASE WHEN status = 'RECEIVED' THEN 1 END), 0)) * 100, 2
        ), 0.00
    )
    INTO v_pct
    FROM purchase_orders
    WHERE supplier_id = p_supplier_id;

    RETURN v_pct;
END;
$$;


-- 3. STORED PROCEDURE: Receive Purchase Order Inventory (Stock In)
CREATE OR REPLACE PROCEDURE sp_receive_inventory(
    p_po_id INT,
    p_employee_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record RECORD;
    v_target_wh INT;
BEGIN
    -- Fetch Purchase Order details
    SELECT warehouse_id INTO v_target_wh
    FROM purchase_orders
    WHERE po_id = p_po_id AND status IN ('ISSUED', 'PARTIAL');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Order % is invalid or already fully received.', p_po_id;
    END IF;

    -- Process each PO line item
    FOR v_record IN 
        SELECT poi.product_id, (poi.quantity_ordered - poi.quantity_received) AS qty_to_receive
        FROM purchase_order_items poi
        WHERE poi.po_id = p_po_id AND poi.quantity_ordered > poi.quantity_received
    LOOP
        -- Upsert inventory in target warehouse
        INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, last_updated)
        VALUES (v_target_wh, v_record.product_id, v_record.qty_to_receive, CURRENT_TIMESTAMP)
        ON CONFLICT (warehouse_id, product_id) 
        DO UPDATE SET 
            quantity_on_hand = inventory.quantity_on_hand + v_record.qty_to_receive,
            last_updated = CURRENT_TIMESTAMP;

        -- Record Stock Transaction
        INSERT INTO stock_transactions (
            transaction_type, product_id, dest_warehouse_id, quantity, reference_id, employee_id, notes
        ) VALUES (
            'STOCK_IN', v_record.product_id, v_target_wh, v_record.qty_to_receive, 
            CONCAT('PO-', p_po_id), p_employee_id, 'Inventory received from Purchase Order'
        );

        -- Update PO Item quantity received
        UPDATE purchase_order_items
        SET quantity_received = quantity_ordered
        WHERE po_id = p_po_id AND product_id = v_record.product_id;
    END LOOP;

    -- Update Purchase Order status to RECEIVED and set delivery date
    UPDATE purchase_orders
    SET status = 'RECEIVED',
        delivery_date = CURRENT_DATE
    WHERE po_id = p_po_id;

    RAISE NOTICE 'Purchase Order % successfully received into Warehouse %.', p_po_id, v_target_wh;
END;
$$;


-- 4. STORED PROCEDURE: Sell Product / Process Sales Order (Stock Out)
CREATE OR REPLACE PROCEDURE sp_sell_product(
    p_customer_id INT,
    p_warehouse_id INT,
    p_product_id INT,
    p_quantity INT,
    p_unit_price DECIMAL(10,2),
    p_employee_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock INT;
    v_so_id INT;
    v_so_number VARCHAR(50);
BEGIN
    -- Validate current stock in warehouse
    SELECT quantity_on_hand INTO v_current_stock
    FROM inventory
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;

    IF v_current_stock IS NULL OR v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock in Warehouse %. Requested: %, Available: %', 
            p_warehouse_id, p_quantity, COALESCE(v_current_stock, 0);
    END IF;

    -- Create Sales Order Header
    v_so_number := CONCAT('SO-', FLOOR(EXTRACT(EPOCH FROM NOW())));
    INSERT INTO sales_orders (so_number, customer_id, warehouse_id, order_date, status, total_amount, employee_id)
    VALUES (v_so_number, p_customer_id, p_warehouse_id, CURRENT_DATE, 'PROCESSING', p_quantity * p_unit_price, p_employee_id)
    RETURNING so_id INTO v_so_id;

    -- Insert Sales Order Item
    INSERT INTO sales_order_items (so_id, product_id, quantity, unit_price)
    VALUES (v_so_id, p_product_id, p_quantity, p_unit_price);

    -- Deduct stock from Inventory
    UPDATE inventory
    SET quantity_on_hand = quantity_on_hand - p_quantity,
        last_updated = CURRENT_TIMESTAMP
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;

    -- Record Stock Transaction
    INSERT INTO stock_transactions (
        transaction_type, product_id, source_warehouse_id, quantity, reference_id, employee_id, notes
    ) VALUES (
        'STOCK_OUT', p_product_id, p_warehouse_id, p_quantity, v_so_number, p_employee_id, 'Sales Order fulfillment'
    );

    RAISE NOTICE 'Sales Order % processed successfully. Deducted % units.', v_so_number, p_quantity;
END;
$$;


-- 5. STORED PROCEDURE: Atomic Inter-Warehouse Stock Transfer
CREATE OR REPLACE PROCEDURE sp_transfer_inventory(
    p_source_wh INT,
    p_dest_wh INT,
    p_product_id INT,
    p_quantity INT,
    p_employee_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_src_qty INT;
BEGIN
    IF p_source_wh = p_dest_wh THEN
        RAISE EXCEPTION 'Source and Destination warehouses must be different.';
    END IF;

    -- Check source warehouse stock
    SELECT quantity_on_hand INTO v_src_qty
    FROM inventory
    WHERE warehouse_id = p_source_wh AND product_id = p_product_id;

    IF v_src_qty IS NULL OR v_src_qty < p_quantity THEN
        RAISE EXCEPTION 'Cannot transfer % units. Available at source warehouse %: %', 
            p_quantity, p_source_wh, COALESCE(v_src_qty, 0);
    END IF;

    -- Deduct from Source Warehouse
    UPDATE inventory
    SET quantity_on_hand = quantity_on_hand - p_quantity,
        last_updated = CURRENT_TIMESTAMP
    WHERE warehouse_id = p_source_wh AND product_id = p_product_id;

    -- Add to Destination Warehouse (Upsert)
    INSERT INTO inventory (warehouse_id, product_id, quantity_on_hand, last_updated)
    VALUES (p_dest_wh, p_product_id, p_quantity, CURRENT_TIMESTAMP)
    ON CONFLICT (warehouse_id, product_id)
    DO UPDATE SET 
        quantity_on_hand = inventory.quantity_on_hand + p_quantity,
        last_updated = CURRENT_TIMESTAMP;

    -- Record Transfer Stock Transaction
    INSERT INTO stock_transactions (
        transaction_type, product_id, source_warehouse_id, dest_warehouse_id, quantity, reference_id, employee_id, notes
    ) VALUES (
        'TRANSFER', p_product_id, p_source_wh, p_dest_wh, p_quantity, 
        CONCAT('TRF-', FLOOR(EXTRACT(EPOCH FROM NOW()))), p_employee_id, 'Inter-warehouse stock rebalancing'
    );

    RAISE NOTICE 'Transferred % units of product % from WH % to WH %.', p_quantity, p_product_id, p_source_wh, p_dest_wh;
END;
$$;

-- =============================================================================
-- NEXSUPPLY WMS - AUTOMATED TRIGGERS & AUDIT LOGGERS
-- =============================================================================

-- 1. TRIGGER FUNCTION: Prevent Negative Inventory Levels
CREATE OR REPLACE FUNCTION fn_prevent_negative_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.quantity_on_hand < 0 THEN
        RAISE EXCEPTION 'Transaction aborted: Negative stock level (%) attempted for Product % in Warehouse %.',
            NEW.quantity_on_hand, NEW.product_id, NEW.warehouse_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_prevent_negative_stock
BEFORE INSERT OR UPDATE ON inventory
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_negative_stock();


-- 2. TRIGGER FUNCTION: Automatic Reorder Alert Generator
CREATE OR REPLACE FUNCTION fn_auto_reorder_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_reorder_point INT;
    v_min_stock INT;
    v_max_stock INT;
    v_recommended_qty INT;
    v_alert_exists INT;
BEGIN
    -- Fetch reorder settings from product master
    SELECT min_stock_level, max_stock_level, reorder_point
    INTO v_min_stock, v_max_stock, v_reorder_point
    FROM products
    WHERE product_id = NEW.product_id;

    -- Check if stock has dropped below or equal to reorder point
    IF NEW.quantity_on_hand <= v_reorder_point THEN
        -- Calculate economic reorder quantity to reach max stock
        v_recommended_qty := GREATEST((v_max_stock - NEW.quantity_on_hand), 10);

        -- Check if an active PENDING or PO_CREATED alert already exists
        SELECT COUNT(*) INTO v_alert_exists
        FROM reorder_alerts
        WHERE product_id = NEW.product_id 
          AND warehouse_id = NEW.warehouse_id
          AND alert_status IN ('PENDING', 'PO_CREATED');

        IF v_alert_exists = 0 THEN
            INSERT INTO reorder_alerts (
                product_id, warehouse_id, current_stock, min_stock_level, recommended_reorder_qty, alert_status
            ) VALUES (
                NEW.product_id, NEW.warehouse_id, NEW.quantity_on_hand, v_min_stock, v_recommended_qty, 'PENDING'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_auto_reorder_alert
AFTER INSERT OR UPDATE ON inventory
FOR EACH ROW
EXECUTE FUNCTION fn_auto_reorder_alert();


-- 3. TRIGGER FUNCTION: Immutable Inventory Audit Log Trigger
CREATE OR REPLACE FUNCTION fn_inventory_audit_logger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO inventory_audit_logs (entity_type, entity_id, action_type, old_values, new_values, performed_by)
        VALUES ('INVENTORY', NEW.inventory_id, 'INSERT', NULL, row_to_json(NEW)::jsonb, CURRENT_USER);
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO inventory_audit_logs (entity_type, entity_id, action_type, old_values, new_values, performed_by)
        VALUES ('INVENTORY', NEW.inventory_id, 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, CURRENT_USER);
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO inventory_audit_logs (entity_type, entity_id, action_type, old_values, new_values, performed_by)
        VALUES ('INVENTORY', OLD.inventory_id, 'DELETE', row_to_json(OLD)::jsonb, NULL, CURRENT_USER);
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_inventory_audit_logger
AFTER INSERT OR UPDATE OR DELETE ON inventory
FOR EACH ROW
EXECUTE FUNCTION fn_inventory_audit_logger();


-- 4. TRIGGER FUNCTION: Automatically Update Product Expiry Status
CREATE OR REPLACE FUNCTION fn_update_expiry_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.expiry_date <= CURRENT_DATE THEN
        NEW.status := 'EXPIRED';
    ELSIF NEW.expiry_date <= CURRENT_DATE + INTERVAL '15 days' THEN
        NEW.status := 'NEAR_EXPIRY';
    ELSE
        NEW.status := 'ACTIVE';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_update_expiry_status
BEFORE INSERT OR UPDATE ON product_expiry
FOR EACH ROW
EXECUTE FUNCTION fn_update_expiry_status();

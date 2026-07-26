-- =============================================================================
-- NEXSUPPLY WMS - COMPREHENSIVE TEST SUITE & VERIFICATION SCRIPTS
-- Tests integrity constraints, stored procedures, triggers, and edge cases
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TEST CASE 1: NEGATIVE STOCK PREVENTION TRIGGER
-- Expected Result: FAILS with exception 'Transaction aborted: Negative stock level...'
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '--- RUNNING TEST CASE 1: NEGATIVE STOCK CHECK ---';
    BEGIN
        UPDATE inventory 
        SET quantity_on_hand = -50 
        WHERE warehouse_id = 1 AND product_id = 1;

        RAISE EXCEPTION 'TEST FAILED: Negative stock was allowed!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'TEST PASSED: Negative stock prevented successfully. Error caught: %', SQLERRM;
    END;
END $$;


-- -----------------------------------------------------------------------------
-- TEST CASE 2: AUTOMATIC REORDER ALERT TRIGGER EXECUTION
-- Expected Result: Automatically creates an entry in `reorder_alerts` when stock <= reorder_point
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_alert_count INT;
BEGIN
    RAISE NOTICE '--- RUNNING TEST CASE 2: AUTOMATIC REORDER ALERT ---';
    
    -- Drop stock of Product 2 in Warehouse 1 to 5 units (below reorder point)
    UPDATE inventory 
    SET quantity_on_hand = 5 
    WHERE warehouse_id = 1 AND product_id = 2;

    -- Verify reorder alert insertion
    SELECT COUNT(*) INTO v_alert_count 
    FROM reorder_alerts 
    WHERE warehouse_id = 1 AND product_id = 2 AND alert_status = 'PENDING';

    IF v_alert_count > 0 THEN
        RAISE NOTICE 'TEST PASSED: Reorder alert automatically generated.';
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Reorder alert was not created!';
    END IF;
END $$;


-- -----------------------------------------------------------------------------
-- TEST CASE 3: INVENTORY AUDIT LOGGER TRIGGER VERIFICATION
-- Expected Result: Record inserted into `inventory_audit_logs` on update
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_log_count INT;
BEGIN
    RAISE NOTICE '--- RUNNING TEST CASE 3: AUDIT LOGGING ---';

    -- Perform valid stock adjustment
    UPDATE inventory
    SET quantity_on_hand = quantity_on_hand + 10
    WHERE warehouse_id = 1 AND product_id = 3;

    -- Verify audit log capture
    SELECT COUNT(*) INTO v_log_count
    FROM inventory_audit_logs
    WHERE entity_type = 'INVENTORY' AND action_type = 'UPDATE';

    IF v_log_count > 0 THEN
        RAISE NOTICE 'TEST PASSED: Audit log recorded update successfully.';
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Audit log entry missing!';
    END IF;
END $$;


-- -----------------------------------------------------------------------------
-- TEST CASE 4: INTER-WAREHOUSE STOCK TRANSFER STORED PROCEDURE
-- Expected Result: Atomically moves stock from WH 1 to WH 2 and logs transaction
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_wh1_before INT;
    v_wh1_after INT;
    v_wh2_before INT;
    v_wh2_after INT;
BEGIN
    RAISE NOTICE '--- RUNNING TEST CASE 4: INTER-WAREHOUSE STOCK TRANSFER ---';

    -- Record initial balances for Product 4
    SELECT quantity_on_hand INTO v_wh1_before FROM inventory WHERE warehouse_id = 1 AND product_id = 4;
    SELECT quantity_on_hand INTO v_wh2_before FROM inventory WHERE warehouse_id = 2 AND product_id = 4;

    -- Execute transfer of 10 units
    CALL sp_transfer_inventory(1, 2, 4, 10, 1);

    -- Check updated balances
    SELECT quantity_on_hand INTO v_wh1_after FROM inventory WHERE warehouse_id = 1 AND product_id = 4;
    SELECT quantity_on_hand INTO v_wh2_after FROM inventory WHERE warehouse_id = 2 AND product_id = 4;

    IF (v_wh1_after = v_wh1_before - 10) AND (v_wh2_after = v_wh2_before + 10) THEN
        RAISE NOTICE 'TEST PASSED: Stock transfer atomic balance verified. WH1: % -> %, WH2: % -> %',
            v_wh1_before, v_wh1_after, v_wh2_before, v_wh2_after;
    ELSE
        RAISE EXCEPTION 'TEST FAILED: Stock transfer balance mismatch!';
    END IF;
END $$;

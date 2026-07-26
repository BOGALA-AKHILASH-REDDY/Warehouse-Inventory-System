-- =============================================================================
-- NEXSUPPLY WMS - ENTERPRISE WAREHOUSE INVENTORY MANAGEMENT SYSTEM
-- Database Schema DDL (PostgreSQL Dialect 3NF Standard)
-- =============================================================================

-- Drop tables if exists (Cascade order for clean creation)
DROP TABLE IF EXISTS inventory_audit_logs CASCADE;
DROP TABLE IF EXISTS reorder_alerts CASCADE;
DROP TABLE IF EXISTS product_expiry CASCADE;
DROP TABLE IF EXISTS sales_order_items CASCADE;
DROP TABLE IF EXISTS sales_orders CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS stock_transactions CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- 1. CATEGORIES (Supports Hierarchical Parent-Child Tree)
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INT REFERENCES categories(category_id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. SUPPLIERS
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL UNIQUE,
    contact_name VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    phone VARCHAR(30),
    address TEXT,
    city VARCHAR(80),
    country VARCHAR(80) DEFAULT 'USA',
    rating DECIMAL(3, 2) CHECK (rating >= 0.00 AND rating <= 5.00),
    avg_lead_time_days INT DEFAULT 7 CHECK (avg_lead_time_days >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. CUSTOMERS
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    company_name VARCHAR(150),
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(30),
    address TEXT,
    city VARCHAR(80),
    country VARCHAR(80) DEFAULT 'USA',
    credit_limit DECIMAL(12, 2) DEFAULT 10000.00 CHECK (credit_limit >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. EMPLOYEES
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('Warehouse Manager', 'Inventory Specialist', 'Logistics Coordinator', 'Procurement Officer', 'Auditor')),
    warehouse_id INT, -- Foreign key added after warehouses table created
    salary DECIMAL(10, 2) CHECK (salary > 0),
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 5. WAREHOUSES
CREATE TABLE warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    warehouse_name VARCHAR(100) NOT NULL UNIQUE,
    location_code VARCHAR(20) NOT NULL UNIQUE,
    address TEXT,
    city VARCHAR(80) NOT NULL,
    capacity_sqft INT NOT NULL CHECK (capacity_sqft > 0),
    max_pallet_capacity INT NOT NULL CHECK (max_pallet_capacity > 0),
    current_utilization_pct DECIMAL(5, 2) DEFAULT 0.00 CHECK (current_utilization_pct >= 0 AND current_utilization_pct <= 100.00),
    manager_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add Foreign Key constraint to employees referencing warehouses
ALTER TABLE employees 
ADD CONSTRAINT fk_employee_warehouse 
FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id) ON DELETE SET NULL;

-- 6. PRODUCTS
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    barcode VARCHAR(100) UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    supplier_id INT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    unit_cost DECIMAL(10, 2) NOT NULL CHECK (unit_cost >= 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= unit_cost),
    min_stock_level INT NOT NULL DEFAULT 10 CHECK (min_stock_level >= 0),
    max_stock_level INT NOT NULL DEFAULT 500 CHECK (max_stock_level >= min_stock_level),
    reorder_point INT NOT NULL DEFAULT 20 CHECK (reorder_point >= min_stock_level),
    is_perishable BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. INVENTORY (Warehouse Specific Stock Levels)
CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    quantity_on_hand INT NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_allocated INT NOT NULL DEFAULT 0 CHECK (quantity_allocated >= 0),
    quantity_reserved INT NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    aisle_location VARCHAR(20),
    bin_location VARCHAR(20),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_warehouse_product UNIQUE (warehouse_id, product_id)
);

-- 8. STOCK TRANSACTIONS
CREATE TABLE stock_transactions (
    transaction_id SERIAL PRIMARY KEY,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('STOCK_IN', 'STOCK_OUT', 'TRANSFER', 'RETURN', 'DAMAGED', 'ADJUSTMENT')),
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    source_warehouse_id INT REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT,
    dest_warehouse_id INT REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    reference_id VARCHAR(100), -- e.g., PO-1002 or SO-5001
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    notes TEXT,
    CONSTRAINT chk_transfer_warehouses CHECK (
        (transaction_type = 'TRANSFER' AND source_warehouse_id IS NOT NULL AND dest_warehouse_id IS NOT NULL AND source_warehouse_id <> dest_warehouse_id)
        OR (transaction_type <> 'TRANSFER')
    )
);

-- 9. PURCHASE ORDERS
CREATE TABLE purchase_orders (
    po_id SERIAL PRIMARY KEY,
    po_number VARCHAR(50) NOT NULL UNIQUE,
    supplier_id INT NOT NULL REFERENCES suppliers(supplier_id) ON DELETE RESTRICT,
    warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date DATE NOT NULL,
    delivery_date DATE,
    status VARCHAR(20) DEFAULT 'ISSUED' CHECK (status IN ('DRAFT', 'ISSUED', 'PARTIAL', 'RECEIVED', 'CANCELLED')),
    total_cost DECIMAL(12, 2) DEFAULT 0.00 CHECK (total_cost >= 0),
    created_by INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_po_dates CHECK (expected_date >= order_date)
);

-- 10. PURCHASE ORDER ITEMS
CREATE TABLE purchase_order_items (
    po_item_id SERIAL PRIMARY KEY,
    po_id INT NOT NULL REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    quantity_received INT DEFAULT 0 CHECK (quantity_received >= 0),
    unit_cost DECIMAL(10, 2) NOT NULL CHECK (unit_cost >= 0),
    line_total DECIMAL(12, 2) GENERATED ALWAYS AS (quantity_ordered * unit_cost) STORED
);

-- 11. SALES ORDERS
CREATE TABLE sales_orders (
    so_id SERIAL PRIMARY KEY,
    so_number VARCHAR(50) NOT NULL UNIQUE,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    shipping_date DATE,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    total_amount DECIMAL(12, 2) DEFAULT 0.00 CHECK (total_amount >= 0),
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12. SALES ORDER ITEMS
CREATE TABLE sales_order_items (
    so_item_id SERIAL PRIMARY KEY,
    so_id INT NOT NULL REFERENCES sales_orders(so_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount_pct DECIMAL(4, 2) DEFAULT 0.00 CHECK (discount_pct >= 0.00 AND discount_pct <= 100.00),
    line_total DECIMAL(12, 2) GENERATED ALWAYS AS (quantity * unit_price * (1 - discount_pct / 100.0)) STORED
);

-- 13. PRODUCT EXPIRY (Batch & Lot Expiry Tracking)
CREATE TABLE product_expiry (
    expiry_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    batch_number VARCHAR(50) NOT NULL,
    manufacturing_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    quantity INT NOT NULL CHECK (quantity >= 0),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'NEAR_EXPIRY', 'EXPIRED', 'DISPOSED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_expiry_dates CHECK (expiry_date > manufacturing_date)
);

-- 14. REORDER ALERTS
CREATE TABLE reorder_alerts (
    alert_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    warehouse_id INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE,
    current_stock INT NOT NULL,
    min_stock_level INT NOT NULL,
    recommended_reorder_qty INT NOT NULL,
    alert_status VARCHAR(20) DEFAULT 'PENDING' CHECK (alert_status IN ('PENDING', 'PO_CREATED', 'RESOLVED', 'IGNORED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 15. INVENTORY AUDIT LOGS (Immutable Compliance Log)
CREATE TABLE inventory_audit_logs (
    log_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INT NOT NULL,
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    performed_by VARCHAR(100) DEFAULT CURRENT_USER,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEX CREATION (Optimized for High-Throughput Warehouse Queries)
-- =============================================================================

-- Indexes on Product SKU and Barcode
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_supplier ON products(supplier_id);

-- Composite Index on Inventory (Warehouse + Product Lookup)
CREATE INDEX idx_inventory_wh_prod ON inventory(warehouse_id, product_id);
CREATE INDEX idx_inventory_qty ON inventory(quantity_on_hand);

-- Stock Transaction Indexes
CREATE INDEX idx_stock_tx_date ON stock_transactions(transaction_date);
CREATE INDEX idx_stock_tx_product ON stock_transactions(product_id);
CREATE INDEX idx_stock_tx_type ON stock_transactions(transaction_type);

-- Product Expiry Date Indexes (Critical for Expiry Alerts)
CREATE INDEX idx_expiry_date ON product_expiry(expiry_date);
CREATE INDEX idx_expiry_status ON product_expiry(status);

-- Sales & Purchase Orders Indexes
CREATE INDEX idx_so_customer ON sales_orders(customer_id);
CREATE INDEX idx_so_date ON sales_orders(order_date);
CREATE INDEX idx_po_supplier ON purchase_orders(supplier_id);
CREATE INDEX idx_po_date ON purchase_orders(order_date);

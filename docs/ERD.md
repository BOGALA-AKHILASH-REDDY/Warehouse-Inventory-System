# Entity-Relationship Specification - NexSupply WMS

This document details the relational schema architecture, cardinalities, constraints, and keys for the 15 core tables.

---

## 1. ER Diagram (Mermaid Rendering)

```mermaid
erDiagram
    categories {
        int category_id PK
        string category_name UK
        int parent_category_id FK
        text description
    }
    suppliers {
        int supplier_id PK
        string supplier_name UK
        string contact_name
        string email UK
        string phone
        decimal rating
        int avg_lead_time_days
    }
    customers {
        int customer_id PK
        string customer_name
        string email UK
        decimal credit_limit
    }
    employees {
        int employee_id PK
        string first_name
        string last_name
        string role
        int warehouse_id FK
    }
    warehouses {
        int warehouse_id PK
        string warehouse_name UK
        string location_code UK
        int capacity_sqft
        int max_pallet_capacity
        int manager_id FK
    }
    products {
        int product_id PK
        string sku UK
        string barcode UK
        string product_name
        int category_id FK
        int supplier_id FK
        decimal unit_cost
        decimal unit_price
        int min_stock_level
        int max_stock_level
        int reorder_point
        boolean is_perishable
    }
    inventory {
        int inventory_id PK
        int warehouse_id FK
        int product_id FK
        int quantity_on_hand
        int quantity_allocated
        string aisle_location
        string bin_location
    }
    stock_transactions {
        int transaction_id PK
        string transaction_type
        int product_id FK
        int source_warehouse_id FK
        int dest_warehouse_id FK
        int quantity
        string reference_id
    }
    purchase_orders {
        int po_id PK
        string po_number UK
        int supplier_id FK
        int warehouse_id FK
        date order_date
        date expected_date
        string status
    }
    purchase_order_items {
        int po_item_id PK
        int po_id FK
        int product_id FK
        int quantity_ordered
        int quantity_received
        decimal unit_cost
    }
    sales_orders {
        int so_id PK
        string so_number UK
        int customer_id FK
        int warehouse_id FK
        date order_date
        string status
    }
    sales_order_items {
        int so_item_id PK
        int so_id FK
        int product_id FK
        int quantity
        decimal unit_price
    }
    product_expiry {
        int expiry_id PK
        int product_id FK
        int warehouse_id FK
        string batch_number
        date expiry_date
        string status
    }
    reorder_alerts {
        int alert_id PK
        int product_id FK
        int warehouse_id FK
        int current_stock
        int min_stock_level
        string alert_status
    }
    inventory_audit_logs {
        int log_id PK
        string entity_type
        int entity_id
        string action_type
        jsonb old_values
        jsonb new_values
    }

    categories ||--o{ products : "categorizes"
    suppliers ||--o{ products : "supplies"
    suppliers ||--o{ purchase_orders : "fulfills"
    warehouses ||--o{ inventory : "houses"
    warehouses ||--o{ employees : "employs"
    products ||--o{ inventory : "stocked in"
    products ||--o{ stock_transactions : "involved in"
    purchase_orders ||--o{ purchase_order_items : "contains"
    products ||--o{ purchase_order_items : "line item"
    sales_orders ||--o{ sales_order_items : "contains"
    products ||--o{ sales_order_items : "line item"
    customers ||--o{ sales_orders : "places"
    inventory ||--o{ inventory_audit_logs : "audits"
```

---

## 2. Table Relationships & Cardinality Summary

1. **`categories` (1) to `categories` (N)**: Recursive self-referencing relationship (`parent_category_id`) allowing multi-tier product category taxonomy.
2. **`suppliers` (1) to `products` (N)**: One supplier supplies multiple products.
3. **`warehouses` (1) to `inventory` (N)**: Junction table enforcing unique `(warehouse_id, product_id)` pairs.
4. **`products` (1) to `product_expiry` (N)**: Enables multi-batch lot tracking per warehouse for perishable items.
5. **`purchase_orders` (1) to `purchase_order_items` (N)**: Parent-child header/detail structure for vendor procurement.
6. **`sales_orders` (1) to `sales_order_items` (N)**: Parent-child header/detail structure for customer order fulfillment.

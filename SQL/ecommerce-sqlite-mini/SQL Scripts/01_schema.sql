--01_schema — Creating schema, constraints, indexes

PRAGMA foreign_keys = ON; --Enabling foreign keys bcz (SQLite default is OFF in some setups)

DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id    INTEGER PRIMARY KEY,
  full_name      TEXT NOT NULL,
  signup_date    TEXT NOT NULL, -- ISO date
  city           TEXT,
  state          TEXT,
  age            INTEGER,
  gender         TEXT CHECK (gender IN ('F','M','O'))
);

CREATE TABLE products (
  product_id     INTEGER PRIMARY KEY,
  product_name   TEXT NOT NULL,
  category       TEXT NOT NULL,
  price          REAL NOT NULL CHECK (price >= 0),
  cost           REAL NOT NULL CHECK (cost >= 0)
);

CREATE TABLE orders (
  order_id       INTEGER PRIMARY KEY,
  customer_id    INTEGER NOT NULL,
  order_date     TEXT NOT NULL,
  status         TEXT NOT NULL CHECK (status IN ('PLACED','CANCELLED','COMPLETED')),
  channel        TEXT NOT NULL CHECK (channel IN ('APP','WEB','MARKETPLACE')),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
  order_item_id  INTEGER PRIMARY KEY,
  order_id       INTEGER NOT NULL,
  product_id     INTEGER NOT NULL,
  quantity       INTEGER NOT NULL CHECK (quantity > 0),
  unit_price     REAL NOT NULL CHECK (unit_price >= 0),
  discount       REAL NOT NULL CHECK (discount >= 0),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE payments (
  payment_id     INTEGER PRIMARY KEY,
  order_id       INTEGER UNIQUE NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('UPI','CARD','COD','NBANK')),
  amount         REAL NOT NULL CHECK (amount >= 0),
  status         TEXT NOT NULL CHECK (status IN ('SUCCESS','FAILURE')),
  payment_date   TEXT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE shipments (
  shipment_id    INTEGER PRIMARY KEY,
  order_id       INTEGER UNIQUE NOT NULL,
  shipped_date   TEXT,
  delivered_date TEXT,
  carrier        TEXT,
  sla_days       INTEGER NOT NULL DEFAULT 5 CHECK (sla_days > 0),
  FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE returns (
  return_id      INTEGER PRIMARY KEY,
  order_item_id  INTEGER UNIQUE NOT NULL,
  return_date    TEXT NOT NULL,
  reason         TEXT NOT NULL,
  FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
);

-- Indexes for performance
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date); 
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_shipments_order ON shipments(order_id);
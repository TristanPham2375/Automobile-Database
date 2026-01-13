# 🚗 Automobile Marketplace Database (MySQL 8)

A normalized relational database for an **Autotrader-style vehicle marketplace**, built in **MySQL 8+** using InnoDB, foreign keys, constraints, triggers, scheduled events, views, and JSON-based filters.

This project models both:
- A **vehicle catalog layer** (manufacturers, models, engines, classes), and  
- A **marketplace layer** (vehicles by VIN, listings, sellers, buyers, messaging, watchlists, analytics).

It demonstrates **database design, data integrity, and automation** in a production-style schema.

---

## 📌 Key Features

### 1️⃣ Catalog Layer (4NF Normalized)
A clean, extensible product catalog for vehicles.

**Core Entities**
- `Manufacturer` (with parent companies, company type)
- `Model` (class, drivetrain, mileage, reliability, price)
- `Engine` (fuel type, power, displacement)
- `Class`, `FuelType`, `CompanyType` lookup tables

**Normalization**
- Multi-valued attributes decomposed into:
  - `ManufacturerBrand`
  - `ManufacturerFounder`
- Many-to-many:
  - `ModelEngine`
- 1:1 extensions:
  - `Speed`
  - `Acceleration`

**Catalog Views**
- `vModelManufacturerClass` → model + manufacturer + class  
- `vModelEngine` → model + engine + fuel type  

---

### 2️⃣ Marketplace Layer (Autotrader-style)

#### 🔹 Sellers & Buyers
- `Seller` (polymorphic)
  - `Dealer`
  - `PrivateSeller`
- `AppUser` (buyers)

#### 🔹 Vehicles & Listings
- `Vehicle` (VIN-based, ties marketplace to catalog `Model`)
- `Listing` (price, status, expiry, sold date)
- `ListingPhoto`
- `ListingPriceHistory`

#### 🔹 Buyer Features
- `Watchlist` (favorites)
- `SavedSearch` (JSON-based filters)
- `MessageThread` + `Message` (buyer–seller messaging)

#### 🔹 Location
- `Location` with region indexes for search

---

## ⚙️ Data Integrity & Business Rules

Implemented using **constraints, triggers, and foreign keys**:

### ✅ Validation
- Prevent negative prices, mileage, power, displacement
- VIN must be 17 characters
- Vehicle year range enforced via triggers
- Seat, mileage, engine, and price sanity checks

### 🔒 Marketplace Rules
- **One ACTIVE listing per VIN** (trigger)
- **Price history automatically tracked** on update
- **SoldAt timestamp auto-set** when status becomes `SOLD`

---

## ⏱️ Automation with Events

Scheduled background jobs simulate real marketplace behavior:

| Event | Purpose |
|------|--------|
| `ExpireListingsNightly` | Expires listings past `ExpiresAt` |
| `CleanupOldDraftListingsWeekly` | Deletes stale drafts/pending listings |
| `CaptureMarketSnapshotDaily` | Stores market KPIs (active count, avg, median price, mileage) |
| `NotifyPriceDropsDaily` | Creates notifications for watchlisted price drops |

---

## 📊 Analytics & Views

### 🔍 Search View
`vListingSearch` powers browsing like a real marketplace:
- Filters by price, mileage, class, location, condition, seller type

### 📈 Functions
- `avgPriceByClass(classId)` → average model price by class (catalog)
- `avgActiveListingPriceByClass(classId)` → marketplace analytics

### 📸 Market Snapshots
`MarketSnapshot` stores daily:
- Active listings
- Average price
- Approximate median price
- Average mileage

---

## 🧠 Design Highlights

- **Normalized to 4NF** to remove multi-valued dependencies
- **VIN-based Vehicle layer** separates real inventory from abstract models
- **Polymorphic seller design** (`Dealer` vs `PrivateSeller`)
- **JSON filters** for flexible saved searches (like modern apps)
- **Triggers + Events** simulate real business workflows
- **Indexes** on search-critical fields (price, status, city, mileage, model, year)

---

## 🛠️ Technologies

- **MySQL 8.0+**
- InnoDB
- Foreign keys, CHECK constraints
- Triggers & stored functions
- Scheduled events (jobs)
- JSON columns for flexible search filters

---

## 📂 ER (UML) Diagram

<img width="2086" height="1246" alt="Untitled" src="https://github.com/user-attachments/assets/fdc5a804-0ca4-4542-b1cc-a1f398e6d569" />





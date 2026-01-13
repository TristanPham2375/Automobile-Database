/* =========================================================
   Automobile Marketplace Database
   MySQL 8.0+ (InnoDB, CHECK constraints, triggers, events, jobs)

   Purpose:
   - A normalized (>=4NF) schema for an automobile marketplace (catalog + marketplace layers).
   - Designed to be compatible with MySQL Workbench and to re-run safely in development.

   Notes on scope:
   - This schema provides core functionality for an Autotrader-like app (listings, price history,
     photos, messaging, watchlists, saved searches) but is intentionally simplified in some areas
     (no in-app payments, limited analytics) — good for a lighter marketplace.

   ========================================================= */

CREATE DATABASE IF NOT EXISTS Automobile_DB
  DEFAULT CHARACTER SET = utf8mb4
  DEFAULT COLLATE = utf8mb4_unicode_ci;
USE Automobile_DB;
SET GLOBAL event_scheduler = ON;

SET SESSION sql_safe_updates = 0;

/* =========================================================
   1) LOOKUP TABLES (Catalog)
   ========================================================= */

CREATE TABLE IF NOT EXISTS CompanyType (
  CompanyType CHAR(1) PRIMARY KEY,
  CompanyTypeDesc VARCHAR(60) NOT NULL,
  CONSTRAINT ck_companytype_desc CHECK (CHAR_LENGTH(TRIM(CompanyTypeDesc)) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS FuelType (
  FuelType CHAR(1) PRIMARY KEY,
  FuelTypeDesc VARCHAR(60) NOT NULL,
  CONSTRAINT ck_fueltype_desc CHECK (CHAR_LENGTH(TRIM(FuelTypeDesc)) > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Class (
  ClassId SMALLINT AUTO_INCREMENT PRIMARY KEY,
  ClassDesc VARCHAR(80) NOT NULL,
  CONSTRAINT ck_class_desc CHECK (CHAR_LENGTH(TRIM(ClassDesc)) > 0)
) ENGINE=InnoDB;

CREATE INDEX idx_class_desc ON Class(ClassDesc);


/* =========================================================
   2) CORE CATALOG TABLES (Manufacturer, Model, Engine)
   ========================================================= */

CREATE TABLE IF NOT EXISTS Manufacturer (
  ManufacturerId SMALLINT AUTO_INCREMENT PRIMARY KEY,
  ManufacturerName VARCHAR(120) NOT NULL,
  ManufacturerOrigin VARCHAR(80),
  ManufacturerFounded DATE,
  ManufacturerHeadquarters VARCHAR(120),
  ManufacturerParentId SMALLINT NULL,
  ManufacturerCompanyType CHAR(1) NOT NULL,

  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT uq_manufacturer_name UNIQUE (ManufacturerName),
  CONSTRAINT fk_manufacturer_companytype
    FOREIGN KEY (ManufacturerCompanyType) REFERENCES CompanyType(CompanyType)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_manufacturer_parent
    FOREIGN KEY (ManufacturerParentId) REFERENCES Manufacturer(ManufacturerId)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Decompose multi-valued Manufacturer attributes to achieve 4NF
CREATE TABLE ManufacturerBrand (
  ManufacturerId SMALLINT NOT NULL,
  BrandName VARCHAR(120) NOT NULL,
  PRIMARY KEY (ManufacturerId, BrandName),
  CONSTRAINT fk_brand_manufacturer FOREIGN KEY (ManufacturerId) REFERENCES Manufacturer(ManufacturerId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ManufacturerFounder (
  FounderId BIGINT AUTO_INCREMENT PRIMARY KEY,
  ManufacturerId SMALLINT NOT NULL,
  FounderName VARCHAR(120) NOT NULL,
  CONSTRAINT fk_founder_manufacturer FOREIGN KEY (ManufacturerId) REFERENCES Manufacturer(ManufacturerId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_manufacturer_name ON Manufacturer(ManufacturerName);
CREATE INDEX idx_manufacturer_origin ON Manufacturer(ManufacturerOrigin);

CREATE TABLE IF NOT EXISTS Model (
  ModelId SMALLINT AUTO_INCREMENT PRIMARY KEY,
  ModelName VARCHAR(120) NOT NULL,
  ModelReleaseDate DATE,

  ModelManufacturerId SMALLINT NOT NULL,
  ModelClassId SMALLINT NOT NULL,

  ModelDrivetrain VARCHAR(40),
  ModelTransmissionType VARCHAR(40),
  ModelSeats TINYINT,

  ModelCityMileage DECIMAL(6,2),
  ModelHighwayMileage DECIMAL(6,2),

  ModelPrice DECIMAL(12,2),
  ModelReliabilityScore DECIMAL(5,2),

  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT ck_model_price CHECK (ModelPrice IS NULL OR ModelPrice >= 0),
  CONSTRAINT ck_model_seats CHECK (ModelSeats IS NULL OR ModelSeats BETWEEN 1 AND 12),
  CONSTRAINT ck_model_mileage CHECK (
    (ModelCityMileage IS NULL OR ModelCityMileage >= 0) AND
    (ModelHighwayMileage IS NULL OR ModelHighwayMileage >= 0)
  ),

  CONSTRAINT fk_model_manufacturer
    FOREIGN KEY (ModelManufacturerId) REFERENCES Manufacturer(ManufacturerId)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_model_class
    FOREIGN KEY (ModelClassId) REFERENCES Class(ClassId)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_model_name ON Model(ModelName);
CREATE INDEX idx_model_release_date ON Model(ModelReleaseDate);

CREATE TABLE IF NOT EXISTS Engine (
  EngineId SMALLINT AUTO_INCREMENT PRIMARY KEY,
  EngineFuelType CHAR(1) NOT NULL,
  EnginePower INT NOT NULL,
  EngineManufacturerId SMALLINT NOT NULL,

  EngineConfiguration VARCHAR(40),
  EngineCylinder TINYINT,
  EngineDisplacement DECIMAL(6,2),

  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT ck_engine_power CHECK (EnginePower >= 0),
  CONSTRAINT ck_engine_cyl CHECK (EngineCylinder IS NULL OR EngineCylinder BETWEEN 1 AND 16),
  CONSTRAINT ck_engine_disp CHECK (EngineDisplacement IS NULL OR EngineDisplacement >= 0),

  CONSTRAINT fk_engine_fueltype
    FOREIGN KEY (EngineFuelType) REFERENCES FuelType(FuelType)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_engine_manufacturer
    FOREIGN KEY (EngineManufacturerId) REFERENCES Manufacturer(ManufacturerId)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_engine_fueltype ON Engine(EngineFuelType);
CREATE INDEX idx_engine_power ON Engine(EnginePower);


/* =========================================================
   3) RELATIONSHIP + EXTENSION TABLES (Catalog)
   ========================================================= */

-- Many-to-many: Model <-> Engine
CREATE TABLE ModelEngine (
  ModelEngineModelId SMALLINT NOT NULL,
  ModelEngineEngineId SMALLINT NOT NULL,
  PRIMARY KEY (ModelEngineModelId, ModelEngineEngineId),
  CONSTRAINT fk_modelengine_model
    FOREIGN KEY (ModelEngineModelId) REFERENCES Model(ModelId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_modelengine_engine
    FOREIGN KEY (ModelEngineEngineId) REFERENCES Engine(EngineId)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 1:1 extension: Speed by model
CREATE TABLE Speed (
  SpeedModelId SMALLINT PRIMARY KEY,
  SpeedMax INT NOT NULL,
  CONSTRAINT ck_speed_max CHECK (SpeedMax >= 0),
  CONSTRAINT fk_speed_model
    FOREIGN KEY (SpeedModelId) REFERENCES Model(ModelId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 1:1 extension: Acceleration by model
CREATE TABLE Acceleration (
  AccelerationModelId SMALLINT PRIMARY KEY,
  AccelerationZeroToSixty DECIMAL(5,2),
  AccelerationQuarterMile DECIMAL(5,2),
  CONSTRAINT ck_accel_0_60 CHECK (AccelerationZeroToSixty IS NULL OR AccelerationZeroToSixty >= 0),
  CONSTRAINT ck_accel_qm CHECK (AccelerationQuarterMile IS NULL OR AccelerationQuarterMile >= 0),
  CONSTRAINT fk_accel_model
    FOREIGN KEY (AccelerationModelId) REFERENCES Model(ModelId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;


/* =========================================================
   4) CATALOG VIEWS + PROGRAMMABILITY
   ========================================================= */

-- View: Model + Manufacturer + Class
CREATE OR REPLACE VIEW vModelManufacturerClass AS
SELECT
  m.ModelId,
  m.ModelName,
  m.ModelReleaseDate,
  mf.ManufacturerId,
  mf.ManufacturerName,
  c.ClassId,
  c.ClassDesc,
  m.ModelDrivetrain,
  m.ModelTransmissionType,
  m.ModelSeats,
  m.ModelCityMileage,
  m.ModelHighwayMileage,
  m.ModelPrice,
  m.ModelReliabilityScore
FROM Model m
JOIN Manufacturer mf ON mf.ManufacturerId = m.ModelManufacturerId
JOIN Class c ON c.ClassId = m.ModelClassId;

-- View: Model + Engine (through bridge)
CREATE OR REPLACE VIEW vModelEngine AS
SELECT
  m.ModelId,
  m.ModelName,
  e.EngineId,
  e.EngineFuelType,
  ft.FuelTypeDesc,
  e.EnginePower,
  e.EngineConfiguration,
  e.EngineCylinder,
  e.EngineDisplacement,
  e.EngineManufacturerId
FROM ModelEngine me
JOIN Model m ON m.ModelId = me.ModelEngineModelId
JOIN Engine e ON e.EngineId = me.ModelEngineEngineId
JOIN FuelType ft ON ft.FuelType = e.EngineFuelType;

DELIMITER $$

DROP TRIGGER IF EXISTS validate_EnginePower$$
-- Trigger: prevent negative EnginePower (extra validation)
CREATE TRIGGER validate_EnginePower
BEFORE INSERT ON Engine
FOR EACH ROW
BEGIN
  IF NEW.EnginePower < 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'EnginePower cannot be negative.';
  END IF;
END$$

-- Function: average model price by class (catalog, like your original)
DROP FUNCTION IF EXISTS avgPriceByClass$$
CREATE FUNCTION avgPriceByClass(p_classId SMALLINT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE avg_price DECIMAL(12,2);
  SELECT AVG(ModelPrice)
    INTO avg_price
  FROM Model
  WHERE ModelClassId = p_classId
    AND ModelPrice IS NOT NULL;
  RETURN avg_price;
END$$

DELIMITER ;

-- Event: archive/delete old models (catalog, like your original)
-- NOTE: This is destructive; in real life you'd mark inactive instead.
SET GLOBAL event_scheduler = ON;

DELIMITER $$
DROP EVENT IF EXISTS ArchiveOldModels$$
CREATE EVENT ArchiveOldModels
ON SCHEDULE EVERY 1 YEAR
DO
BEGIN
  DELETE FROM Model
  WHERE ModelReleaseDate IS NOT NULL
    AND ModelReleaseDate < (CURDATE() - INTERVAL 20 YEAR);
END$$
DELIMITER ;


/* =========================================================
   5) MARKETPLACE LAYER 
   ========================================================= */

-- Sellers (dealer or private)
CREATE TABLE Seller (
  SellerId BIGINT AUTO_INCREMENT PRIMARY KEY,
  SellerType ENUM('DEALER','PRIVATE') NOT NULL,
  Phone VARCHAR(30),
  Email VARCHAR(120),
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_seller_email (Email)
) ENGINE=InnoDB;

CREATE TABLE Dealer (
  SellerId BIGINT PRIMARY KEY,
  DealerName VARCHAR(120) NOT NULL,
  LicenseNumber VARCHAR(60),
  Website VARCHAR(200),
  FOREIGN KEY (SellerId) REFERENCES Seller(SellerId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE PrivateSeller (
  SellerId BIGINT PRIMARY KEY,
  FullName VARCHAR(120) NOT NULL,
  FOREIGN KEY (SellerId) REFERENCES Seller(SellerId)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Location
CREATE TABLE Location (
  LocationId BIGINT AUTO_INCREMENT PRIMARY KEY,
  CountryCode CHAR(2) NOT NULL DEFAULT 'CA',
  ProvinceState VARCHAR(60),
  City VARCHAR(80),
  PostalCode VARCHAR(20),
  Latitude DECIMAL(9,6),
  Longitude DECIMAL(9,6),
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_location_region (ProvinceState, City),
  INDEX idx_location_city (City)
) ENGINE=InnoDB;

-- VIN-level vehicle (ties the marketplace to your Model catalog)
CREATE TABLE Vehicle (
  VIN CHAR(17) PRIMARY KEY,
  ModelId SMALLINT NOT NULL,
  VehicleYear SMALLINT NOT NULL,
  Trim VARCHAR(60),
  BodyStyle VARCHAR(60),
  ExteriorColor VARCHAR(40),
  InteriorColor VARCHAR(40),
  MileageKm INT NOT NULL DEFAULT 0,
  ConditionType ENUM('NEW','USED','CERTIFIED') NOT NULL DEFAULT 'USED',
  TitleStatus ENUM('CLEAN','REBUILT','SALVAGE','UNKNOWN') NOT NULL DEFAULT 'UNKNOWN',
  AccidentFlag BOOLEAN NOT NULL DEFAULT FALSE,
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT ck_vin_len CHECK (CHAR_LENGTH(VIN) = 17),
  CONSTRAINT ck_vehicle_year CHECK (VehicleYear >= 1980),
  CONSTRAINT ck_vehicle_mileage CHECK (MileageKm >= 0),

  FOREIGN KEY (ModelId) REFERENCES Model(ModelId)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  INDEX idx_vehicle_model_year (ModelId, VehicleYear),
  INDEX idx_vehicle_mileage (MileageKm),
  INDEX idx_vehicle_condition (ConditionType)
) ENGINE=InnoDB;

DELIMITER $$
DROP TRIGGER IF EXISTS vehicle_year_before_insert$$
CREATE TRIGGER vehicle_year_before_insert
BEFORE INSERT ON Vehicle
FOR EACH ROW
BEGIN
  IF NEW.VehicleYear > (YEAR(CURDATE()) + 1) OR NEW.VehicleYear < 1980 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'VehicleYear must be >= 1980 and <= current year + 1';
  END IF;
END$$

DROP TRIGGER IF EXISTS vehicle_year_before_update$$
CREATE TRIGGER vehicle_year_before_update
BEFORE UPDATE ON Vehicle
FOR EACH ROW
BEGIN
  IF NEW.VehicleYear > (YEAR(CURDATE()) + 1) OR NEW.VehicleYear < 1980 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'VehicleYear must be >= 1980 and <= current year + 1';
  END IF;
END$$
DELIMITER ;

-- Listings
CREATE TABLE Listing (
  ListingId BIGINT AUTO_INCREMENT PRIMARY KEY,
  VIN CHAR(17) NOT NULL,
  SellerId BIGINT NOT NULL,
  LocationId BIGINT NOT NULL,

  AskingPrice DECIMAL(12,2) NOT NULL,
  Currency CHAR(3) NOT NULL DEFAULT 'CAD',
  Status ENUM('DRAFT','PENDING','ACTIVE','SOLD','EXPIRED','REMOVED') NOT NULL DEFAULT 'ACTIVE',

  PostedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ExpiresAt TIMESTAMP NULL,
  SoldAt TIMESTAMP NULL,
  Notes TEXT,

  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT ck_listing_price CHECK (AskingPrice > 0),

  FOREIGN KEY (VIN) REFERENCES Vehicle(VIN)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (SellerId) REFERENCES Seller(SellerId)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (LocationId) REFERENCES Location(LocationId)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  INDEX idx_listing_status_price (Status, AskingPrice),
  INDEX idx_listing_posted (PostedAt),
  INDEX idx_listing_vin_status (VIN, Status),
  INDEX idx_listing_location (LocationId)
) ENGINE=InnoDB;

-- Listing photos
CREATE TABLE ListingPhoto (
  PhotoId BIGINT AUTO_INCREMENT PRIMARY KEY,
  ListingId BIGINT NOT NULL,
  PhotoUrl VARCHAR(500) NOT NULL,
  SortOrder INT NOT NULL DEFAULT 0,
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ListingId) REFERENCES Listing(ListingId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_listingphoto_listing_sort (ListingId, SortOrder)
) ENGINE=InnoDB;

-- Price history
CREATE TABLE ListingPriceHistory (
  PriceHistoryId BIGINT AUTO_INCREMENT PRIMARY KEY,
  ListingId BIGINT NOT NULL,
  OldPrice DECIMAL(12,2) NOT NULL,
  NewPrice DECIMAL(12,2) NOT NULL,
  ChangedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (ListingId) REFERENCES Listing(ListingId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_pricehistory_listing_time (ListingId, ChangedAt)
) ENGINE=InnoDB;

-- App users (buyers)
CREATE TABLE AppUser (
  UserId BIGINT AUTO_INCREMENT PRIMARY KEY,
  FullName VARCHAR(120) NOT NULL,
  Email VARCHAR(120) NOT NULL,
  Phone VARCHAR(30),
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_appuser_email (Email)
) ENGINE=InnoDB;

-- Watchlist (favorites)
CREATE TABLE Watchlist (
  UserId BIGINT NOT NULL,
  ListingId BIGINT NOT NULL,
  SavedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (UserId, ListingId),
  FOREIGN KEY (UserId) REFERENCES AppUser(UserId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (ListingId) REFERENCES Listing(ListingId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_watchlist_listing (ListingId)
) ENGINE=InnoDB;

-- Saved searches (store filters as JSON like real marketplaces)
CREATE TABLE SavedSearch (
  SavedSearchId BIGINT AUTO_INCREMENT PRIMARY KEY,
  UserId BIGINT NOT NULL,
  SearchName VARCHAR(80) NOT NULL,
  FiltersJson JSON NOT NULL,
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (UserId) REFERENCES AppUser(UserId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_savedsearch_user (UserId)
) ENGINE=InnoDB;

-- Messaging
CREATE TABLE MessageThread (
  ThreadId BIGINT AUTO_INCREMENT PRIMARY KEY,
  ListingId BIGINT NOT NULL,
  BuyerUserId BIGINT NOT NULL,
  SellerId BIGINT NOT NULL,
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (ListingId) REFERENCES Listing(ListingId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (BuyerUserId) REFERENCES AppUser(UserId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (SellerId) REFERENCES Seller(SellerId)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  UNIQUE KEY uq_thread_unique (ListingId, BuyerUserId, SellerId)
) ENGINE=InnoDB;

CREATE TABLE Message (
  MessageId BIGINT AUTO_INCREMENT PRIMARY KEY,
  ThreadId BIGINT NOT NULL,
  SenderType ENUM('BUYER','SELLER') NOT NULL,
  MessageBody TEXT NOT NULL,
  SentAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (ThreadId) REFERENCES MessageThread(ThreadId)
    ON DELETE CASCADE ON UPDATE CASCADE,

  INDEX idx_message_thread_time (ThreadId, SentAt)
) ENGINE=InnoDB;


/* =========================================================
   6) MARKETPLACE TRIGGERS + VIEWS + FUNCTIONS + EVENTS
   ========================================================= */

DELIMITER $$

-- Prevent multiple ACTIVE listings for the same VIN
DROP TRIGGER IF EXISTS trg_listing_single_active_per_vin$$
CREATE TRIGGER trg_listing_single_active_per_vin
BEFORE INSERT ON Listing
FOR EACH ROW
BEGIN
  IF NEW.Status = 'ACTIVE' THEN
    IF EXISTS (
      SELECT 1 FROM Listing
      WHERE VIN = NEW.VIN AND Status = 'ACTIVE'
      LIMIT 1
    ) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A VIN cannot have more than one ACTIVE listing.';
    END IF;
  END IF;
END$$

-- Track price changes into history
DROP TRIGGER IF EXISTS trg_listing_price_history$$
CREATE TRIGGER trg_listing_price_history
BEFORE UPDATE ON Listing
FOR EACH ROW
BEGIN
  -- Null-safe check (handles NULLs correctly)
  IF NOT (NEW.AskingPrice <=> OLD.AskingPrice) THEN
    INSERT INTO ListingPriceHistory(ListingId, OldPrice, NewPrice)
    VALUES (OLD.ListingId, OLD.AskingPrice, NEW.AskingPrice);
  END IF;
END$$

-- Set SoldAt automatically when status becomes SOLD
DROP TRIGGER IF EXISTS trg_listing_set_soldat$$
CREATE TRIGGER trg_listing_set_soldat
BEFORE UPDATE ON Listing
FOR EACH ROW
BEGIN
  IF NEW.Status = 'SOLD' AND OLD.Status <> 'SOLD' THEN
    SET NEW.SoldAt = COALESCE(NEW.SoldAt, CURRENT_TIMESTAMP);
  END IF;
END$$

DELIMITER ;

-- Search/browse view (powers marketplace search page)
CREATE OR REPLACE VIEW vListingSearch AS
SELECT
  l.ListingId,
  l.Status,
  l.AskingPrice,
  l.Currency,
  l.PostedAt,
  l.ExpiresAt,
  l.SoldAt,

  v.VIN,
  v.VehicleYear,
  v.Trim,
  v.BodyStyle,
  v.ExteriorColor,
  v.InteriorColor,
  v.MileageKm,
  v.ConditionType,
  v.TitleStatus,
  v.AccidentFlag,

  m.ModelName,
  mf.ManufacturerName,
  c.ClassDesc,

  loc.CountryCode,
  loc.ProvinceState,
  loc.City,
  loc.PostalCode,

  s.SellerType
FROM Listing l
JOIN Vehicle v ON v.VIN = l.VIN
JOIN Model m ON m.ModelId = v.ModelId
JOIN Manufacturer mf ON mf.ManufacturerId = m.ModelManufacturerId
JOIN Class c ON c.ClassId = m.ModelClassId
JOIN Location loc ON loc.LocationId = l.LocationId
JOIN Seller s ON s.SellerId = l.SellerId;

DELIMITER $$

-- Function: average ACTIVE listing price by class (market analytics)
DROP FUNCTION IF EXISTS avgActiveListingPriceByClass$$
CREATE FUNCTION avgActiveListingPriceByClass(p_classId SMALLINT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE avg_price DECIMAL(12,2);

  SELECT AVG(l.AskingPrice)
    INTO avg_price
  FROM Listing l
  JOIN Vehicle v ON v.VIN = l.VIN
  JOIN Model m ON m.ModelId = v.ModelId
  WHERE l.Status = 'ACTIVE'
    AND m.ModelClassId = p_classId;

  RETURN avg_price;
END$$
DELIMITER ;

-- Event: expire listings daily if past ExpiresAt (real marketplaces do this)
DELIMITER $$
DROP EVENT IF EXISTS ExpireListingsDaily$$
CREATE EVENT ExpireListingsDaily
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
  UPDATE Listing
  SET Status = 'EXPIRED'
  WHERE Status = 'ACTIVE'
    AND ExpiresAt IS NOT NULL
    AND ExpiresAt < CURRENT_TIMESTAMP;
END$$
DELIMITER ;

DELIMITER $$

CREATE EVENT IF NOT EXISTS ExpireListingsNightly
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE, '02:00:00'))  -- 2am server time
DO
BEGIN
  UPDATE Listing
  SET Status = 'EXPIRED'
  WHERE Status = 'ACTIVE'
    AND ExpiresAt IS NOT NULL
    AND ExpiresAt < NOW();
END$$

DELIMITER ;

DELIMITER $$

DROP EVENT IF EXISTS CleanupOldDraftListingsWeekly$$
CREATE EVENT IF NOT EXISTS CleanupOldDraftListingsWeekly
ON SCHEDULE EVERY 1 WEEK
STARTS (TIMESTAMP(CURRENT_DATE, '03:00:00'))
DO
BEGIN
  DELETE FROM Listing
  WHERE Status IN ('DRAFT','PENDING')
    AND PostedAt < (NOW() - INTERVAL 30 DAY);
END$$

DELIMITER ;

CREATE TABLE IF NOT EXISTS MarketSnapshot (
  SnapshotId BIGINT AUTO_INCREMENT PRIMARY KEY,
  SnapshotAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ActiveListings INT NOT NULL,
  AvgPrice DECIMAL(12,2),
  MedianPrice DECIMAL(12,2),
  AvgMileageKm DECIMAL(12,2)
);

DELIMITER $$

DROP EVENT IF EXISTS CaptureMarketSnapshotDaily$$
CREATE EVENT IF NOT EXISTS CaptureMarketSnapshotDaily
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE, '01:30:00'))
DO
BEGIN
  DECLARE v_active INT;
  DECLARE v_avg_price DECIMAL(12,2);
  DECLARE v_avg_mileage DECIMAL(12,2);
  DECLARE v_median_price DECIMAL(12,2);
  DECLARE v_median_index INT DEFAULT 0;

  SELECT COUNT(*), AVG(AskingPrice), AVG(v.MileageKm)
    INTO v_active, v_avg_price, v_avg_mileage
  FROM Listing l
  JOIN Vehicle v ON v.VIN = l.VIN
  WHERE l.Status = 'ACTIVE';

  -- Median approximation using ordering and OFFSET
  -- Compute an integer offset first (GREATEST() in OFFSET caused parse errors in an event body)
  IF v_active > 0 THEN
    SET v_median_index = FLOOR(v_active / 2);
    IF v_median_index < 0 THEN SET v_median_index = 0; END IF;

    SELECT AskingPrice
      INTO v_median_price
    FROM Listing
    WHERE Status = 'ACTIVE'
    ORDER BY AskingPrice
    LIMIT 1 OFFSET v_median_index;
  ELSE
    SET v_median_price = NULL;
  END IF;

  INSERT INTO MarketSnapshot(ActiveListings, AvgPrice, MedianPrice, AvgMileageKm)
  VALUES (v_active, v_avg_price, v_median_price, v_avg_mileage);
END$$

DELIMITER ;

CREATE TABLE IF NOT EXISTS Notification (
  NotificationId BIGINT AUTO_INCREMENT PRIMARY KEY,
  UserId BIGINT NOT NULL,
  ListingId BIGINT NOT NULL,
  Type ENUM('PRICE_DROP','LISTING_SOLD','LISTING_EXPIRED') NOT NULL,
  PayloadJson JSON,
  CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ReadAt TIMESTAMP NULL,
  FOREIGN KEY (UserId) REFERENCES AppUser(UserId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (ListingId) REFERENCES Listing(ListingId)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_notification_user_time (UserId, CreatedAt)
);

DELIMITER $$

DROP EVENT IF EXISTS NotifyPriceDropsDaily$$
CREATE EVENT IF NOT EXISTS NotifyPriceDropsDaily
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURRENT_DATE, '08:00:00'))
DO
BEGIN
  INSERT INTO Notification (UserId, ListingId, Type, PayloadJson)
  SELECT
    w.UserId,
    lph.ListingId,
    'PRICE_DROP',
    JSON_OBJECT(
      'oldPrice', lph.OldPrice,
      'newPrice', lph.NewPrice,
      'changedAt', lph.ChangedAt
    )
  FROM ListingPriceHistory lph
  JOIN Watchlist w ON w.ListingId = lph.ListingId
  WHERE lph.ChangedAt >= (NOW() - INTERVAL 1 DAY)
    AND lph.NewPrice < lph.OldPrice;
END$$

DELIMITER ;


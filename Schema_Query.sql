-- Create the database
CREATE DATABASE Automobile_DB;
USE Automobile_DB;

-- Create the Manufacturer table to store info of car/engine manufacturers
CREATE TABLE Manufacturer (
    ManufacturerId SMALLINT AUTO_INCREMENT,
    ManufacturerName VARCHAR(25) NOT NULL,
    ManufacturerOrigin VARCHAR(25) NOT NULL,
    ManufacturerFounded DATE NOT NULL,
    ManufacturerFounder LONGTEXT NOT NULL,
    ManufacturerHeadquarter LONGTEXT NOT NULL,
    ManufacturerCompanyType CHAR(1) NOT NULL,
    ManufacturerBrands LONGTEXT,
    ManufacturerParentCompany LONGTEXT,
    PRIMARY KEY (ManufacturerId)
) ENGINE = InnoDB;

-- Create the Class table to store info of car classification 
CREATE TABLE Class (
    ClassId SMALLINT AUTO_INCREMENT,
    ClassDesc VARCHAR(25) NOT NULL,
    PRIMARY KEY (ClassId)
) ENGINE = InnoDB;

-- Create the Engine table to store info of car engines
CREATE TABLE Engine (
    EngineId SMALLINT AUTO_INCREMENT,
    EngineFuelType CHAR(1) NOT NULL,
    EnginePower SMALLINT NOT NULL,
    EngineManufacturerId SMALLINT,
    EngineConfiguration VARCHAR(25),
    EngineCylinder SMALLINT,
    EngineDisplacement SMALLINT,
    PRIMARY KEY (EngineId),
    FOREIGN KEY (EngineManufacturerId) REFERENCES Manufacturer(ManufacturerId)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Create the FuelType lookup table to determine types of fuel for engines
CREATE TABLE FuelType (
    FuelType CHAR(1) NOT NULL,
    FuelTypeDesc VARCHAR(25) NOT NULL,
    PRIMARY KEY (FuelType)
) ENGINE = InnoDB;

-- Create the CompnayType lookup table to determine types of company ownership
CREATE TABLE CompanyType (
    CompanyType CHAR(1) NOT NULL,
    CompanyDesc VARCHAR(25) NOT NULL,
    PRIMARY KEY (CompanyType)
) ENGINE = InnoDB;

-- Create the Model table to store info of specific car models
CREATE TABLE Model (
    ModelId SMALLINT AUTO_INCREMENT,
    ModelName VARCHAR(25) NOT NULL,
    ModelReleaseDate DATE NOT NULL,
    ModelManufacturerId SMALLINT NOT NULL,
    ModelClassId SMALLINT NOT NULL,
    ModelDrivetrain VARCHAR(25) NOT NULL,
    ModelTransmissionType CHAR(1) NOT NULL,
    ModelSeats SMALLINT NOT NULL,
    ModelCityMileage DECIMAL(5,2),
    ModelHighwayMileage DECIMAL(5,2),
    ModelPrice BIGINT,
    ModelReliabilityScore DECIMAL(3,2),
    PRIMARY KEY (ModelId),
    FOREIGN KEY (ModelManufacturerId) REFERENCES Manufacturer(ManufacturerId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ModelClassId) REFERENCES Class(ClassId)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- Create the Speed table to store info of a model's max speed 
CREATE TABLE Speed (
    SpeedModelId SMALLINT AUTO_INCREMENT,
    SpeedMax SMALLINT NOT NULL,
    PRIMARY KEY (SpeedModelId)
) ENGINE = InnoDB;

-- Create the Accekeration table to store info of a model's acceleration
CREATE TABLE Acceleration (
    AccelerationModelId SMALLINT,
    AccelerationZeroToSixty DECIMAL(4,2) NOT NULL,
    AccelerationQuarterMile DECIMAL(4,2) NOT NULL,
    PRIMARY KEY (AccelerationModelId),
    FOREIGN KEY (AccelerationModelId) REFERENCES Model(ModelId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Create the join table ModelEngine table to store info of models and its engine
CREATE TABLE ModelEngine (
    ModelEngineModelId SMALLINT,
    ModelEngineEngineId SMALLINT,
    PRIMARY KEY (ModelEngineModelId, ModelEngineEngineId),
    FOREIGN KEY (ModelEngineModelId) REFERENCES Model(ModelId)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ModelEngineEngineId) REFERENCES Engine(EngineId)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- Create a 3 table view a model, its manufacturer and its class
CREATE VIEW vModelManufacturerClass AS
SELECT
    m.ModelId AS ModelId,
    m.ModelName AS ModelName,
    m.ModelReleaseDate AS ModelReleaseDate,
    m.ModelDrivetrain AS ModelDrivetrain,
    m.ModelTransmissionType AS ModelTransmissionType,
    m.ModelSeats AS ModelSeats,
    m.ModelCityMileage AS ModelCityMileage,
    m.ModelHighwayMileage AS ModelHighwayMileage,
    m.ModelPrice AS ModelPrice,
    m.ModelReliabilityScore AS ModelReliabilityScore,
    ma.ManufacturerId,
    ma.ManufacturerName,
    c.ClassId,
    c.ClassDesc
FROM Model m
JOIN Manufacturer ma ON m.ModelManufacturerId = ma.ManufacturerId
JOIN Class c ON m.ModelClassId = c.ClassId;

-- Create a 2 table view for a model and its engine
CREATE VIEW vModelEngine AS
SELECT
    m.ModelId AS ModelId,
    m.ModelName AS ModelName,
    m.ModelReleaseDate AS ModelReleaseDate,
    m.ModelDrivetrain AS ModelDrivetrain,
    m.ModelTransmissionType AS ModelTransmissionType,
    m.ModelSeats AS ModelSeats,
    m.ModelCityMileage AS ModelCityMileage,
    m.ModelHighwayMileage AS ModelHighwayMileage,
    m.ModelPrice AS ModelPrice,
    m.ModelReliabilityScore AS ModelReliabilityScore,
    e.EngineId,
    e.EngineFuelType,
    e.EnginePower,
    e.EngineManufacturerId,
    e.EngineConfiguration,
    e.EngineCylinder,
    e.EngineDisplacement
FROM Model m
JOIN ModelEngine me ON m.ModelId = me.ModelEngineModelId
JOIN Engine e ON me.ModelEngineEngineId = e.EngineId;

CREATE INDEX idx_manufacturer_name ON Manufacturer (ManufacturerName);
CREATE INDEX idx_model_name ON Model (ModelName);
CREATE INDEX idx_engine_fueltype ON Engine (EngineFuelType);
CREATE INDEX idx_class_desc ON Class (ClassDesc);

CREATE UNIQUE INDEX idvmodelenginex_fuel_type_desc ON FuelType (FuelTypeDesc);
CREATE UNIQUE INDEX idx_company_type_desc ON CompanyType (CompanyDesc);

-- Setting the delimiter for the function
DELIMITER $$

-- Creating the function to calculate average price by class
CREATE FUNCTION avgPriceByClass(class_id SMALLINT) 
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    DECLARE avg_price DECIMAL(10, 2);

    -- Calculate average model price based on class
    SELECT AVG(Model.ModelPrice) INTO avg_price
    FROM Model
    WHERE Model.ModelClassId = class_id;

    -- Return 0 if no average price is found
    RETURN IFNULL(avg_price, 0);
END$$

DELIMITER ;

-- Setting the delimiter for the procedure
DELIMITER $$

-- Creating the procedure to insert a manufacturer
CREATE PROCEDURE InsertManufacturer(
    IN name VARCHAR(25),
    IN origin VARCHAR(25),
    IN founded DATE,
    IN founder LONGTEXT,
    IN headquarter LONGTEXT,
    IN companyType CHAR(1)
)
BEGIN
    -- Insert new manufacturer into the Manufacturer table
    INSERT INTO Manufacturer (ManufacturerName, ManufacturerOrigin, ManufacturerFounded, ManufacturerFounder, ManufacturerHeadquarter, ManufacturerCompanyType)
    VALUES (name, origin, founded, founder, headquarter, companyType);
END$$

DELIMITER ;

-- Setting the delimiter for the trigger
DELIMITER $$

-- Creating the trigger to validate engine power
CREATE TRIGGER validate_EnginePower BEFORE INSERT ON Engine
FOR EACH ROW
BEGIN
    -- Check if EnginePower is negative
    IF NEW.EnginePower < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'EnginePower cannot be negative';
    END IF;
END$$

DELIMITER ;

-- Setting the delimiter for the event
DELIMITER $$

-- Creating the event to archive old models
CREATE EVENT ArchiveOldModels
ON SCHEDULE EVERY 1 YEAR
DO
BEGIN
    -- Delete models older than 20 years
    DELETE FROM Model
    WHERE YEAR(ModelReleaseDate) < YEAR(CURDATE()) - 20;
END$$

DELIMITER ;

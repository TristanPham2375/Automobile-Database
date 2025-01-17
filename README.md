# Automobile-Database

This SQL project defines a relational database schema for storing and managing data about automobile models, their engines, and manufacturers. The design aims to facilitate efficient querying and analysis of automobile-related information such as car model specifications, engine configurations, and manufacturer details. The database has been normalized up to the 4th Normal Form (4NF) to ensure data integrity and minimize redundancy.

## Database Structure

The schema includes several interrelated tables, each representing key entities in the automobile industry:

### `Manufacturer` Table
Stores detailed information about car and engine manufacturers. Attributes include the name, origin, founding date, founder, headquarters, and company type.

### `Class` Table
Represents car model classifications (e.g., sedan, SUV, etc.). Each model is associated with a classification to define its category.

### `Engine` Table
Contains engine specifications, such as fuel type, power, configuration, cylinder count, and displacement. Each engine is linked to a manufacturer.

### `Model` Table
Stores detailed information about specific car models, including the model name, release date, manufacturer, classification, drivetrain, transmission type, seats, fuel efficiency, price, and reliability score.

### `Speed` Table
Contains the maximum speed for each car model.

### `Acceleration` Table
Stores acceleration data for each model, including 0-60 mph and quarter-mile times.

### `ModelEngine` Table
A junction table linking car models to their respective engines, allowing a many-to-many relationship between models and engines.

## Views

### `vModelManufacturerClass` View
A view that combines data from the `Model`, `Manufacturer`, and `Class` tables to provide a comprehensive view of car models, their manufacturers, and classifications.

### `vModelEngine` View
A view that combines data from the `Model`, `Engine`, and `ModelEngine` tables, offering detailed information about car models and their associated engines.

## Functions, Procedures, and Triggers

### `avgPriceByClass` Function
Calculates and returns the average price of car models by class.

### `InsertManufacturer` Procedure
A stored procedure for inserting new manufacturers into the `Manufacturer` table.

### `validate_EnginePower` Trigger
Validates that engine power is not negative before a new engine record is inserted.

### `ArchiveOldModels` Event
An event that runs annually to delete car models older than 20 years from the `Model` table.

## Indexes
To optimize query performance, the following indexes have been created:
- `idx_manufacturer_name`: Index on `ManufacturerName`.
- `idx_model_name`: Index on `ModelName`.
- `idx_engine_fueltype`: Index on `EngineFuelType`.
- `idx_class_desc`: Index on `ClassDesc`.

## Normalization

The schema has been normalized up to the **4th Normal Form (4NF)** to ensure:
- Elimination of redundant data.
- Avoidance of partial and transitive dependencies.
- Minimization of multi-valued dependencies.

This normalization approach helps in maintaining data integrity, ensuring consistency across the database, and improving query performance.



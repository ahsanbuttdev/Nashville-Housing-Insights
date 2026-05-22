-- Create table

drop table property_sales;

CREATE TABLE property_sales (
    unique_id INT PRIMARY KEY,              -- Safe (Pure integer)
    parcel_id VARCHAR(50),                  -- Safe (Alphanumeric text)
    land_use VARCHAR(50),
    property_address VARCHAR(255),
    sale_date VARCHAR(50),                  
    sale_price VARCHAR(50),                 
    legal_reference VARCHAR(50),
    sold_as_vacant VARCHAR(10),
    owner_name VARCHAR(255),
    owner_address VARCHAR(255),
    acreage VARCHAR(50),                    
    tax_district VARCHAR(100),
    land_value INT,                         -- Safe (Pure integers in raw file)
    building_value INT,                     -- Safe
    total_value INT,                        -- Safe
    year_built INT,                         -- Safe
    bedrooms INT,                           -- Safe
    full_bath INT,                          -- Safe
    half_bath INT                           -- Safe
);


-- import data

copy property_sales
from 'D:\presentations\Nashville Housing Data for Data Cleaning.csv'
delimiter ','
csv header

select * from property_sales;


-- date colomn

ALTER TABLE property_sales 
ALTER COLUMN sale_date TYPE DATE 
USING to_date(sale_date, 'Month DD, YYYY');

select sale_date from property_sales;

-- sale price colomm

select sale_price from property_sales;

ALTER TABLE property_sales
ALTER COLUMN sale_price TYPE NUMERIC 
USING (regexp_replace(sale_price, '[^0-9.]', '', 'g'))::numeric;

-- property address

select property_address from property_sales;

select p1.parcel_id, p1.property_address, p2.parcel_id, p2.property_address,
coalesce(p1.property_address, p2.property_address)
from property_sales p1
join property_sales p2
on p1.parcel_id = p2.parcel_id
and p1.unique_id <> p2.unique_id
where p1.property_address is null

UPDATE property_sales p1
SET property_address = p2.property_address
FROM property_sales p2
WHERE p1.parcel_id = p2.parcel_id
  AND p1.unique_id <> p2.unique_id
  AND p1.property_address IS NULL;


-- break into individual parts

ALTER TABLE property_sales 
ADD COLUMN broken_address VARCHAR(255),
ADD COLUMN property_city VARCHAR(100);

UPDATE property_sales
SET 
    broken_address = TRIM(split_part(property_address, ',', 1)),
    property_city = TRIM(split_part(property_address, ',', 2));

SELECT property_address, broken_address, property_city 
FROM property_sales;


-- owner address

update property_sales
set owner_address = property_address || ', TN'
where owner_address is null
and property_address is not null;

select owner_address from property_sales 
where owner_address is null;

-- break owner_address into individual parts

ALTER TABLE property_sales 
ADD COLUMN broken_owner_address VARCHAR(255),
ADD COLUMN owner_property_city VARCHAR(100);

UPDATE property_sales
SET broken_owner_address = TRIM(split_part(owner_address, ',', 1)),
owner_property_city = TRIM(split_part(owner_address, ',', 2));

ALTER TABLE property_sales 
ADD COLUMN owner_state VARCHAR(10);

UPDATE property_sales
SET owner_state = TRIM(split_part(owner_address, ',', 3));


-- change Y and N in sold_as_vacant

update property_sales
set sold_as_vacant =
case 
	when sold_as_vacant = 'Y' then 'Yes'
	when sold_as_vacant = 'N' then 'No'
	else sold_as_vacant
end

select distinct(sold_as_vacant), count(sold_as_vacant) from property_sales
group by sold_as_vacant;



-- remove duplicates

WITH no_duplicate AS (
    SELECT unique_id,
        ROW_NUMBER() OVER ( 
            PARTITION BY parcel_id, property_address, sale_date, sale_price 
            ORDER BY unique_id
        ) as row_num
    FROM property_sales
)
DELETE FROM property_sales
WHERE unique_id IN (
    SELECT unique_id 
    FROM no_duplicate 
    WHERE row_num > 1
);


-- removing unused columns

ALTER TABLE property_sales 
    DROP COLUMN tax_district, 
    DROP COLUMN owner_address;

-- handling null in owner_name

UPDATE property_sales p1
SET owner_name = p2.owner_name
FROM property_sales p2
WHERE p1.property_address = p2.property_address
  AND p1.owner_name IS NULL
  AND p2.owner_name IS NOT NULL;

update property_sales 
set owner_name = 'Unknown Owner'
where owner_name is null

select * from property_sales 

-- acreage 

ALTER TABLE property_sales
ALTER COLUMN acreage TYPE numeric
USING acreage::numeric;



-- creating a view...

drop view properties;

create view properties as(
select unique_id, parcel_id, owner_name, property_city, property_address,
sale_price, sale_date, sold_as_vacant,acreage, land_value, building_value, total_value,
full_bath, half_bath
from property_sales
)

select * from properties;

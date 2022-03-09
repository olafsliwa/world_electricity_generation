--	Overview of data

EXEC sp_rename ['World Energy Consumption$'], energy;

SELECT *
FROM energy;

sp_help energy;


--	Dealing with empty cells, change of the columns data type.
--	(Empty cells wile be treated as NULLS, due to the lack of information)

UPDATE energy SET
electricity_generation = CASE WHEN electricity_generation = '' THEN NULL ELSE electricity_generation END,
coal_electricity = CASE WHEN coal_electricity = '' THEN NULL ELSE coal_electricity END,
oil_electricity = CASE WHEN oil_electricity = '' THEN NULL ELSE oil_electricity END,
gas_electricity = CASE WHEN gas_electricity = '' THEN NULL ELSE gas_electricity END,
nuclear_electricity = CASE WHEN nuclear_electricity = '' THEN NULL ELSE nuclear_electricity END,
biofuel_electricity = CASE WHEN biofuel_electricity = '' THEN NULL ELSE biofuel_electricity END,
hydro_electricity = CASE WHEN hydro_electricity = '' THEN NULL ELSE hydro_electricity END,
solar_electricity = CASE WHEN solar_electricity = '' THEN NULL ELSE solar_electricity END,
wind_electricity = CASE WHEN wind_electricity = '' THEN NULL ELSE wind_electricity END;


--	(Change to number format due to future calculations)

ALTER TABLE energy
ALTER COLUMN electricity_generation float;
ALTER TABLE energy
ALTER COLUMN coal_electricity float;
ALTER TABLE energy
ALTER COLUMN oil_electricity float;
ALTER TABLE energy
ALTER COLUMN gas_electricity float;
ALTER TABLE energy
ALTER COLUMN nuclear_electricity float;
ALTER TABLE energy
ALTER COLUMN biofuel_electricity float;
ALTER TABLE energy
ALTER COLUMN hydro_electricity float;
ALTER TABLE energy
ALTER COLUMN solar_electricity float;
ALTER TABLE energy
ALTER COLUMN wind_electricity float;


--	(Converting units, TWH to kWH)
--	1 TWh = 1 000 000 000 kWh

UPDATE energy
SET
electricity_generation = electricity_generation * 1000000000,
coal_electricity = coal_electricity * 1000000000,
oil_electricity = oil_electricity * 1000000000,
gas_electricity = gas_electricity * 1000000000,
nuclear_electricity = nuclear_electricity * 1000000000,
biofuel_electricity = biofuel_electricity * 1000000000,
hydro_electricity = hydro_electricity * 1000000000,
solar_electricity = solar_electricity * 1000000000,
wind_electricity = wind_electricity * 1000000000;

--	Droping countries that officially did not exist after 2000

SELECT DISTINCT country FROM energy WHERE iso_code='';

DELETE FROM energy
WHERE country in ('Yugoslavia','Czechoslovakia');


--	Creating procedure, which allows to get information about specific country in exact, given year

GO
CREATE PROCEDURE country_detail @state nvarchar(50),@time float
AS
BEGIN
SELECT * 
FROM energy
WHERE country = @state and [year] = @time
END;

EXEC country_detail @state = 'Poland', @time = 2005;


--	Calculating	'Average electricity generation per capita' and 'Average electricity generation per gdp'
--	(Geographical regions are not considered [iso_code != ''], only countries will be examined)

SELECT country, 
ROUND((AVG(electricity_generation)/AVG([population])),0) AS [electricity_percapita_(kWh/person)],
ROUND((AVG(electricity_generation)/AVG(gdp)),2) AS [electricity_pergdp_(kWh/$)]
FROM energy
WHERE iso_code != ''
GROUP BY country
ORDER BY [electricity_percapita_(kWh/person)] DESC, [electricity_pergdp_(kWh/$)];


--	Share of renewable and non-renewable energy sources in total electricity production by countries (in %) in 2010
--	(Renewable sources of energy: biofuel, hydro, solar, and wind; Non-renewable sources: coal, oil, gas and nuclear)
--	(Geographical regions are not considered as well [iso_code != ''] )

WITH electricity_share AS
(SELECT iso_code, country, [year], [population], gdp, electricity_generation,
biofuel_electricity + hydro_electricity + solar_electricity + wind_electricity AS renewable,
coal_electricity + oil_electricity + gas_electricity + nuclear_electricity AS non_renewable
FROM energy)
SELECT country, [year], electricity_generation,
CASE WHEN electricity_generation = 0 THEN 0 ELSE ROUND(((renewable/electricity_generation) * 100),2) END AS [R_%_of_total], 
CASE WHEN electricity_generation = 0 THEN 0 ELSE ROUND(((non_renewable/electricity_generation) * 100),2) END AS [NR_%_of_total]
FROM electricity_share
WHERE [year] = 2010 AND iso_code != ''
ORDER BY [R_%_of_total] DESC;


--	Generation of energy by geographical region (in TWh), year 2010

WITH total_energy AS
(SELECT country as region, electricity_generation, SUM(electricity_generation) OVER () AS total_world_energy_generation
FROM energy
WHERE iso_code = '' and country IN 
('North America','South & Central America','Europe','CIS','Middle East', 'Africa','Asia Pacific') and [year] = 2010)
SELECT region, 
electricity_generation / 1000000000 AS [electricity_generation(TWh)],
total_world_energy_generation / 1000000000 AS [total_world_energy_generation(TWh)],
ROUND(((electricity_generation/total_world_energy_generation) * 100),2) AS [%_of_total]
 FROM total_energy
 ORDER BY [%_of_total] DESC;


--	Annual change of the energy production by country
--	(Geographical regions are not considered [iso_code != ''] )

WITH annual
AS
(SELECT country,[year], electricity_generation, (electricity_generation - LAG(electricity_generation,1) OVER (PARTITION BY country ORDER BY country)) AS change 
FROM energy
WHERE iso_code != '')

SELECT country, [year],
CASE WHEN (LAG(electricity_generation,1) OVER (PARTITION BY country ORDER BY country)) IS NULL  THEN 0
	WHEN (LAG(electricity_generation,1) OVER (PARTITION BY country ORDER BY country)) = 0  THEN 0
	ELSE ROUND((change / (LAG(electricity_generation, 1) OVER (ORDER BY country))*100),2) 
	END AS [annual_%_change]
FROM annual;
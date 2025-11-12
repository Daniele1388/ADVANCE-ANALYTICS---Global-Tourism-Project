-- Retrieve trend data for a given Country, Indicator, and Unit from a dynamic Fact view

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_domestic_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ALBANIA';
DECLARE @Indicator NVARCHAR(100) = 'GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS, PERCENT, AVG_NIGHTS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
SELECT
	y.Year,
	c.Country_name,
	i.Indicator_name,
	m.Measure_Units,
	f.Value
FROM '+ @factView + N' f
INNER JOIN gold.dim_year y
ON f.Year_key = y.Year_key
INNER JOIN gold.dim_country c
ON f.Country_key = c.Country_key
INNER JOIN gold.dim_indicator i
ON f.Indicator_key = i.Indicator_key
INNER JOIN gold.dim_unit_of_measure m
ON f.Units_key = m.Units_key
WHERE c.Country_name = @Country AND i.Indicator_name = @Indicator AND m.Measure_Units = @Units
ORDER BY y.Year;';

EXEC sp_executesql @sql, N'@Country NVARCHAR(50), @Indicator NVARCHAR(100), @Units NVARCHAR(50)', @Country=@Country, @Indicator=@Indicator, @Units=@Units;


-- Retrieve yearly trend data (value, difference, and percent change) 
-- for a given Country, Indicator, and Unit from a dynamic Fact view using parameters.

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_domestic_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ALBANIA';
DECLARE @Indicator NVARCHAR(100) = 'GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS, PERCENT, AVG_NIGHTS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
WITH cte_trend AS
(
	SELECT
		y.Year,
		c.Country_name,
		i.Indicator_name,
		m.Measure_Units,
		f.Value,
		LAG(f.Value) OVER(ORDER BY y.Year) AS Prev_Year
	FROM '+ @factView + N' f
	INNER JOIN gold.dim_year y
	ON f.Year_key = y.Year_key
	INNER JOIN gold.dim_country c
	ON f.Country_key = c.Country_key
	INNER JOIN gold.dim_indicator i
	ON f.Indicator_key = i.Indicator_key
	INNER JOIN gold.dim_unit_of_measure m
	ON f.Units_key = m.Units_key
	WHERE c.Country_name = @Country AND i.Indicator_name = @Indicator AND m.Measure_Units = @Units
)
SELECT
	cte.Year,
	cte.Country_name,
	cte.Indicator_name,
	cte.Measure_Units,
	CAST(cte.Value AS DECIMAL(18,2)) AS Value,
	CAST(cte.Value - cte.Prev_Year AS DECIMAL(18,2)) AS Diff_Prev_Year,
	CAST(ROUND(((cte.Value - cte.Prev_Year)/NULLIF(cte.Prev_Year,0))*100, 2) AS DECIMAL(10,2)) AS Pct_Change 
FROM cte_trend cte
ORDER BY cte.Year;';

EXEC sp_executesql @sql, N'@Country NVARCHAR(50), @Indicator NVARCHAR(100), @Units NVARCHAR(50)', @Country=@Country, @Indicator=@Indicator, @Units=@Units;


-- Retrieve yearly trend data (value) for a given Country and Unit from the SDG Fact table to analyze change over time.

DECLARE @Country NVARCHAR(100) = 'UNITED STATES OF AMERICA'
DECLARE @Units NVARCHAR(50) = 'PERCENT' -- PERCENT, NUMBER
DECLARE @Indicator NVARCHAR(50) = 'SDG_8.9.1_GDP' -- SDG_8.9.2_EMP, SDG_12.b.1_SEEA, SDG_8.9.1_GDP

SELECT
	y.Year,
	c.Country_name,
	f.Indicator,
	m.Measure_Units,
	f.Value
FROM gold.fact_sdg f
INNER JOIN gold.dim_year y
ON f.Year_key = y.Year_key
INNER JOIN gold.dim_country c
ON f.Country_key = c.Country_key
INNER JOIN gold.dim_unit_of_measure m
ON f.Units_key = m.Units_key
WHERE c.Country_name = @Country AND m.Measure_Units = @Units AND f.Indicator = @Indicator
ORDER BY y.Year

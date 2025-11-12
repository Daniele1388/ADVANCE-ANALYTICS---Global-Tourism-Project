-- Retrieve yearly trend for a given Country/Indicator/Unit from a dynamic Fact view, including running total and running average (window functions)

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_domestic_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ITALY';
DECLARE @Indicator NVARCHAR(100) = 'GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
SELECT
	y.Year,
	c.Country_name,
	i.Indicator_name,
	m.Measure_Units,
	CAST(f.Value AS DECIMAL (18,2)) AS Value,
	SUM(f.Value) OVER(ORDER BY y.Year) AS running_total_value,
	CAST(ROUND(AVG(f.Value) OVER(ORDER BY y.Year), 2) AS DECIMAL (10,2)) AS running_avg_value
FROM '+ @factView + N'  f
INNER JOIN gold.dim_year y
ON f.Year_key = y.Year_key
INNER JOIN gold.dim_country c
ON f.Country_key = c.Country_key
INNER JOIN gold.dim_indicator i
ON f.Indicator_key = i.Indicator_key
INNER JOIN gold.dim_unit_of_measure m
ON f.Units_key = m.Units_key
WHERE c.Country_name = @Country AND i.Indicator_name = @Indicator AND m.Measure_Units = @Units;';

EXEC sp_executesql @sql, N'@Country NVARCHAR(50), @Indicator NVARCHAR(100), @Units NVARCHAR(50)', @Country=@Country, @Indicator=@Indicator, @Units=@Units;


-- Retrieve Year-over-Year (YoY) trend for a given Country/Indicator/Unit from a dynamic Fact view,
-- including previous year value, absolute change, and percentage change using window functions (LAG)

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_domestic_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ITALY';
DECLARE @Indicator NVARCHAR(100) = 'GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
SELECT
	y.Year,
	c.Country_name,
	i.Indicator_name,
	m.Measure_Units,
	f.Value,
	LAG(f.Value) OVER(ORDER BY y.Year) AS prev_value,
	f.Value - LAG(f.Value) OVER(ORDER BY y.Year) AS yoy_change,
	CAST(ROUND((f.Value - LAG(f.Value) OVER(ORDER BY y.Year))*100.0/NULLIF(LAG(f.Value) OVER(ORDER BY y.Year),0), 2) AS DECIMAL(10,2)) AS yoy_percent_change
FROM '+ @factView + N' f
INNER JOIN gold.dim_year y
ON f.Year_key = y.Year_key
INNER JOIN gold.dim_country c
ON f.Country_key = c.Country_key
INNER JOIN gold.dim_indicator i
ON f.Indicator_key = i.Indicator_key
INNER JOIN gold.dim_unit_of_measure m
ON f.Units_key = m.Units_key
WHERE c.Country_name = @Country AND i.Indicator_name = @Indicator AND m.Measure_Units = @Units;';

EXEC sp_executesql @sql, N'@Country NVARCHAR(50), @Indicator NVARCHAR(100), @Units NVARCHAR(50)', @Country=@Country, @Indicator=@Indicator, @Units=@Units;
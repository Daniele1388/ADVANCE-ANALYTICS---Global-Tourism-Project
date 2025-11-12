-- Retrieve yearly performance for a given Country/Indicator/Unit from a dynamic Fact view,
-- comparing each year's value against the historical average and previous year (window functions)

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_inbound_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ITALY';
DECLARE @Indicator NVARCHAR(100) = 'AMERICAS'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'

SELECT
	y.Year,
	c.Country_name,
	i.Indicator_name,
	m.Measure_Units,
	f.value,
	CAST(ROUND(AVG(f.Value) OVER(PARTITION BY i.Indicator_name), 2) AS decimal (10,2)) AS avg_value,
	f.value - CAST(ROUND(AVG(f.Value) OVER(PARTITION BY i.Indicator_name), 2) AS decimal (10,2)) AS diff_avg,
	CASE
		WHEN f.value - CAST(ROUND(AVG(f.Value) OVER(PARTITION BY i.Indicator_name), 2) AS decimal (10,2)) > 0 THEN ''ABOVE AVG''
		WHEN f.value - CAST(ROUND(AVG(f.Value) OVER(PARTITION BY i.Indicator_name), 2) AS decimal (10,2)) < 0 THEN ''BELOW AVG''
		ELSE ''AVG''
	END avg_perf_flag,
	LAG(f.value) OVER (ORDER BY y.Year) AS py_value,
	f.value - LAG(f.value) OVER (ORDER BY y.Year) AS diff_py,
	CASE
		WHEN f.value - LAG(f.value) OVER (ORDER BY y.Year) > 0 THEN ''INCREASE''
		WHEN f.value - LAG(f.value) OVER (ORDER BY y.Year) < 0 THEN ''DECREASE''
		ELSE ''NO CHANGE''
	END YoY_trend
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
-- Retrieve yearly performance for a selected Country/Indicator/Unit from a dynamic Fact view,
-- calculating each year's share of the total historical value and flagging the top-performing year (window functions)

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_inbound_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Country NVARCHAR(50) = 'ITALY';
DECLARE @Indicator NVARCHAR(100) = 'TOTAL ARRIVALS'; -- see Indicator Dictionary
DECLARE @Units NVARCHAR(50) = 'THOUSANDS'; -- NUMBER, THOUSANDS, US$ MILLIONS
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'

SELECT
	y.Year,
	c.Country_name,
	i.Indicator_name,
	m.Measure_Units,
	f.Value,
	SUM(f.value) OVER(PARTITION BY c.Country_name, i.Indicator_name) AS total_value,
	CONCAT(CAST(ROUND(f.Value*100.0/NULLIF(SUM(f.value) OVER(PARTITION BY i.Indicator_name),0), 2) AS decimal (10,2)), ''%'') AS pct_of_total,
	CASE
		WHEN ROW_NUMBER() OVER(PARTITION BY c.Country_name, i.Indicator_name ORDER BY f.Value DESC) = 1 THEN ''TOP YEAR''
		ELSE ''''
	END pct_top_flag
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


-- Retrieve the top 10 Countries for a selected Indicator from a dynamic Fact view,
-- computing each Country's total historical value and share of the global total (window functions)

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_inbound_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @Indicator NVARCHAR(100) = 'TOTAL ARRIVALS'; -- see Indicator Dictionary
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
WITH cte_share AS
(
	SELECT
		y.Year,
		c.Country_name,
		i.Indicator_name,
		m.Measure_Units,
		f.Value,
		SUM(f.Value) OVER(PARTITION BY i.Indicator_name) AS total_indicator_value,
		SUM(f.Value) OVER(PARTITION BY c.Country_name, i.Indicator_name) AS total_country_value
	FROM '+ @factView + N' f
	INNER JOIN gold.dim_year y
	ON f.Year_key = y.Year_key
	INNER JOIN gold.dim_country c
	ON f.Country_key = c.Country_key
	INNER JOIN gold.dim_indicator i
	ON f.Indicator_key = i.Indicator_key
	INNER JOIN gold.dim_unit_of_measure m
	ON f.Units_key = m.Units_key
)
SELECT TOP 10
	cte.Country_name,
	cte.Indicator_name,
	cte.Measure_Units,
	cte.total_country_value,
	cte.total_indicator_value,
	CONCAT(CAST(ROUND(cte.total_country_value*100.00/NULLIF(cte.total_indicator_value,0), 2) AS decimal (10,2)), ''%'') AS pct_country_of_total
FROM cte_share cte
WHERE cte.Indicator_name = @Indicator
GROUP BY	cte.Country_name,
			cte.Indicator_name,
			cte.Measure_Units,
			cte.total_country_value,
			cte.total_indicator_value
ORDER BY cte.total_country_value DESC;';

EXEC sp_executesql @sql, N'@Indicator NVARCHAR(100)', @Indicator=@Indicator;
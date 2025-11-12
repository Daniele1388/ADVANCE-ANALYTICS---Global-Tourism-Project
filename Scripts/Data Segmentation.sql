-- Retrieve the list of Indicators available in a selected Fact view,
-- assigning each Indicator to its corresponding Indicator Segment via CASE logic.

DECLARE @factView NVARCHAR(MAX) = N'gold.fact_domestic_tourism'; -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries
DECLARE @sql NVARCHAR(MAX);

SET @sql = N'
SELECT DISTINCT
	i.Indicator_name,
	m.Measure_Units,
		CASE
			-- Volume & Demand
			WHEN i.Indicator_name IN (
			''TOTAL ARRIVALS'', ''TOTAL DEPARTURES'', ''TOTAL TRIPS'', ''OVERNIGHTS VISITORS (TOURISTS)'',
			''SAME-DAY VISITORS (EXCURSIONISTS)'', ''NATIONALS RESIDING ABROAD'', ''CRUISE PASSENGERS'',
			''TOTAL PURPOSE'', ''PERSONAL'', ''BUSINESS AND PROFESSIONAL'') THEN ''VOLUME & DEMAND''

			-- Accommodation & Capacity
			WHEN i.Indicator_name IN (
			''GUESTS (ACCOMMODATION)'',''GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)'',
			''OVERNIGHTS (ACCOMMODATION)'',''OVERNIGHTS (HOTELS AND SIMILAR ESTABLISHMENTS)'') 
			THEN ''ACCOMMODATION & CAPACITY''

			-- Economic & Spending
			WHEN i.Indicator_name IN (
			''TOURISM EXPENDITURE IN THE COUNTRY'',''TOURISM EXPENDITURE IN OTHER COUNTRIES'',
			''TRAVEL'',''PASSENGER TRANSPORT'') THEN ''ECONOMIC & SPENDING''

			-- Transport mode
			WHEN i.Indicator_name IN (''TOTAL TRANSPORT'',''AIR'',''WATER'',''LAND'') THEN ''TRANSPORT MODES''

			-- Source market / Regional flows
			WHEN i.Indicator_name IN (
			''EUROPE'',''AMERICAS'',''AFRICA'',''EAST ASIA AND THE PACIFIC'',
			''SOUTH ASIA'',''MIDDLE EAST'',''TOTAL REGIONS'',''OTHER NOT CLASSIFIED'') THEN ''SOURCE MARKETS''
			
			-- Tourism Industries
			WHEN m.Measure_Units = ''PERCENT'' THEN ''INDUSTRIES | OTHER (PERCENT)''
			WHEN m.Measure_Units = ''AVG_NIGHTS'' THEN ''INDUSTRIES | ACCOMMODATION (AVG_NIGHTS)''
			WHEN i.Indicator_name IN (
			''NUMBER OF ESTABLISHMENTS'',''NUMBER OF ROOMS'',''NUMBER OF BED-PLACES'') 
			THEN ''INDUSTRIES | ACCOMMODATION (NUMBER)''
			WHEN i.Indicator_name = ''AVAILABLE CAPACITY (BED-PLACES PER 1000 INHABITANS)'' THEN ''INDUSTRIES | OTHER (NUMBER)''
			
			ELSE ''OTHER''
		END AS Indicator_Segment
FROM ' + @factView + N' f
INNER JOIN gold.dim_year y
ON f.Year_key = y.Year_key
INNER JOIN gold.dim_country c
ON f.Country_key = c.Country_key
INNER JOIN gold.dim_indicator i
ON f.Indicator_key = i.Indicator_key
INNER JOIN gold.dim_unit_of_measure m
ON f.Units_key = m.Units_key;';

EXEC sp_executesql @sql
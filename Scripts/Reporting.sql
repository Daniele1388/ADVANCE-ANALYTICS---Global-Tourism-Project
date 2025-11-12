/*
========================================================================
VIEW: unify all tourism fact tables into a single source (adds fact_name).
Use it to query Domestic/Inbound/Outbound/Industries together or per fact.

========================================================================
*/

CREATE VIEW gold.vw_fact_tourism_all
AS
SELECT 'fact_domestic_tourism' AS fact_name, Country_key, Indicator_key, Year_key, Units_key, Value FROM gold.fact_domestic_tourism
UNION ALL
SELECT 'fact_inbound_tourism' AS fact_name, Country_key, Indicator_key, Year_key, Units_key, Value FROM gold.fact_inbound_tourism
UNION ALL
SELECT 'fact_outbound_tourism' AS fact_name, Country_key, Indicator_key, Year_key, Units_key, Value FROM gold.fact_outbound_tourism
UNION ALL
SELECT 'fact_tourism_industries' AS fact_name, Country_key, Indicator_key, Year_key, Units_key, Value FROM gold.fact_tourism_industries;
GO

/*
========================================================================
ITVF: compute country market share (%) and assign Segment Tier
within a selected Indicator Segment, optionally filtered by fact.
Params:
	@fact			: 'fact_domestic_tourism' | 'fact_inbound_tourism' | 'fact_outbound_tourism' | 'fact_tourism_industries' | 'ALL'
	@Indicator_seg	: target segment (e.g., 'VOLUME & DEMAND')
Returns:
	Country, Indicator_Segment, Country_seg_total, world_seg_total, share_pct, Segment_Tier
Notes:
   - Tiers via thresholds 5% / 1% / 0.2%
   - Window functions for world totals; safe division with NULLIF
   - ORDER BY to be applied outside the function
========================================================================
*/
CREATE FUNCTION rpt.fn_segment_tier 
(
	@fact NVARCHAR(100) = 'ALL', -- fact_domestic_tourism, fact_inbound_tourism, fact_outbound_tourism, fact_tourism_industries, ALL
	@Indicator_seg NVARCHAR(100)
)
RETURNS TABLE
AS
RETURN
(
	WITH src AS
	(
		SELECT
			*
		FROM gold.vw_fact_tourism_all f
		WHERE @fact = 'ALL' OR f.fact_name = @fact
	),
	cte_indicator_seg AS
    (
        SELECT
            y.Year,
            c.Country_name,
            i.Indicator_name,
            m.Measure_Units,
            f.Value,
            CASE
                -- Volume & Demand
                WHEN i.Indicator_name IN (
                    'TOTAL ARRIVALS','TOTAL DEPARTURES','TOTAL TRIPS','OVERNIGHTS VISITORS (TOURISTS)',
                    'SAME-DAY VISITORS (EXCURSIONISTS)','NATIONALS RESIDING ABROAD','CRUISE PASSENGERS',
                    'TOTAL PURPOSE','PERSONAL','BUSINESS AND PROFESSIONAL'
                ) THEN 'VOLUME & DEMAND'

                -- Accommodation & Capacity
                WHEN i.Indicator_name IN (
                    'GUESTS (ACCOMMODATION)','GUESTS (HOTELS AND SIMILAR ESTABLISHMENTS)',
                    'OVERNIGHTS (ACCOMMODATION)','OVERNIGHTS (HOTELS AND SIMILAR ESTABLISHMENTS)'
                ) THEN 'ACCOMMODATION & CAPACITY'

                -- Economic & Spending
                WHEN i.Indicator_name IN (
                    'TOURISM EXPENDITURE IN THE COUNTRY','TOURISM EXPENDITURE IN OTHER COUNTRIES',
                    'TRAVEL','PASSENGER TRANSPORT'
                ) THEN 'ECONOMIC & SPENDING'

                -- Transport mode
                WHEN i.Indicator_name IN ('TOTAL TRANSPORT','AIR','WATER','LAND') THEN 'TRANSPORT MODES'

                -- Source markets
                WHEN i.Indicator_name IN (
                    'EUROPE','AMERICAS','AFRICA','EAST ASIA AND THE PACIFIC',
                    'SOUTH ASIA','MIDDLE EAST','TOTAL REGIONS','OTHER NOT CLASSIFIED'
                ) THEN 'SOURCE MARKETS'

                -- Tourism Industries
                WHEN m.Measure_Units = 'PERCENT' THEN 'INDUSTRIES | OTHER (PERCENT)'
                WHEN m.Measure_Units = 'AVG_NIGHTS' THEN 'INDUSTRIES | ACCOMMODATION (AVG_NIGHTS)'
                WHEN i.Indicator_name IN ('NUMBER OF ESTABLISHMENTS','NUMBER OF ROOMS','NUMBER OF BED-PLACES')
                    THEN 'INDUSTRIES | ACCOMMODATION (NUMBER)'
                WHEN i.Indicator_name = 'AVAILABLE CAPACITY (BED-PLACES PER 1000 INHABITANTS)'
                    THEN 'INDUSTRIES | OTHER (NUMBER)'
                ELSE 'OTHER'
            END AS Indicator_Segment
        FROM src f
        INNER JOIN gold.dim_year y          ON f.Year_key    = y.Year_key
        INNER JOIN gold.dim_country c       ON f.Country_key = c.Country_key
        INNER JOIN gold.dim_indicator i     ON f.Indicator_key = i.Indicator_key
        INNER JOIN gold.dim_unit_of_measure m ON f.Units_key = m.Units_key
    ),
    cte_agg_country_segment AS 
    (
        SELECT
            ind.Country_name,
            ind.Indicator_Segment,
            ind.Measure_Units,
            SUM(ind.Value) AS Country_seg_total
        FROM cte_indicator_seg ind
        GROUP BY ind.Country_name, ind.Indicator_Segment, ind.Measure_Units
    ),
    cte_global_segment AS
    (
        SELECT
            agg.Country_name,
            agg.Indicator_Segment,
            agg.Country_seg_total,
            SUM(agg.Country_seg_total) OVER (PARTITION BY agg.Indicator_Segment, agg.Measure_Units) AS world_seg_total,
            agg.Country_seg_total*100.00/NULLIF(SUM(agg.Country_seg_total) OVER (PARTITION BY agg.Indicator_Segment, agg.Measure_Units),0) AS share_pct
        FROM cte_agg_country_segment agg
    )
    SELECT
        Country_name  AS Country,
        Indicator_Segment,
        Country_seg_total,
        world_seg_total,
        CAST(share_pct AS DECIMAL(10,2)) AS share_pct,
        CASE
            WHEN Indicator_Segment = 'VOLUME & DEMAND' THEN
                CASE WHEN share_pct >= 5 THEN 'Global Demand Leaders'
                     WHEN share_pct >= 1 THEN 'Strong Demand Markets'
                     WHEN share_pct >= 0.2 THEN 'Emerging Demand Players'
                     WHEN share_pct < 0.2 THEN 'Small Demand Contributors' END
            WHEN Indicator_Segment = 'ACCOMMODATION & CAPACITY' THEN
                CASE WHEN share_pct >= 5 THEN 'Capacity Powerhouse'
                     WHEN share_pct >= 1 THEN 'High-Capacity Market'
                     WHEN share_pct >= 0.2 THEN 'Growing Capacity Market'
                     WHEN share_pct < 0.2 THEN 'Low-Capacity Footprint' END
            WHEN Indicator_Segment = 'ECONOMIC & SPENDING' THEN
                CASE WHEN share_pct >= 5 THEN 'High-Value Market'
                     WHEN share_pct >= 1 THEN 'Strong Value Market'
                     WHEN share_pct >= 0.2 THEN 'Emerging Value Market'
                     WHEN share_pct < 0.2 THEN 'Low Value Footprint' END
            WHEN Indicator_Segment = 'TRANSPORT MODES' THEN
                CASE WHEN share_pct >= 5 THEN 'Global Access Hub'
                     WHEN share_pct >= 1 THEN 'Regional Access Hub'
                     WHEN share_pct >= 0.2 THEN 'Emerging Access Node'
                     WHEN share_pct < 0.2 THEN 'Minor Access Node' END
            WHEN Indicator_Segment = 'SOURCE MARKETS' THEN
                CASE WHEN share_pct >= 5 THEN 'Global Source Magnet'
                     WHEN share_pct >= 1 THEN 'Strong Source Reach'
                     WHEN share_pct >= 0.2 THEN 'Emerging Source Reach'
                     WHEN share_pct < 0.2 THEN 'Narrow Source Reach' END
            WHEN Indicator_Segment = 'INDUSTRIES | ACCOMMODATION (NUMBER)' THEN
                CASE WHEN share_pct >= 5 THEN 'Tourism Industry Leaders'
                     WHEN share_pct >= 1 THEN 'Strong Industry Markets'
                     WHEN share_pct >= 0.2 THEN 'Emerging Industry Players'
                     WHEN share_pct < 0.2 THEN 'Small Industry Footprint' END
            ELSE ''
        END AS Segment_Tier
    FROM cte_global_segment
    WHERE Indicator_Segment = @Indicator_seg
);
GO

========================================================================
/*
Example: rank countries for the inbound 'VOLUME & DEMAND' segment.
Tip: add ORDER BY Country_seg_total DESC in the outer SELECT if needed.
*/
========================================================================

SELECT
	*
FROM rpt.fn_segment_tier('fact_inbound_tourism', 'VOLUME & DEMAND')
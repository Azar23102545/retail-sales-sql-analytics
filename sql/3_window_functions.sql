-- Analyser som bygger på window functions:
-- ranking, tillväxt över tid, topp N per grupp och intervall mellan köp

-- Kundernas livstidsvärde med rank och decilindelning
WITH customer_value AS (
    SELECT
        customer_id,
        country,
        COUNT(DISTINCT invoice_no) AS antal_ordrar,
        ROUND(SUM(revenue), 2) AS livstidsvarde,
        ROUND(AVG(revenue), 2) AS snitt_radvarde,
        MIN(CAST(invoice_date AS DATE)) AS forsta_kop,
        MAX(CAST(invoice_date AS DATE)) AS senaste_kop
    FROM fact_sales
    WHERE customer_id IS NOT NULL
      AND NOT is_cancellation
    GROUP BY customer_id, country
)
SELECT
    RANK() OVER (ORDER BY livstidsvarde DESC) AS rang,
    customer_id,
    country,
    antal_ordrar,
    livstidsvarde,
    NTILE(10) OVER (ORDER BY livstidsvarde DESC) AS decil,
    ROUND(100.0 * livstidsvarde / SUM(livstidsvarde) OVER (), 3) AS andel_av_total_pct
FROM customer_value
ORDER BY livstidsvarde DESC
LIMIT 20;


-- Månad över månad: förändring, tillväxt i procent och ackumulerad intäkt.
-- NULLIF används för att undvika division med noll första månaden.
WITH monthly AS (
    SELECT
        d.month_start AS manad,
        SUM(f.revenue) AS intakt
    FROM fact_sales f
    JOIN dim_date d ON f.date_key = d.date_key
    WHERE NOT f.is_cancellation
    GROUP BY d.month_start
)
SELECT
    manad,
    ROUND(intakt, 0) AS intakt,
    ROUND(LAG(intakt) OVER (ORDER BY manad), 0) AS foregaende_manad,
    ROUND(intakt - LAG(intakt) OVER (ORDER BY manad), 0) AS forandring,
    ROUND(100.0 * (intakt - LAG(intakt) OVER (ORDER BY manad)) / NULLIF(LAG(intakt) OVER (ORDER BY manad), 0), 1) AS tillvaxt_pct,
    ROUND(SUM(intakt) OVER (ORDER BY manad ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS ackumulerat
FROM monthly
ORDER BY manad;


-- Topp 3 produkter per land, begränsat till de åtta största marknaderna
WITH product_by_country AS (
    SELECT
        f.country,
        p.description AS produkt,
        SUM(f.revenue) AS intakt
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    WHERE NOT f.is_cancellation
    GROUP BY f.country, p.description
),
ranked AS (
    SELECT
        country,
        produkt,
        ROUND(intakt, 0) AS intakt,
        RANK() OVER (PARTITION BY country ORDER BY intakt DESC) AS rang_i_land
    FROM product_by_country
),
top_countries AS (
    SELECT country
    FROM fact_sales
    WHERE NOT is_cancellation
    GROUP BY country
    ORDER BY SUM(revenue) DESC
    LIMIT 8
)
SELECT r.*
FROM ranked r
JOIN top_countries t USING (country)
WHERE r.rang_i_land <= 3
ORDER BY r.country, r.rang_i_land;


-- Hur ofta återkommer kunderna? LAG över varje kunds orderhistorik
-- ger antal dagar mellan köp.
WITH order_dates AS (
    SELECT DISTINCT
        customer_id,
        CAST(invoice_date AS DATE) AS orderdatum
    FROM fact_sales
    WHERE customer_id IS NOT NULL AND NOT is_cancellation
),
gaps AS (
    SELECT
        customer_id,
        orderdatum,
        LAG(orderdatum) OVER (PARTITION BY customer_id ORDER BY orderdatum) AS foregaende_order,
        DATE_DIFF('day', LAG(orderdatum) OVER (PARTITION BY customer_id ORDER BY orderdatum), orderdatum) AS dagar_mellan
    FROM order_dates
)
SELECT
    customer_id,
    COUNT(*) + 1 AS antal_ordrar,
    ROUND(AVG(dagar_mellan), 1) AS snitt_dagar_mellan_kop,
    MIN(dagar_mellan) AS kortaste_intervall,
    MAX(dagar_mellan) AS langsta_intervall
FROM gaps
WHERE dagar_mellan IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) >= 4
ORDER BY snitt_dagar_mellan_kop ASC
LIMIT 20;
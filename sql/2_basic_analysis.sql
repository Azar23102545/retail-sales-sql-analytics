-- Grundläggande analyser: KPI:er, intäkt över tid, produkter, geografi

-- Övergripande nyckeltal för hela datasetet
SELECT
    COUNT(DISTINCT invoice_no) AS antal_ordrar,
    COUNT(DISTINCT customer_id) AS antal_kunder,
    COUNT(DISTINCT product_key) AS antal_produkter,
    ROUND(SUM(revenue), 0) AS total_intakt,
    ROUND(SUM(revenue) / COUNT(DISTINCT invoice_no), 2) AS snitt_ordervarde,
    ROUND(100.0 * SUM(CASE WHEN is_cancellation THEN 1 ELSE 0 END) / COUNT(*), 2) AS makulering_pct
FROM fact_sales;


-- Intäkt, ordrar och aktiva kunder per månad
SELECT
    d.month_start AS manad,
    ROUND(SUM(f.revenue), 0) AS intakt,
    COUNT(DISTINCT f.invoice_no) AS ordrar,
    COUNT(DISTINCT f.customer_id) AS aktiva_kunder
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE NOT f.is_cancellation
GROUP BY d.month_start
ORDER BY d.month_start;


-- Topp 10 produkter efter intäkt
SELECT
    p.description AS produkt,
    SUM(f.quantity) AS antal_salda,
    ROUND(SUM(f.revenue), 0) AS intakt,
    COUNT(DISTINCT f.customer_id) AS unika_kunder
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
WHERE NOT f.is_cancellation
GROUP BY p.description
ORDER BY intakt DESC
LIMIT 10;


-- Intäkt per land. Andelen räknas ut med en window function
-- ovanpå aggregeringen, utan subquery.
SELECT
    country AS land,
    COUNT(DISTINCT customer_id) AS kunder,
    COUNT(DISTINCT invoice_no) AS ordrar,
    ROUND(SUM(revenue), 0) AS intakt,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS andel_av_total_pct
FROM fact_sales
WHERE NOT is_cancellation
GROUP BY country
ORDER BY intakt DESC
LIMIT 15;


-- Intäkt per timme på dygnet
SELECT
    EXTRACT(hour FROM invoice_date) AS timme,
    COUNT(DISTINCT invoice_no) AS ordrar,
    ROUND(SUM(revenue), 0) AS intakt
FROM fact_sales
WHERE NOT is_cancellation
GROUP BY timme
ORDER BY timme;


-- Intäkt per veckodag
SELECT
    d.day_name AS veckodag,
    d.day_of_week,
    ROUND(SUM(f.revenue), 0) AS intakt
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE NOT f.is_cancellation
GROUP BY d.day_name, d.day_of_week
ORDER BY d.day_of_week;
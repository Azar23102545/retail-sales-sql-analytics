-- Analytiska views som återanvändbart lager ovanpå star schemat

-- Nyckeltal per månad
CREATE OR REPLACE VIEW v_monthly_kpi AS
SELECT
    d.month_start AS manad,
    COUNT(DISTINCT f.invoice_no) AS ordrar,
    COUNT(DISTINCT f.customer_id) AS aktiva_kunder,
    SUM(f.revenue) AS intakt,
    SUM(f.revenue) / COUNT(DISTINCT f.invoice_no) AS snitt_ordervarde
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
WHERE NOT f.is_cancellation
GROUP BY d.month_start;


-- RFM-poäng per kund, utan segmentindelningen
CREATE OR REPLACE VIEW v_customer_rfm AS
WITH snapshot AS (
    SELECT MAX(invoice_date) + INTERVAL 1 DAY AS snapshot_date FROM fact_sales
),
base AS (
    SELECT
        customer_id,
        DATE_DIFF('day', MAX(CAST(invoice_date AS DATE)), CAST((SELECT snapshot_date FROM snapshot) AS DATE)) AS recency,
        COUNT(DISTINCT invoice_no) AS frequency,
        SUM(revenue) AS monetary
    FROM fact_sales
    WHERE customer_id IS NOT NULL AND NOT is_cancellation
    GROUP BY customer_id
    HAVING SUM(revenue) > 0
)
SELECT
    *,
    NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
FROM base;


-- Försäljning, returer och intäkt per produkt
CREATE OR REPLACE VIEW v_product_performance AS
SELECT
    p.stock_code,
    p.description,
    SUM(CASE WHEN NOT f.is_cancellation THEN f.quantity ELSE 0 END) AS antal_salda,
    SUM(CASE WHEN f.is_cancellation THEN ABS(f.quantity) ELSE 0 END) AS antal_returer,
    SUM(CASE WHEN NOT f.is_cancellation THEN f.revenue ELSE 0 END) AS intakt,
    COUNT(DISTINCT f.customer_id) AS unika_kunder
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.stock_code, p.description;

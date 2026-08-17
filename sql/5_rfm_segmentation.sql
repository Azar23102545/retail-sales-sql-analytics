-- RFM-segmentering i ren SQL.
-- Recency, Frequency och Monetary poängsätts 1-5 med NTILE och
-- kombineras till affärsanvändbara segment.

WITH snapshot AS (
    SELECT MAX(invoice_date) + INTERVAL 1 DAY AS snapshot_date
    FROM fact_sales
),
customer_rfm AS (
    SELECT
        f.customer_id,
        DATE_DIFF('day', MAX(CAST(f.invoice_date AS DATE)), CAST((SELECT snapshot_date FROM snapshot) AS DATE)) AS recency,
        COUNT(DISTINCT f.invoice_no) AS frequency,
        ROUND(SUM(f.revenue), 2) AS monetary
    FROM fact_sales f
    WHERE f.customer_id IS NOT NULL
      AND NOT f.is_cancellation
    GROUP BY f.customer_id
    HAVING SUM(f.revenue) > 0
),
scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    r_score, f_score, m_score,
    CAST(r_score AS VARCHAR) || CAST(f_score AS VARCHAR) || CAST(m_score AS VARCHAR) AS rfm_kod,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Lojala kunder'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Nya kunder'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'Riskerar att lämna'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 4 THEN 'Förlorade högvärdeskunder'
        WHEN r_score <= 2 THEN 'Vilande'
        ELSE 'Behöver uppmärksamhet'
    END AS segment
FROM scored
ORDER BY monetary DESC;

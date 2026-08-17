-- Kohortanalys: hur stor andel av varje månadskohort som återkommer.
-- Kunderna grupperas efter månaden för sitt första köp. För varje
-- efterföljande månad räknas hur många av gruppen som handlade igen.

WITH first_purchase AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM fact_sales
    WHERE customer_id IS NOT NULL AND NOT is_cancellation
    GROUP BY customer_id
),
customer_activity AS (
    SELECT DISTINCT
        f.customer_id,
        fp.cohort_month,
        DATE_TRUNC('month', f.invoice_date) AS activity_month
    FROM fact_sales f
    JOIN first_purchase fp USING (customer_id)
    WHERE NOT f.is_cancellation
),
cohort_matrix AS (
    SELECT
        cohort_month,
        DATE_DIFF('month', cohort_month, activity_month) AS manad_index,
        COUNT(DISTINCT customer_id) AS aktiva_kunder
    FROM customer_activity
    GROUP BY cohort_month, manad_index
),
-- Kohortens storlek är antalet aktiva vid index 0, alltså startmånaden
cohort_size AS (
    SELECT
        cohort_month,
        aktiva_kunder AS kohortstorlek
    FROM cohort_matrix
    WHERE manad_index = 0
)
SELECT
    cm.cohort_month,
    cs.kohortstorlek,
    cm.manad_index,
    cm.aktiva_kunder,
    ROUND(100.0 * cm.aktiva_kunder / cs.kohortstorlek, 1) AS retention_pct
FROM cohort_matrix cm
JOIN cohort_size cs USING (cohort_month)
ORDER BY cm.cohort_month, cm.manad_index;

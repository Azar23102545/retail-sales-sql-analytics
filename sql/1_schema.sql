-- Star schema: dimensionstabeller och faktatabell
-- Byggs i notebooks/build_database.ipynb från staging-tabellen

-- Produktdimension. Samma stock_code har ibland flera beskrivningar,
-- så vi väljer den som förekommer oftast.
CREATE OR REPLACE TABLE dim_product AS
WITH ranked AS (
    SELECT
        stock_code,
        description,
        COUNT(*) AS n,
        ROW_NUMBER() OVER (
            PARTITION BY stock_code
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM staging
    GROUP BY stock_code, description
)
SELECT
    ROW_NUMBER() OVER (ORDER BY stock_code) AS product_key,
    stock_code,
    description
FROM ranked
WHERE rn = 1;


-- Kunddimension. Samma princip, väljer det land som förekommer oftast per kund.
CREATE OR REPLACE TABLE dim_customer AS
WITH ranked AS (
    SELECT
        customer_id,
        country,
        COUNT(*) AS n,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM staging
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id, country
)
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    country
FROM ranked
WHERE rn = 1;


-- Datumdimension
CREATE OR REPLACE TABLE dim_date AS
WITH all_dates AS (
    SELECT DISTINCT CAST(invoice_date AS DATE) AS full_date
    FROM staging
)
SELECT
    CAST(STRFTIME(full_date, '%Y%m%d') AS INTEGER) AS date_key,
    full_date,
    EXTRACT(year FROM full_date) AS year,
    EXTRACT(quarter FROM full_date) AS quarter,
    EXTRACT(month FROM full_date) AS month,
    STRFTIME(full_date, '%B') AS month_name,
    EXTRACT(day FROM full_date) AS day_of_month,
    EXTRACT(dow FROM full_date) AS day_of_week,
    STRFTIME(full_date, '%A') AS day_name,
    CASE WHEN EXTRACT(dow FROM full_date) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    DATE_TRUNC('month', full_date) AS month_start
FROM all_dates
ORDER BY full_date;


-- Faktatabell med transaktionsrader
CREATE OR REPLACE TABLE fact_sales AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.invoice_date, s.invoice_no) AS sales_key,
    s.invoice_no,
    p.product_key,
    c.customer_key,
    CAST(STRFTIME(CAST(s.invoice_date AS DATE), '%Y%m%d') AS INTEGER) AS date_key,
    s.invoice_date,
    s.customer_id,
    s.country,
    s.quantity,
    s.unit_price,
    s.revenue,
    s.is_cancellation
FROM staging s
LEFT JOIN dim_product p ON s.stock_code = p.stock_code
LEFT JOIN dim_customer c ON s.customer_id = c.customer_id;
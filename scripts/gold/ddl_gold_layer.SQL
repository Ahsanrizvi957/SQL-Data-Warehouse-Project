/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

DROP VIEW IF EXISTS gold.dim_customers;

CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key, -- surrogate key
	m.cst_id                            AS customer_id,
	m.cst_key 							AS customer_number,
	m.cst_firstname 					AS first_name,
	m.cst_lastname 						AS last_name,
	c2.cntry 							AS country,
	m.cst_marital_status 				AS marital_status,
	CASE WHEN m.cst_gndr != 'n/a' THEN m.cst_gndr
		 ELSE COALESCE (c1.gen,'n/a')
    END AS gender,
	c1.bdate 							AS birth_date,
	m.cst_create_date				    AS create_date
FROM silver.crm_cust_info AS m
LEFT JOIN silver.erp_cust_az12 AS c1
ON 		  m.cst_key = c1.cid
LEFT JOIN silver.erp_loc_a101 AS c2
ON 	 	  m.cst_key = c2.cid;

DROP VIEW IF EXISTS gold.dim_products;

CREATE VIEW gold.dim_products AS 
SELECT
ROW_NUMBER() OVER (ORDER BY mp.prd_key,pc,prd_start_dt) AS product_key, --surrogate key
mp.prd_id 												AS product_id,
mp.prd_key 												AS product_number,
mp.prd_nm 												AS product_name,
mp.cat_id 												AS category_id,
pc.cat													AS category,
pc.subcat												AS sub_category,
pc.maintenance,
mp.prd_line 											AS product_line,
mp.prd_cost 											AS cost,
mp.prd_start_dt 										AS start_date
FROM silver.crm_prd_info AS mp
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON  	  mp.cat_id = pc.id
WHERE prd_end_dt IS NULL -- filter out historical records



DROP VIEW IF EXISTS gold.fact_sales;

CREATE VIEW gold.fact_sales AS
SELECT
sf.sls_ord_num 		AS order_number,
dp.product_key ,
dc.customer_key,
sf.sls_order_dt 	AS order_date,
sf.sls_ship_dt  	AS shipping_date,
sf.sls_due_dt 		AS due_date,
sf.sls_sales 		AS sales_amount,
sf.sls_quantity 	AS quantity,
sf.sls_price	    AS price
FROM silver.crm_sales_details AS sf
LEFT JOIN gold.dim_products AS dp
ON 		  sf.sls_prd_key = dp.product_number
LEFT JOIN gold.dim_customers AS dc
ON 		  CAST(sf.sls_cust_id AS INTEGER) = dc.customer_id 

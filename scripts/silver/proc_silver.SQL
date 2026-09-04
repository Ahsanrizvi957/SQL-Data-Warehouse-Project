/*
=============================================================================
Script Purpose:
    This script performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		- This sript also shows how much time would it take to load data from bronze to silver layer.
		- I used exception handling in this ETL procedure to make troubleshooting easier.		
===============================================================================
*/



CREATE OR REPLACE PROCEDURE silver.silver_load()
LANGUAGE plpgsql
AS $$

DECLARE 
		batch_start_time TIMESTAMP;
		batch_end_time 	 TIMESTAMP;
		start_time		 TIMESTAMP;
		end_time  		 TIMESTAMP;
		error_message    TEXT;
		error_detail	 TEXT;
		error_hint		 TEXT;

BEGIN

	batch_start_time := clock_timestamp();
	
	RAISE NOTICE'==============================================';
	RAISE NOTICE 'Loading silver layer';
	RAISE NOTICE'==============================================';

	RAISE NOTICE '=================CRM TABLES===================';

	start_time := clock_timestamp();
	
	RAISE NOTICE '>> Truncating table: silver.crm_cust_info';
	TRUNCATE silver.crm_cust_info;
	RAISE NOTICE '>> Inserting data into: silver.crm_cust_info';
	INSERT INTO silver.crm_cust_info(
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_marital_status,
	cst_gndr,
	cst_create_date
	)
	SELECT
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname, -- remove unwanted spaces
	TRIM(cst_lastname) AS cst_lastname,   -- remove unwanted spaces
	CASE
		WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		ELSE 'n/a'
	END AS cst_marital_status, -- normalize marital status to readable form
	CASE
		WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		ELSE 'n/a'
	END AS cst_gndr,-- normalize gender to readable form
	cst_create_date
	FROM (
		SELECT
		*,
		ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rn
		FROM bronze.crm_cust_info) t where rn = 1 AND cst_id != 0 AND cst_id IS NOT NULL; -- select recent record
		
		end_time := clock_timestamp();
		RAISE NOTICE '>> Loading duration: % seconds',
			  EXTRACT(EPOCH FROM(end_time - start_time));

	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.crm_prd_info';
	TRUNCATE silver.crm_prd_info;
	RAISE NOTICE '>> Inserting data into: silver.crm_prd_info';
	INSERT INTO silver.crm_prd_info(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt)
	SELECT
	prd_id,
	REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id, -- Exract cataegory ID
	SUBSTRING(prd_key,7,length(prd_key)) AS prd_key,   -- Extract product key
	prd_nm,
	COALESCE(prd_cost,0) AS prd_cost,
	CASE
		WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
	    WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other sales'
	    WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
	    WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
	    ELSE 'n/a'
	END AS prd_line, -- Map product line to descriptive name
	prd_start_dt,
	(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - INTERVAL '1 day') AS prd_end_date
	FROM bronze.crm_prd_info; -- calculate end date as one day before start date
	end_time := clock_timestamp();

	RAISE NOTICE '>> Loading duration:= % seconds',
		  EXTRACT(EPOCH FROM(end_time - start_time));
	
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.crm_sales_details';
	TRUNCATE silver.crm_sales_details;
	RAISE NOTICE '>> Inserting data into: silver.crm_sales_details';
	INSERT INTO silver.crm_sales_details(
	
	sls_ord_num,  
	sls_prd_key,   
	sls_cust_id,  
	sls_order_dt,  
	sls_ship_dt,   
	sls_due_dt,    
	sls_sales,     
	sls_quantity,  
	sls_price     
	)
	
	SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE 
		 WHEN sls_order_dt = '0' OR LENGTH(sls_order_dt) != '8' THEN NULL
		 ELSE CAST(sls_order_dt AS DATE)  
	END sls_order_dt, -- correct the dates if there is 0 and length is not equal to 8
	
	CASE 
		 WHEN sls_ship_dt = '0' OR LENGTH(sls_ship_dt) != '8' THEN NULL
		 ELSE CAST(sls_ship_dt AS DATE)  
	END sls_ship_dt,
	
	CASE 
		 WHEN sls_due_dt = '0' OR LENGTH(sls_due_dt) != '8' THEN NULL
		 ELSE CAST(sls_due_dt AS DATE)  
	END sls_due_dt,
	
	CASE 
		 WHEN sls_sales <=0 OR sls_sales IS NULL OR sls_sales != sls_quantity * ABS(sls_price) 
		 THEN sls_quantity * ABS(sls_price)
		 ELSE sls_sales
	END AS sls_sales, -- recalculating sales if original value is missing or incorrect
	
	sls_quantity,
	CASE 
		 WHEN sls_price <=0 OR sls_price IS NULL OR sls_price != sls_sales/sls_quantity
		 THEN sls_sales/NULLIF(sls_quantity,0) 
		 ELSE sls_price
	END AS sls_price -- recalculating price if original value is missing or incorrect
	FROM bronze.crm_sales_details;
	
	end_time := clock_timestamp();
	RAISE NOTICE '>> Loading duration:= % seconds',
		  EXTRACT(EPOCH FROM(end_time - start_time));

	RAISE NOTICE '=====================ERP TABLES======================';
	
	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12; 
	RAISE NOTICE '>> Inserting data into: silver.erp_cust_az12';
	INSERT INTO silver.erp_cust_az12(
	cid,
	bdate,
	gen
	)
	SELECT 
	CASE 
		 WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4,length(cid))
		 ELSE cid
	END AS cid, -- removing NAS prefix from cid
	
	CASE 
		 WHEN bdate !~'^\d{4}-\d{2}-\d{2}$' THEN NULL
		 WHEN CAST(bdate AS DATE) > current_date THEN NULL
		 ELSE CAST(bdate AS DATE)
	END AS bdate, /* use regex to identify the incorrect date format then change the data type of bdate (text to DATE)
	and set the future dates to null*/
	
	CASE
		 WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M','MALE') 	 THEN 'Male'
		 ELSE 'n/a'
	END AS gen -- normalize gender values and handle unkwon nulls
	FROM bronze.erp_cust_az12;
	end_time := clock_timestamp();
	RAISE NOTICE '>> Loading duration:= % seconds',
		  EXTRACT (EPOCH FROM(end_time - start_time));

	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	RAISE NOTICE '>> Inserting data into: silver.erp_loc_a101';
	INSERT INTO silver.erp_loc_a101(
	
	cid,
	cntry
	)
	
	SELECT 
	REPLACE(cid,'-','') AS cid, -- remove '-' from cid
	CASE 
		 WHEN TRIM(cntry) ='DE' THEN 'Germany'
		 WHEN TRIM(cntry)IN ('US','USA') THEN 'United states'
		 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END AS cntry -- normailze and handle missing or blank country code
	FROM bronze.erp_loc_A101;
	end_time := clock_timestamp();
	RAISE NOTICE '>> Loading duration:= % seconds',
		  EXTRACT (EPOCH FROM(end_time - start_time));

	start_time := clock_timestamp();
	RAISE NOTICE '>> Truncating table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	RAISE NOTICE '>> Inserting data into: silver.erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2(
	id,
	cat,
	subcat,
	maintenance
	)
	SELECT
	id,
	cat,
	subcat,
	maintenance
	FROM bronze.erp_px_cat_g1v2;

	end_time := clock_timestamp();
	RAISE NOTICE '>> Loading duration:= % seconds',
		  EXTRACT(EPOCH FROM (end_time - start_time));

	batch_end_time := clock_timestamp();
	
	RAISE NOTICE'==============================================';
	RAISE NOTICE 'Total loading duration:= % seconds',
		  EXTRACT (EPOCH FROM(batch_end_time - batch_start_time));
	RAISE NOTICE'==============================================';

	EXCEPTION 
		WHEN OTHERS THEN
				
				GET STACKED DIAGNOSTICS

				error_message = MESSAGE_TEXT,
				error_detail  = PG_EXCEPTION_DETAIL,
				error_hint    = PG_EXCEPTION_HINT;

	RAISE NOTICE '=========================================================';
	RAISE NOTICE 'ERROR OCCURED DURING SILVER LOADING';
	RAISE NOTICE '=========================================================';

	RAISE NOTICE 'error_message: %', error_message;
	RAISE NOTICE 'error_detail: %', error_detail;
	RAISE NOTICE 'error_message: %', error_hint;

	RAISE;
			
				

END $$;

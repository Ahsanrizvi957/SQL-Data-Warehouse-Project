
CREATE OR REPLACE PROCEDURE bronze.bronze_load()
LANGUAGE plpgsql
AS $$

DECLARE
    batch_start_time TIMESTAMP;
    batch_end_time   TIMESTAMP;
    start_time       TIMESTAMP;
    end_time         TIMESTAMP;
	error_message 	 TEXT;
	error_detail	 TEXT;
	error_hint       TEXT;

BEGIN

    batch_start_time := clock_timestamp();

    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Loading bronze layer';
    RAISE NOTICE '=================================================================';


    RAISE NOTICE'==================== CRM CUSTOMER =======================';

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.crm_cust_info;

    COPY bronze.crm_cust_info
    FROM 'C:\Users\ahsan\Downloads\cust_info.csv'
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'crm_cust_info loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    -- ======================= CRM PRODUCTS =======================

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.crm_prd_info;

    COPY bronze.crm_prd_info
    FROM 'C:\Users\ahsan\Downloads\prd_info.csv'
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'crm_prd_info loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    -- ======================= CRM SALES =======================

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.crm_sales_details;

    COPY bronze.crm_sales_details
    FROM 'C:\Users\ahsan\Downloads\sales_details.csv'
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'crm_sales_details loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    RAISE NOTICE'==================== ERP CUSTOMER =======================';

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.erp_cust_az12;

    COPY bronze.erp_cust_az12
    FROM  'C:\Users\ahsan\Downloads\cust_AZ12.csv'
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'erp_CUST_AZ12 loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    -- ======================= ERP LOCATION =======================

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.erp_loc_a101;

    COPY bronze.erp_loc_a101
    FROM  'C:\Users\ahsan\Downloads\loc_A101.csv'
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'erp_LOC_A101 loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    -- ======================= ERP PRODUCT CATEGORY =======================

    start_time := clock_timestamp();

    TRUNCATE TABLE bronze.erp_px_cat_g1v2;

    COPY bronze.erp_px_cat_g1v2
    FROM 'C:\Users\ahsan\Downloads\PX_CAT_G1V2.csv' 
    WITH (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        QUOTE '"'
    );

    end_time := clock_timestamp();

    RAISE NOTICE 'erp_PX_CAT_G1V2 loading duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));


    -- ============================== END BATCH ==============================

    batch_end_time := clock_timestamp();

    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Total loading duration: % seconds',
        EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
    RAISE NOTICE '=================================================================';

	-- ================================EXCEPTION===================================
	EXCEPTION
		WHEN OTHERS THEN

			GET STACKED DIAGNOSTICS
			error_message = MESSAGE_TEXT;
			error_detail  = PG_EXCEPTION_DETAIL;
			error_hint 	  = PG_EXCEPTION_HINT;

		RAISE NOTICE '=================================================================';
        RAISE NOTICE 'ERROR OCCURRED DURING BRONZE LOADING';
        RAISE NOTICE '=================================================================';


		RAISE NOTICE 'Error message: %', error_message;
        RAISE NOTICE 'Error detail: %', error_detail;
        RAISE NOTICE 'Error hint: %', error_hint;

        RAISE NOTICE '=================================================================';

        RAISE;
END $$;
CALL bronze.bronze_load();

/*
Project: Sales Performance Analysis
Author: Lakshay Rana
Tools: MySQL
Description:
End-to-end SQL analysis including KPI trends,
profit contribution analysis, segmentation,
and advanced ranking patterns.
*/


--------------------PHASE 1 = KPI & TREND ANALYSIS-----------------------


--TOTAL SALES AND PROFIT PER YEAR--
SELECT YEAR(order_date) as order_year,
       sum(sales) as total_sales, sum(profit) as total_profit
from superstore_clean
GROUP BY YEAR(order_date)
order by order_year;


--YOY ANALYSIS--
SELECT  order_year,
        total_sales,
        LAG(total_sales) OVER (ORDER BY order_year)as prev_year_sales,
        ROUND((total_sales-LAG(total_sales) OVER(ORDER BY order_year))/
        LAG(total_sales) OVER (ORDER BY order_year)*100,2)as yoy_growth_pct
FROM    (SELECT YEAR(order_date)as order_year,
        sum(sales) as total_sales
        FROM superstore_clean
        GROUP BY YEAR(order_date)
        )x
        ORDER BY order_year;


--------------PHASE 2 = HIGH LEVEL PERFORMANCE ANALYSIS----------------------


--CATEGORY LEVEL PERFORMANCE ANALYSIS--
SELECT category,
       SUM(sales) as total_sales,
       SUM(profit)as total_profit,
       ROUND((SUM(profit)/SUM(sales))*100,2) as profit_margin_pct
from superstore_clean
GROUP BY category
ORDER BY total_sales DESC;


-- SUB-CATEGORY LEVEL PERFORMANCE ANALYSIS--
SELECT category,
       sub_category,
       SUM(sales) as total_sales,
       SUM(profit)as total_profit,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct
from superstore_clean
GROUP BY category,sub_category
ORDER BY category,total_sales DESC;


-- ARE NEGATIVE MARGINS CAUSED BY EXCESSIVE DISCOUNTS?--
SELECT category,
       sub_category,
       ROUND(AVG(discount)*100,2) as avg_disc_pct,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct
FROM superstore_clean
GROUP BY category,sub_category
ORDER BY category,profit_margin_pct DESC;


-- REGIONAL LEVEL TABLES ANALYSIS--
SELECT region,
       SUM(sales) as total_sales,
       SUM(profit) as total_profit,
       ROUND(AVG(discount)*100,2) as avg_disc_pct,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct
FROM superstore_clean
where sub_category="Tables"
GROUP BY region
ORDER BY profit_margin_pct DESC;


-- CHECKING TABLES VOLUME IN THE EAST--
SELECT region,
       SUM(sales) as total_sales,
       SUM(profit) as total_profit,
       SUM(quantity) as total_quan_sold,
       COUNT(DISTINCT order_id) as num_of_orders,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct
FROM superstore_clean
where sub_category="Tables"
GROUP BY region
ORDER BY profit_margin_pct ASC;


--SEGMENT LEVEL PERFORMANCE ANALYSIS--
SELECT segment,
       SUM(sales) as total_sales,
       SUM(profit) as total_profit,
       ROUND(AVG(discount)*100,2) as avg_disc_pct,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct
from superstore_clean
GROUP BY segment
ORDER BY total_sales DESC;


--PROFIT CONTRIBUTION % BY SEGMENT--
SELECT segment,
       SUM(profit) as total_profit,
       ROUND(SUM(profit)/comp_total_profit*100,2) as profit_cont_pct
FROM   (SELECT *,SUM(profit) OVER() as comp_total_profit
       FROM superstore_clean)x
GROUP BY segment,comp_total_profit
ORDER BY profit_cont_pct DESC;


--REGION OVERALL PERFORMANCE ANALYSIS--
SELECT region,
       SUM(sales) as total_sales,
       SUM(profit) as total_profit,
       ROUND((SUM(profit)/NULLIF(SUM(sales),0))*100,2) as profit_margin_pct,
       ROUND(SUM(profit)/comp_total_profit*100,2) as profit_cont_pct
FROM   (SELECT *, SUM(profit) OVER() as comp_total_profit
       FROM superstore_clean)x
GROUP BY region,comp_total_profit
ORDER BY profit_cont_pct DESC;


--------------------PHASE 3 = ADVANCED SQL/INSIGHTS-----------------------


--TOP 5 SUB CATEGORIES BY SALES--
SELECT sub_category,rnk FROM
(SELECT *,DENSE_RANK() OVER(ORDER BY total_sales DESC) as rnk FROM
(SELECT sub_category,
       SUM(sales) as total_sales 
FROM superstore_clean
GROUP BY sub_category)x)y
where rnk<=5;


--CONTRIBUTION % OF TOP 5 SUB CATEGORIES IN TOTAL SALES--
SELECT sub_category,
       total_sales,
       sales_contribution_pct,
       rnk
FROM   (SELECT sub_category,
       SUM(sales) AS total_sales,
       ROUND(SUM(sales) / MAX(comp_total_sales) * 100, 2) AS sales_contribution_pct,
       DENSE_RANK() OVER (ORDER BY SUM(sales) DESC) AS rnk
FROM   (SELECT *,
       SUM(sales) OVER() AS comp_total_sales
       FROM superstore_clean)x
       GROUP BY sub_category)y
WHERE rnk <= 5;


--PROFIT SEGMENTATION--
SELECT
    sub_category,
    total_sales,
    profit_margin_pct,
    CASE
        WHEN sales_bucket = 'High Sales' 
             AND margin_bucket = 'High Margin'
        THEN 'Star'
        WHEN sales_bucket = 'High Sales' 
             AND margin_bucket = 'Low Margin'
        THEN 'Volume Risk'
        WHEN sales_bucket = 'Low Sales' 
             AND margin_bucket = 'High Margin'
        THEN 'High Efficiency'
        ELSE 'Underperformer'
    END AS performance_label
FROM  (SELECT sub_category,
       total_sales,
       ROUND(AVG(total_sales) OVER(),2) as avg_total_sales,
       ROUND(AVG(profit_margin_pct)OVER(),2) as avg_margin,
       profit_margin_pct,
       CASE 
              WHEN total_sales > AVG(total_sales) over()
              THEN "High Sales"
              ELSE  "Low Sales"
       END as sales_bucket,
       CASE 
              WHEN profit_margin_pct>AVG(profit_margin_pct) OVER()
              THEN "High Margin"  
              ELSE  "Low Margin"
       END as margin_bucket
FROM   (SELECT sub_category,
       SUM(sales) as total_sales,
       ROUND(SUM(profit)/NULLIF(SUM(sales),0)*100,2) as profit_margin_pct
FROM superstore_clean
GROUP BY sub_category)x)y
ORDER BY profit_margin_pct DESC;


----CUSTOMER SEGMENTATION----
--Customer Revenue & Profit Overview--
SELECT customer_id,
       SUM(sales) as total_sales,
       SUM(profit)as total_profit
FROM superstore_clean
GROUP BY customer_id
ORDER BY total_sales DESC;


--Customer Contribution %--
SELECT customer_id,
       SUM(sales) as total_sales,
       ROUND(SUM(sales)/MAX(comp_total_sales)*100,2) as customer_cont_pct
FROM   (SELECT *,SUM(sales) OVER() as comp_total_sales
       FROM superstore_clean)X
GROUP BY customer_id
ORDER BY total_sales DESC;


--Customer Concentration & Profitability Analysis--
SELECT customer_id,
       total_sales,
       total_profit,
       profit_margin_pct,
       sales_cont_pct,
       rnk
FROM   (SELECT customer_id,
       SUM(sales) as total_sales,
       SUM(profit) as total_profit,
       ROUND(SUM(profit)/NULLIF(SUM(sales),0)*100,2) as profit_margin_pct,
       ROUND(SUM(sales)/MAX(comp_total_sales)*100,2) as sales_cont_pct,
       DENSE_RANK() OVER(ORDER BY SUM(sales) DESC) as rnk
FROM   (SELECT *, SUM(sales) OVER() as comp_total_sales
       FROM superstore_clean)X
GROUP BY customer_id)y
WHERE rnk<=10;


--Advanced Ranking Pattern--
SELECT region,
       sub_category,
       total_sales,
       rnk
FROM   (SELECT region,
               sub_category,
               total_sales,
               DENSE_RANK() OVER(PARTITION BY region ORDER BY total_sales DESC) as rnk
FROM   (SELECT sub_category,
               region,
               SUM(sales) as total_sales
       FROM superstore_clean
       GROUP BY sub_category,region)x)y
WHERE rnk<=3
ORDER BY region,rnk;


----------------------------------END--------------------------------------

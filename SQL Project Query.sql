-- Global superstore sales analysis

-- Assume functional currency of GBP 
-- Quick overview of the global sales and profit
-- Results show £12,642,507 sales and £1,467,457 profit, showing a profit margin of 11.6%
SELECT SUM(sales), SUM(profit), SUM(profit)/SUM(sales)*100 FROM orders

-- Analysing categories with highest sales for each year to identify growth opportunities
-- results show technology category makes up the highest % of the sales mix each year
SELECT 
	EXTRACT(YEAR FROM order_date) AS year, 
	category, 
	SUM(sales) AS total_sales, 
	ROUND(SUM(profit)/SUM(quantity),2) AS average_profit from orders
GROUP BY EXTRACT(YEAR from order_date), category
ORDER BY year, total_sales DESC

-- Using CTE, list top 3 customers in each segment in each country by sales and assess their order priority
-- person in charge of each country should have the knowledge of their large customers, can be expanded to top 10 customers

WITH top_three AS(
	SELECT 
	country, 
	segment, 
	customer_name, 
	order_priority, 
	SUM(sales) AS total_sales,
	rank() over (PARTITION BY country, segment ORDER BY SUM(sales) DESC) rank
	FROM orders
	GROUP BY 
	country, 
	segment, 
	customer_name, 
	order_priority 
)
SELECT * FROM top_three
WHERE rank <=3

-- created temp table to use the dataset for several queries

DROP TABLE IF EXISTS top_3_per_segment
SELECT 
	country, 
	segment, 
	customer_name, 
	order_priority, 
	sum(sales) AS total_sales,
	rank() over (PARTITION BY country, segment ORDER BY SUM(sales) DESC) rank
INTO TEMP TABLE top_3_per_segment 
FROM orders
GROUP BY 
	country, 
	segment, 
	customer_name, 
	order_priority 

-- assume that the 'low order priority' in this dataset means that given everything else is the same, this order has a lower priority
-- these are largest customers hence important to secure their loyalty
-- this can be a performance metrics 
-- result shows that out of 1108 important orders, 49 orders are given low priority
-- low priority sales as a % of important sales is 3.32%

-- count the number of important orders 
SELECT COUNT (total_sales) from top_3_per_segment
WHERE rank <=3 

-- count the number of important orders with low priority 
SELECT COUNT (total_sales) from top_3_per_segment
WHERE rank <=3 AND order_priority = 'Low'

-- calculate the sale of the low priority order as a % of total important sales
SELECT DISTINCT((
	SELECT SUM(total_sales) FROM top_3_per_segment
	WHERE rank <=3 AND order_priority='Low')/
				(SELECT sum(total_sales) FROM top_3_per_segment
				WHERE rank <=3))*100 AS perc_imp_sales_low_priority 
FROM top_3_per_segment


-- identify top 20 most profitable products
-- average profit used to ensure output not distorted by quantity
-- sum of sales used to understand the size of sales 
-- the product with highest avg profit is Canon imageCLASS 2200, the avg profit is approx 126% of the second product, the sales is the largest among top 20 products with highest average profit
-- this is a star product, need to ensure sufficient inventory (also consider obsolescence)
-- need data on costs to understand the key driver of the high profit

SELECT 
	product_id, 
	product_name, 
	sum(quantity), 
	ROUND(SUM(profit)/SUM(quantity),2) AS avg_profit, 
	SUM(sales) AS total_sales 
FROM orders
GROUP BY product_id,product_name
ORDER BY avg_profit DESC
LIMIT 20

-- understand the segment breakdown of Canon imageCLASS2200
-- corporate segment has highest average profit of £1680, followed by consumer segment of £1170 
-- corporate segment has second highest sales total of £17.5k wheareas consumer segment has sales of £32.9k (double the sales of corporate)
-- however there are a number of returns from consumer segment, see section returns below

SELECT 
	product_id, 
	product_name, 
	segment, 
	SUM(quantity), 
	ROUND(SUM(profit)/SUM(quantity),2) AS avg_profit, 
	SUM(sales) AS total_sales 
FROM orders
WHERE product_name LIKE '%Canon imageCLASS 2200%'
GROUP BY product_id,product_name, segment 
ORDER BY AVG(profit) DESC

SELECT 
	product_id, 
	product_name, 
	segment, 
	profit, 
	sales, 
	quantity 
FROM orders
WHERE product_name LIKE '%Canon imageCLASS%'
ORDER BY profit DESC

-- top 20 least profitable products
-- top 2 loss making products are Cubify 3D Triple and Double Head prints 

SELECT 
	product_id, 
	product_name, 
	ROUND(SUM(profit)/SUM(quantity),2) AS avg_profit, 
	SUM(sales) AS total_sales 
FROM orders
GROUP BY product_id,product_name 
ORDER BY avg_profit
LIMIT 20

-- to understand if the brand in general has relatively low average profit
-- results show that these are the only two products under this brand, the loss is caused by high discount at 20%, 50% and 70%
-- need further investigation on the nature of the transactions
-- consider dropping the products if they are creating loss and if they do not complement other sales

SELECT 
	product_id, 
	product_name, 
	ROUND(SUM(profit)/SUM(quantity),2) AS avg_profit, 
	SUM(sales) AS total_sales 
FROM orders
WHERE product_name LIKE '%Cubify%'
GROUP BY product_id,product_name 
ORDER BY AVG(profit)

SELECT * FROM orders
WHERE product_name LIKE '%Cubify%'

-- join with the returns table to investigate returns

-- big picture on total returns sales as a % of total sales, total returns profit as a % of total profit
-- returns accounted for 6.5% of total sales and 8% of total profit
-- this can be a performance measure

SELECT 
	ROUND((SUM(sales))/ 
		  (SELECT SUM(sales) FROM orders),4)*100 AS perc_returned_sales, 
	ROUND((sum(profit))/
		  (SELECT SUM(profit) FROM orders),4)*100 AS perc_returned_profit 
FROM returns
INNER JOIN orders 
ON returns.order_id = orders.order_id 
AND returns.market = orders.market

-- identify the products with highest return by sales
-- the product with highest return by sales is the Canon imageCLASS 2200 copier, of which all relate to consumer segment
-- £14k of £32.9k of the Canon 2200 sales to consumer sector is return (42.5% of sales returned)
-- investigation required on the reason of returns

SELECT 
	returns.order_id, 
	returns.market, 
	segment, 
	category, 
	subcategory, 
	product_id, 
	product_name, 
	SUM(quantity) AS total_quantity, 
	SUM(profit) AS total_profit, 
	SUM(sales) AS total_sales 
FROM returns
INNER JOIN orders 
ON returns.order_id = orders.order_id 
AND returns.market = orders.market
GROUP BY 
	returns.order_id, 
	returns.market, 
	segment, 
	category, 
	subcategory, 
	product_id, 
	product_name
ORDER BY SUM(sales) DESC

-- highest number of return by quantity
-- results show that the highest number of return by quantity is Stanley Canvas water colour - 15 returns, the reason can be investigated.
-- however the profit and sales are relatively small at £268 and £710 each
-- the product which pops up with high number with returns and has high profit and sales is Red Hoover Stove - 14 returns
-- Red Hoover Stove also appears as the second products with highest return by sales in the table above
-- the profit and sales are £3979 and £7959 respectively, need to be investigated.

SELECT 
	returns.order_id, 
	returns.market, 
	segment, 
	category, 
	subcategory, 
	product_id, 
	product_name, 
	SUM(quantity) AS total_quantity, 
	SUM(profit) AS total_profit, 
	SUM(sales) AS total_sales 
FROM returns
INNER JOIN orders 
ON returns.order_id = orders.order_id 
AND returns.market = orders.market
GROUP BY 
	returns.order_id, 
	returns.market, 
	segment, 
	category, 
	subcategory, 
	product_id, 
	product_name
ORDER BY SUM(quantity) DESC



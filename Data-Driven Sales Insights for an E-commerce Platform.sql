-- Project Title: Data-Driven Sales Insights for an E-commerce Platform
Use Sales_Major_Project;

 sp_help 'ecom_orders';

--ALTER TABLE ecom_orders
--ALTER COLUMN order_date DATE;

-- 1.	Daily / Monthly / Yearly sales

Select 
order_date,
sum(order_amount) as total_amount
from ecom_orders
group by order_date
order by order_date asc

Select 
format(order_date,'yyyy-MM') as month,
sum(order_amount) as total_amount
from ecom_orders
group by format(order_date,'yyyy-MM')
order by month asc

Select 
year(order_date) as year,
sum(order_amount) as total_amount
from ecom_orders
group by year(order_date) 
order by year asc 

-- Q. YoY & MoM growth %

;with monthly_sales as
(
	Select
	format(order_date,'yyyy-MM') as month,
	sum(order_amount) as total_sales
	from ecom_orders
	group by format(order_date,'yyyy-MM'),year(order_date)
)

Select * ,
lag(total_sales) over(order by month) as previous_month_sales,
((total_sales - lag(total_sales) over(order by month)) * 100)/lag(total_sales) over(order by month) MOM
from monthly_sales

-- Daily growth %
;with daily_sales as
(
	Select 
	order_Date,
	sum(order_amount) as total_sales
	from ecom_orders
	group by order_Date
)

Select *,
lag(total_sales) over(order by order_date asc) as previou_day_sale,
((total_sales - lag(total_sales) over(order by order_date asc))*100)/lag(total_sales) over(order by order_date asc) as DOD_Percentage
from daily_sales

-- YOY GROWTH %
;With yearly_sales as
(
	Select 
	year(order_date) as year,
	sum(order_amount) as total_Sales
	from ecom_orders
	group by year(order_date)
)

Select *,
lag(total_sales) over(order by year) as prev_year_sales,
((total_sales - lag(total_sales) over(order by year))*100)/ lag(total_sales) over(order by year) as YOY_percentage
from yearly_Sales

-- Top-selling products by revenue
Select * from ecom_orders
Select * from ecom_products
Select * from ecom_order_items

Select oi.product_id,
product_name,
sum(order_amount) as order_amount
from ecom_order_items oi
join ecom_products p
on oi.product_id= p.product_id
join ecom_orders o
on o.order_id=oi.order_id
group by  oi.product_id,product_name
order by sum(order_amount) desc

-- Revenue by category & city
--Peak revenue months/days

-- By month
select top 1
format(order_date,'yyyy-MM') as monthly_sales,
sum(order_amount) as total_Amount
from ecom_orders
group by format(order_date,'yyyy-MM')
order by sum(order_amount) desc

-- By Daily
select top 1
order_date,
sum(order_amount) as total_Amount
from ecom_orders
group by order_date
order by sum(order_amount) desc

-- Repeat vs. one-time customers % 

declare @Category Table(Category_Type Varchar(50))
INSERT INTO @Category 
			VALUES ('One-Time'), ('Repeat')

;With user_order_count as
(
Select 
user_id,
count(order_id) as total_count
from ecom_orders
group by user_id
)
SELECT C.Category_Type, COUNT(U.User_id) AS UserCount
FROM @Category C
LEFT JOIN user_order_count U ON C.Category_Type= CASE U.total_count WHEN 1 THEN 'One-Time' ELSE 'Repeat' END
GROUP BY C.Category_Type

--Other ways
;With user_order_count as
(
Select 
user_id,
count(order_id) as total_count
from ecom_orders
group by user_id
),
classify as
(
Select
user_id,
total_count,
case 
	when total_count = 1 then 'one-type'
	else 'repeat'
	end as 'Customer_Type'
from user_order_count
)

Select 
	customer_type,
	count(*) TotalUsers,
	count(*)*100/(select count(*) from user_order_count) as PercentageofUsers
from classify
group by customer_type

--Avg order value per user

Select 
user_id,
round(sum(order_amount)/count(order_id),2) as Aov
from ecom_orders
group by user_id
order by 2

--*** 8. Users who increased/decreased purchase frequency

;with monthly_sales as
(
	Select 
	user_id,
	format(order_date,'yyyy-MM') as month_year,
	count(*) as user_order_count
	from ecom_orders
	group by user_id, format(order_date,'yyyy-MM')
),
sales_growth as
(
Select *,
lag(user_order_count) over (order by month_year desc) as prev_month_year
from monthly_sales
)
Select 
user_id,
month_year,
user_order_count,
prev_month_year,
case
	when prev_month_year is Null then 'New Customer'
	when user_order_count>prev_month_year then 'Increased'
	when user_order_count<prev_month_year then 'Decreased'
	else 'New'
end as 'Purchase Trend'
from sales_growth

--*** Identify users who haven’t made any order in the last 90 days from today (or from the latest order date in your dataset).

WITH last_user_order AS (
  SELECT
    user_id,
    MAX(order_date) AS last_order_date
  FROM ecom_orders
  WHERE status = 'completed'
  GROUP BY user_id
)
SELECT 
  user_id,
  last_order_date,
  DATEDIFF(day, last_order_date, GETDATE()) AS days_since_last_order
FROM last_user_order
WHERE last_order_date < DATEADD(day, -90, GETDATE())
ORDER BY days_since_last_order DESC;


-- Inventory pressure products

--Q . Products sold in most cities
--select * from ecom_orders
--select * from [dbo].[ecom_users]
--select * from ecom_products
--select * from ecom_order_items

Select ep.product_id,
ep.product_name,
count(distinct eu.city) as No_of_distinct_city
from ecom_products ep
join ecom_order_items ei
on ep.product_id=ei.product_id
join ecom_orders eo
on ei.order_id=eo.order_id
join ecom_users eu
on eo.user_id= eu.user_id
group by ep.product_id,ep.product_name
order by No_of_distinct_city desc

-- Products with highest return rate 
-- Here I don't have any resturn table so we arre assuming return table.

Select * from ecom_orders
Select * from ecom_products
Select * from ecom_order_items

;WITH sold_qty AS (
  SELECT 
    product_id,
    SUM(quantity) AS total_sold
  FROM ecom_orders eo
  join ecom_order_items oi
  on oi.order_id= eo.order_id
  GROUP BY product_id
),
-- This assumed table
returned_qty AS (
  SELECT 
    product_id,
    SUM(return_quantity) AS total_returned
  FROM returns
  GROUP BY product_id
)

SELECT 
  p.product_id,
  p.product_name,
  s.total_sold,
  ISNULL(r.total_returned, 0) AS total_returned,
  ROUND(
    ISNULL(r.total_returned * 100.0 / NULLIF(s.total_sold, 0), 0),
    2
  ) AS return_rate_percentage
FROM sold_qty s
JOIN products p ON s.product_id = p.product_id
LEFT JOIN returned_qty r ON s.product_id = r.product_id
ORDER BY return_rate_percentage DESC;


--*** % cancelled orders by category

select * from ecom_orders
select * from [dbo].[ecom_users]
select * from ecom_products
select * from ecom_order_items

;With product_wise_sales as
(
Select 
ep.product_id as prod_id,
ep.category as prod_category,
count( eo.order_id) as No_of_successfull_orders
from ecom_products ep
left join ecom_order_items ei
on ep.product_id=ei.product_id
join ecom_orders eo
on ei.order_id=eo.order_id
where eo.status='completed'
group by ep.product_id,ep.category
),

No_of_returned_orders as
(
Select 
ep.product_id as prod_id,
ep.category prod_category,
count( eo.order_id) as No_of_Cancelled_orders
from ecom_products ep
left join ecom_order_items ei
on ep.product_id=ei.product_id
join ecom_orders eo
on ei.order_id=eo.order_id
where eo.status='cancelled'
group by ep.product_id,ep.category
)

select 
no.prod_id,
no.prod_category,
(ps.No_of_successfull_orders)* 100.0/no.no_of_cancelled_orders as Cancelled_Rate
from No_of_returned_orders no
join product_wise_sales ps
on no.prod_id=ps.prod_id

-- Payment method trends
;with payment_details as (
Select 
payment_method,
format(order_date,'yyyy-MM') as month_year,
count(*) as No_of_payment,
sum(order_amount) as total_sales
from ecom_orders
where status='completed'
group by payment_method,format(order_date,'yyyy-MM')
),
monthly_total as
(
Select 
FORMAT(order_date,'yyyy-MM') as monthly_sales,
count(*) total_month_order,
sum(order_amount) as total_sales
from ecom_orders
group by FORMAT(order_date,'yyyy-MM')
)


select pd.month_year,
pd.payment_method,
pd.total_sales,
(pd.No_of_payment*100)/mt.total_month_order as paymet_percentage,
round((pd.total_sales*100)/mt.total_sales,2) as sales_percetage
from payment_details pd
join monthly_total mt
on pd.month_year = mt.monthly_sales

-- Daily/monthly order volume trend

Select 
order_date,
count(order_id) as No_of_orders,
sum(order_amount) as total_sales
from ecom_orders
group by order_date 
order by order_date desc

Select 
format(order_date,'yyyy-MM') as month_year,
count(*) as No_of_orders,
sum(order_amount) as total_amount
from ecom_orders
group by format(order_date,'yyyy-MM')

-- Avg order items per cart
-- % orders with only 1 item

-- Calculate the percentage of completed orders where the total quantity of items = 1.

;with order_quantity as
(
select 
eo.order_id ,
sum(ei.quantity) as total_quantity
from ecom_orders eo
join ecom_order_items ei
on ei.order_id=eo.order_id
group by eo.order_id
)
Select
count(case when total_quantity=1 then 1 end) * 100/ Count(*) as one_item_order_percentage
from order_quantity 

-- 20. % of users who made purchases after signup
Select * from ecom_orders
select * from ecom_order_items
Select * from ecom_products
select * from ecom_users

;with purchasing_users as
(
	Select distinct eu.user_id
	from ecom_orders eo
	left join ecom_users eu
	on eo.user_id=eu.user_id
	where status='completed' and eo.order_date> eu.signup_date 
)

SELECT 
  ROUND(
    COUNT(distinct pu.user_id) * 100.0 / COUNT(distinct u.user_id),
    2
  ) AS purchase_after_signup_percentage
FROM ecom_users u
LEFT JOIN purchasing_users pu ON u.user_id = pu.user_id


Select * from ecom_users

-- % orders per payment method?

Select 
payment_method,
count(*) as Total_orders,
(count(*) * 100)/ (select count(*) from ecom_orders eo1 where status='completed') as percentage_of_orders
from ecom_orders eo
where status='completed'
group by payment_method
order by percentage_of_orders desc


-- *** 22. % revenue from top 10 products

;with top_10_products as
(
Select Top 10
ep.product_id, 
ep.product_name,
sum(unit_price * quantity) as total_spent
from ecom_products ep
join ecom_order_items ed
on ep.product_id=ed.product_id
--join ecom_orders eo
--on ed.order_id=eo.order_id
group by ep.product_id, ep.product_name
order by total_spent desc
)
Select 
product_id,
product_name,
(total_spent *100)/(Select sum(order_amount) from ecom_orders) as percenatge
from top_10_products


-- % Customers Who Bought from Multiple Categories

SELECT * FROM ecom_orders
Select * from ecom_products
Select * from ecom_order_items

;with user_category as 
(
	Select 
	eo.user_id,
	ep.category
	from ecom_products ep
	join ecom_order_items ei
	on ep.product_id=ei.product_id
	join ecom_orders eo
	on eo.order_id=ei.order_id
	group by eo.user_id,ep.category
),

--Count how many category per customer

category_count as
(
	Select 
	USER_ID,
	count(distinct category) as cnt
	from user_category
	group by USER_ID
)
Select 
count(case when cnt > 1 then 1 end)*100/ (Select count(*) from category_count)
from category_count





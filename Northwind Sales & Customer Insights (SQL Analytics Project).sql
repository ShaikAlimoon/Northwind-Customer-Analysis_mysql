use northwind;
select * from category;
select* from customer;
## --Analytical Questions for Northwind Database
# --1 Customer Analysis
-- 1. Who are the top 5 customers by total order value, and what is their contribution to overall revenue? 
-- This helps identify high-value customers for targeted marketing or loyalty programs.
with moeed as(
               select contactname,sum(unitprice*quantity) as revenue
               from customer
                join salesorder using(custid)
                join orderdetail using(orderid) 
                group by contactName),
moeed_all as(
              select sum(unitprice*quantity) as total_revenue
              from orderdetail)
select m.contactname,m.revenue,
         round((m.revenue/ma.total_revenue)*100,2) as contributionINpercent
from moeed as m
cross join moeed_all as ma
order by m.revenue desc limit 5;

#2. Which customers have placed the most orders in the last year, and what are their order frequencies?
##Useful for understanding customer engagement and retention.


select contactname,count(orderid) as count_order
   from customer
   join salesorder using(custid)
   where orderdate>DATE_SUB(orderdate, INTERVAL 1 year)
   group by contactname
   order by count_order desc;








select DATE_SUB(CURDATE(), INTERVAL 1 year);
   








# 3. What is the geographic distribution of customers by country, and which countriesgenerate the most revenue?
#Helps in analyzing market penetration and regional performance.
with revenue as(
                select 
                      c.country,
                      count(c.custid) as numcustomer,
                      round(sum((quantity)*(unitprice)),2) as total_revenue,
                      row_number()over(partition by c.country order by sum(quantity*unitprice) desc) as Most_Revenue_Generate
				from customer as c
				join salesorder as o using(custid)
				join orderdetail as od using(orderid)
				group by  c.country
                               )
select *
from revenue
where Most_Revenue_Generate<=1
order by total_revenue desc;
                      





#4. Which customers have not placed orders in the past 6 months?
#Identifies inactive customers for re-engagement campaigns.
 
SELECT custid,
       contactName,
       phone
FROM customer
WHERE custid NOT IN (
    SELECT custid
    FROM salesorder
    WHERE orderdate >= (select DATE_SUB(max(orderdate), INTERVAL 6 MONTH) from salesorder))
;
                       
                          
#2 Sales and Order Analysis
##1. What are the top-selling products by quantity and revenue, and how do they trend over time?
#Highlights best-performing products for inventory and marketing strategies.

WITH top_products AS (
    SELECT 
        od.productid
    FROM orderdetail od
    GROUP BY od.productid
    ORDER BY SUM(od.quantity) DESC
    LIMIT 5
)
SELECT 
    p.productname,
    YEAR(o.orderdate) AS year,
    MONTH(o.orderdate) AS month,
    SUM(od.quantity) AS monthly_quantity,
    SUM(od.quantity * od.unitprice) AS monthly_revenue
FROM product p
JOIN orderdetail od 
    ON p.productid = od.productid
JOIN salesorder o 
    ON od.orderid = o.orderid
WHERE od.productid IN (SELECT productid FROM top_products)
GROUP BY 
    p.productname,
    YEAR(o.orderdate),
    MONTH(o.orderdate)
ORDER BY 
    p.productname, year, month;

select distinct p.productname,
        year(s.orderdate) as yr,
        monthname(s.orderdate),
        sum(od.quantity) as monthwiseQuantity,
        sum((od.quantity)*(od.unitprice))as monthRvenue
from product as p
        join orderdetail as od using(productid)
        join salesorder as s using(orderid)
group by 
		p.productname,
        year(s.orderdate) ,
        monthname(s.orderdate)
        order by  yr asc ;







##2. What is the average order value (AOV) per month, and how does it vary by customer segment or region?
#Provides insights into purchasing behavior and regional differences.



with moeed as (
    select
        r.regiondescription as region,

        monthname(s.orderdate) as order_month,
        count(distinct s.orderid) as total_orders,
        SUM(od.quantity * od.unitprice) as total_revenue
    from customer c
    join salesorder s using(custid)
    join orderdetail od using(orderid)
    join employeeterritory et using(employeeid)
    join territory t using(territoryid)
    join region r using(regionid) 
    where c.region is not null
    group by
        r.regiondescription,
     
        monthname(s.orderdate)
)
select *,
    round(total_revenue / total_orders,2) as AOV
from moeed
order by region, order_month;























##3. Which products are frequently purchased together in the same order?
#Useful for cross-selling recommendations or product bundling strategies.
select 
   p1.productname as product_1,
   p2.productname as product_2,
   count(*) as times_bought_together
from orderdetail as od1
     join orderdetail as od2 on od1.orderid=od2.orderid and od1.productId<od2.productId
     join product as p1 on od1.productId=p1.productId
     join product as p2 on od2.productId=p2.productId
group by product_1,
         product_2
order by times_bought_together desc;
      



##4. What is the sales performance by employee, and how does it correlate with order
#processing time?
#Evaluates employee productivity and efficiency in order fulfillment.
  

SELECT 
    e.employeeid,
    CONCAT(e.firstname, ' ', e.lastname) AS fullname,
    COUNT(DISTINCT so.orderid) AS total_orders,
    CONCAT("$ ",ROUND(SUM(od.quantity * od.unitprice)/1000,2),"K") AS total_revenue,
    CONCAT(
        FLOOR(AVG(DATEDIFF(so.shippeddate, so.orderdate))), ' days ',
        FLOOR(
            (AVG(DATEDIFF(so.shippeddate, so.orderdate))
            - FLOOR(AVG(DATEDIFF(so.shippeddate, so.orderdate)))) * 24
        ),
        ' hours'
    ) AS avg_processing_time
FROM employee e
JOIN salesorder so ON e.employeeid = so.employeeid
JOIN orderdetail od ON so.orderid = od.orderid
WHERE so.shippeddate IS NOT NULL
GROUP BY e.employeeid, fullname
 ;







####3 Product and Inventory Analysis
##1. Which products have the highest and lowest stock levels, and how do they correlate
#with sales velocity?
#Aids in inventory management to prevent stockouts or overstocking.
#1


with moeed as
   (select 
      p.productid,p.productname,unitsInStock,
      sum(od.quantity) as total_quantity_sold,
      count(distinct so.orderdate) as selling_date
    from product as p
    left join orderdetail as od using(productid)
    left join salesorder as so using(orderid)
    group by p.productid,p.productname,unitsInStock)
select *,
      (total_quantity_sold/selling_date) as sales_velocity,
      case 
         when 
           unitsInStock=(select max(unitsInStock) from product) then 'highStock'
		 when unitsInStock=(select min(unitsInStock) from product) then 'lowStock'
	else 'Midium'
    end Stock_Category
    from moeed
    order by sales_velocity desc;
      


##2. What is the profit margin for each product, considering unit price and supplier cost?
#Helps identify high-margin products for strategic focus.
   with moeed as
    (select 
       p.productid,
       p.productname,
       sum(p.unitPrice*od.unitPrice) as cost_of_product,
       sum(od.unitprice-p.unitprice) as profit
       from product as p
       join orderdetail as od
       group by 
           p.productId,p.productName
           order by profit desc)
     select productid,
            productname,
           concat("$ ",round(profit/1000,2)," K") AS Profit ,
          concat (round((profit/cost_of_product)*100,2)," %") as margin_percent
       from moeed
       ;    
            
  

##3. Which product categories contribute the most to total revenue, and how has this changed over time?
#Guides category-level marketing and procurement decisions.
with md as(
      with moeed as(
        select 
           year(so.orderdate) as yr,quarter(so.orderdate) as 	Qt,
           ca.categoryname,
           concat("$ ",round(sum(od.quantity*od.unitprice/1000),2)," K") as total_revenue
		from product
         join orderdetail as od using(productid)
         join category as ca using(categoryid)
         join salesorder as so using(orderid)
        group by 
               yr,	
               Qt,
               categoryName
		order by total_revenue desc)
   select *,
         row_number() over (partition by yr,Qt order by total_revenue desc) as rownumber
	from moeed)
select *
  from md
  where rownumber<=1;
  
   
        





###4 Supplier Analysis
##1. Which suppliers provide the most products, and what is their average product price
#compared to sales performance?
#Evaluates supplier importance and cost-effectiveness.

with md as(
	with moeed as(
		 SELECT
               s.supplierid,
               s.companyname,
               count(distinct p.productid) as count_product,
               round(avg(p.unitprice),2) as avg_productprice,
               sum(od.unitprice*od.quantity) as total_revenue
			from supplier as s
              join product as p using(supplierid)
              join orderdetail as od using(productid)
			group by 
                    s.supplierid,
                    s.companyname )
	 select *,
         rank() over (order by total_revenue desc) as supplier_rank
         from moeed)
select *,
      case
         when
           supplier_rank<=3 then 'heigh'
         when 
           supplier_rank<=7 then 'medium'
         else 'low'
      end supplier_category
  from md;
            
               
               
            
               



###2. Are there suppliers whose products have higher-than-average reorder rates?
#Identifies reliable suppliers for long-term partnerships
with supplier_category as(
           with md as(
               with moeed as( 
                 select 
                    p.productid,
                    p.supplierid,
					count(distinct od.orderid) as count_reorder
				 from product as p 
                    join orderdetail as od using(productid)
				 group by 
                          p.productid,
                          p.supplierid)
                          
		select 
             m.supplierid,
             s.companyname,
             avg(count_reorder) as avg_reorder
		   from moeed as m
             join supplier as s using(supplierid)
		   group by   
                     m.supplierid,
                     s.companyname)
                     
	select *,
         rank() over (order by avg_reorder desc) as supplier_ranks
	from md
    where avg_reorder>(select avg(avg_reorder) from md) )
    
select *,
     case
       when 
          supplier_ranks <= 3 then 'reliable_supplier'
	   when
		  supplier_ranks <= 10 then 'medium_supplier'
	   else 'low_level_supllier'
	end supplier_trusted_category
from supplier_category;
	
    
    
    
         
                     
			
           
		  
            





###5 Temporal and Seasonal Analysis
##1. What are the peak months or seasons for sales, and which products drive these
#peaks?
#Helps in planning for seasonal demand and inventory.


with months_revenue as(
        select 
           year(so.orderdate) as yr,
           quarter(so.orderdate) as Qt,
           monthname(so.orderdate) as months,
           sum(od.unitprice*od.quantity) as month_revenue
		from product as p
		join orderdetail as od using(productid)
        join salesorder as so using(orderid)
        group by  
            yr,
            Qt,
            months
            ),
month_peak as(
             select *,
                  rank() over (order by month_revenue desc) as month_ranks
				from months_revenue),

products_revenue as(
          select
              quarter(so.orderdate) as Qt,
              monthname(so.orderdate) as months,
              p.productname,
              sum(od.unitprice*od.quantity) as product_revenue
		 from product as p
            join orderdetail as od using(productid)
            join salesorder as so using(orderid)
		 group by
              Qt,
              months,
              productname) ,
              
product_peak as (
          select *,
              rank() over (partition by Qt,months order by product_revenue desc) as product_ranks
			from products_revenue)

select distinct
      pp.Qt,
      pp.months,
      pp.productname,
      pp.product_revenue,
      pp.product_ranks
	from product_peak as pp
    join month_peak as mp on 
                      pp.Qt=mp.Qt and
                      pp.months=mp.months
     where  
          month_ranks <= 3  and
          product_ranks <= 1
	order by 
          pp.Qt,
          pp.months,
          pp.product_ranks;
	
      
    
    
    
    
    
          
          
##2. How does order volume and revenue trend year-over-year for specific product categories?
#Provides insights into long-term business growth and category performance.
with top_category_perfomence as(
  with category_performance as(
    with md as(
      with moeed as (
        with category_revenue as(
                  select 
                     year(so.orderdate) as yr,
                     ca.categoryname,
                     sum(od.quantity) as quantity_value,
                     sum(od.quantity*od.unitprice) as category_value
					from category as ca
					join product as p using(categoryid)
                    join orderdetail as od using(productid)
                    join salesorder as so using(orderid)
                   group by 
                          yr,
                          categoryname)
     select *,
           lag(quantity_value) over (partition by categoryname order by yr ) as quantity_value_YOY,
           LAG(category_value) over (partition by categoryname order by yr) as category_value_YOY
       from category_revenue )
  select *
  from moeed
  order by yr,categoryname)
  
select   
      yr,
      categoryname,
      quantity_value,
      quantity_value_YOY,
     round((quantity_value-quantity_value_YOY)*100/quantity_value,2) as Grouth_quantity_percent,
      category_value
      category_value_YOY,
      round((category_value-category_value_YOY)*100/category_value,2) as Grouth_category_percent
   from md)

  select *,
       rank() over (partition by categoryname order by Grouth_category_percent desc) as category_ranks
	from category_performance)
    
select *
  from top_category_perfomence;
  

      


with category_yearly as(
				select
                    year(so.orderdate) as yr,
                    ca.categoryname,
                    sum(od.quantity) as total_quantity,
                    sum(od.quantity*od.unitprice) as revenue
				from category as ca
                  join product as p using(categoryid)
                  join orderdetail as od using(productid)
                  join salesorder as so using(orderid)
                group by 
                   year(so.orderdate) ,
                    ca.categoryname  ),
base_yearly as (
            select 
                categoryname,
                total_quantity as base_quantity,
                revenue as base_revenue
            from category_yearly
             where yr='2006' 
			)
  select 
       cy.yr,
       cy.categoryname,
       cy.total_quantity,
       byy.base_quantity,
       round((cy.total_quantity-byy.base_quantity)*100/byy.base_quantity,2) as grouth_percentQuantity,
       cy.revenue,
       byy.base_revenue,
       round((cy.revenue-byy.base_revenue)*100/byy.base_revenue,2) as grouth_percentRevenue
	from category_yearly as cy
    join base_yearly as byy on
        cy.categoryname=byy.categoryname
	order by 
             categoryname,
             yr; 
             
             use northwind;
			
                


                     





###6 Employee and Operational Analysis
##1. Which employees have the highest sales volume, and how does this correlate with their territory assignments?
# Useful for performance reviews and territory optimization.


      with moeed as(
             select 
                e.employeeid,
                t.territorydescription as territory,
				concat(e.firstname," ",lastname) as employeename,
                count(so.orderid) as number_product_order,
                sum(od.unitprice*od.quantity) as total_volume
			from employee as e
              join salesorder as so using(employeeid)
              join orderdetail as od using(orderid)
              join employeeterritory using(employeeid)
              join territory as t using(territoryid)
			group by 
                  employeeId,
                     territory,
                     employeename)
                     
		select distinct 
              territory,
              employeename,
              number_product_order,
              total_volume,
              dense_rank() over (partition by territory order by total_volume desc) as employee_efficency
		from  moeed
        
             ;
            
                









#2. What is the average time taken to ship orders, and how does it vary by region or shipping company?
#Evaluates operational efficiency and logistics performance.2


        with moeed as(
             select 
                so.shipregion,
                s.companyname as shippingcompany,
               avg (datediff(so.shippeddate,so.orderdate)) as delay_days
                from salesorder as so 
                join shipper as s using(shipperid)
                where shipregion is not null and so.shippedDate is not null
                group by 
                    shipRegion,
                    shippingcompany)
		select *,
          dense_rank() over ( order by delay_days asc) as perfomence_shippingcompany
		from moeed;
             
             
             
             
             
             
             
             
             
             
  
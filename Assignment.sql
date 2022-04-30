--Q1. List of Persons’ full name, all their fax and phone numbers, as well as the phone number and fax of the company they are working for (if any). 
USE WideWorldImporters

SELECT
	p.FullName,
	p.FaxNumber AS Personal_Fax,
	p.PhoneNumber AS Personal_Phone,
	COALESCE(s.FaxNumber, c.FaxNumber) AS Company_Fax,
	COALESCE(s.PhoneNumber, c.PhoneNumber) AS Company_Phone
FROM
	Application.People p 
LEFT JOIN Purchasing.Suppliers s ON s.PrimaryContactPersonID = p.PersonID OR s.AlternateContactPersonID = p.PersonID
LEFT JOIN Sales.Customers c ON c.PrimaryContactPersonID = p.PersonID OR c.AlternateContactPersonID = p.PersonID
WHERE
	p.PersonID != 1

--Q2. If the customer's primary contact person has the same phone number as the customer’s phone number, list the customer companies. 

SELECT
	c.CustomerName AS Company
FROM
	Sales.Customers c
JOIN Application.People p ON c.PrimaryContactPersonID = p.PersonID AND c.PhoneNumber = p.PhoneNumber

--Q3. List of customers to whom we made a sale prior to 2016 but no sale since 2016-01-01.

SELECT
	c.CustomerName
FROM
	Sales.CustomerTransactions ct
JOIN Sales.Customers c ON c.CustomerID = ct.CustomerID
GROUP BY
	c.CustomerName
HAVING MAX(ct.TransactionDate) <= '2015-12-31'

--Q4. List of Stock Items and total quantity for each stock item in Purchase Orders in Year 2013.

SELECT
	s.StockItemID,
	COUNT(p.PurchaseOrderID) AS total_quantity
FROM
	Purchasing.PurchaseOrders p
JOIN Warehouse.StockItemTransactions s ON p.PurchaseOrderID = s.PurchaseOrderID
WHERE
	p.OrderDate BETWEEN '2013-01-01' AND '2013-12-31'
GROUP BY
	s.StockItemID
ORDER BY
	s.StockItemID

--Q5. List of stock items that have at least 10 characters in description.

SELECT
	StockItemID
FROM
	Warehouse.StockItems
WHERE
	len(MarketingComments) >= 10

-- Q6. List of stock items that are not sold to the state of Alabama and Georgia in 2014.
-- Only ID 223 do not sell to both states
WITH items_with_AL_GA AS(
	SELECT
		DISTINCT s.StockItemID
	FROM
		Warehouse.StockItemTransactions s
	JOIN Sales.Customers sc ON s.CustomerID = sc.CustomerID
	JOIN Application.Cities ac ON ac.CityID = sc.PostalCityID
	WHERE
		ac.StateProvinceID IN	(SELECT
									StateProvinceID
								FROM
									Application.StateProvinces s
								WHERE
									s.StateProvinceName = 'Alabama' or s.StateProvinceName = 'Georgia'
								)
)
SELECT
	DISTINCT ws.StockItemID
FROM
	Warehouse.StockItemTransactions ws
WHERE
	CAST(ws.TransactionOccurredWhen AS DATE) BETWEEN '2014-01-01' AND '2014-12-31'
	AND
	ws.StockItemID NOT IN (
						SELECT
							StockItemID
						FROM
							items_with_AL_GA
						)

--Q7. List of States and Avg dates for processing (confirmed delivery date – order date).

SELECT
	ac.StateProvinceID,
	AVG(DATEDIFF(DAY, o.OrderDate, i.ConfirmedDeliveryTime)) AS avg_day
FROM
	Sales.Orders o
JOIN Sales.Invoices i ON i.OrderID = o.OrderID
JOIN Sales.Customers c ON i.CustomerID = c.CustomerID
RIGHT JOIN Application.Cities ac ON ac.CityID = c.PostalCityID
GROUP BY
	ac.StateProvinceID
ORDER BY
	ac.StateProvinceID

--Q8. List of States and Avg dates for processing (confirmed delivery date – order date) by month.

SELECT
	ac.StateProvinceID,
	AVG(DATEDIFF(MONTH, o.OrderDate, i.ConfirmedDeliveryTime)) AS avg_day
FROM
	Sales.Orders o
JOIN Sales.Invoices i ON i.OrderID = o.OrderID
JOIN Sales.Customers c ON i.CustomerID = c.CustomerID
RIGHT JOIN Application.Cities ac ON ac.CityID = c.PostalCityID
GROUP BY
	ac.StateProvinceID
ORDER BY
	ac.StateProvinceID

--Q9. List of StockItems that the company purchased more than sold in the year of 2015.
WITH sold AS(
	SELECT
		ws.StockItemID,
		COUNT(ws.InvoiceID) AS count_sold
	FROM
		Warehouse.StockItemTransactions ws
	JOIN Sales.Invoices i ON ws.InvoiceID = i.InvoiceID
	GROUP BY
		ws.StockItemID
), purchase AS(
	SELECT
		ws.StockItemID,
		COUNT(ws.PurchaseOrderID) AS count_purchase
	FROM
		Warehouse.StockItemTransactions ws
	JOIN Purchasing.PurchaseOrders p ON ws.PurchaseOrderID = p.PurchaseOrderID
	GROUP BY
		ws.StockItemID
)
SELECT
	DISTINCT ws.StockItemID
FROM
	Warehouse.StockItemTransactions ws
JOIN sold s ON ws.StockItemID = s.StockItemID
JOIN purchase p ON ws.StockItemID = p.StockItemID
WHERE
	CAST(ws.TransactionOccurredWhen AS DATE) BETWEEN '2015-01-01' AND '2015-12-31'
	AND
	p.count_purchase > s.count_sold

--Q10. List of Customers and their phone number, together with the primary contact person’s name, to whom we did not sell more than 10 mugs (search by name) in the year 2016.
WITH cte_ID AS(
	SELECT
		c.CustomerID
	FROM
		Warehouse.StockItems si 
	JOIN Warehouse.StockItemTransactions st ON si.StockItemID = st.StockItemID
	JOIN Sales.Customers c ON c.CustomerID = st.CustomerID
	WHERE
		si.StockItemName LIKE '%mug%'
		AND
		YEAR(st.TransactionOccurredWhen) = '2016'
	GROUP BY
		c.CustomerID
	HAVING COUNT(si.StockItemID) <= 10
)
SELECT
	c.CustomerName,
	c.PhoneNumber,
	p.FullName
FROM
	Sales.Customers c
JOIN cte_ID i ON c.CustomerID = i.CustomerID
JOIN Application.People p ON p.PersonID = c.PrimaryContactPersonID

--Q11. List all the cities that were updated after 2015-01-01.

SELECT
	CityName
FROM
	Application.Cities
WHERE
	YEAR(ValidFrom) >= 2015


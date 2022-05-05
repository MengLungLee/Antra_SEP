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
	SUM(pol.OrderedOuters) AS total_quantity
FROM
	Purchasing.PurchaseOrders p
JOIN Warehouse.StockItemTransactions s ON p.PurchaseOrderID = s.PurchaseOrderID
JOIN Purchasing.PurchaseOrderLines pol ON pol.PurchaseOrderID = p.PurchaseOrderID
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
WITH cte_sold AS(
	SELECT
		ws.StockItemID,
		COUNT(ws.InvoiceID) AS count_sold
	FROM
		Warehouse.StockItemTransactions ws
	JOIN Sales.Invoices i ON ws.InvoiceID = i.InvoiceID
	GROUP BY
		ws.StockItemID
), cte_purchase AS(
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
JOIN cte_sold s ON ws.StockItemID = s.StockItemID
JOIN cte_purchase p ON ws.StockItemID = p.StockItemID
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

--Q12. List all the Order Detail (Stock Item name, delivery address, delivery state, city, country, customer name, 
-- customer contact person name, customer phone, quantity) for the date of 2014-07-01. Info should be relevant to that date.

WITH cte_filter_time AS(
	SELECT
		st.StockItemID,
		st.CustomerID,
		st.Quantity
	FROM
		Warehouse.StockItemTransactions st
	WHERE
		CAST(TransactionOccurredWhen AS DATE) = '2014-07-01'
)
SELECT
	si.StockItemName AS Stock_Item_name,
	sc.DeliveryAddressLine2 AS Delivery_add,
	asp.StateProvinceName AS Delivery_state, 
	ac.CityName AS Delivery_city,
	acty.CountryName AS Delivery_country,
	sc.CustomerName AS Customer_name,
	ap.FullName AS Contact_person_name,
	sc.PhoneNumber AS Customer_phone,
	st.Quantity
FROM
	cte_filter_time st
JOIN Warehouse.StockItems si ON st.StockItemID = si.StockItemID
JOIN Sales.Customers sc ON st.CustomerID = sc.CustomerID
JOIN Application.Cities ac ON ac.CityID = sc.DeliveryCityID
JOIN Application.StateProvinces asp ON asp.StateProvinceID = ac.StateProvinceID
JOIN Application.Countries acty ON acty.CountryID = asp.CountryID
JOIN Application.People ap ON sc.PrimaryContactPersonID = ap.PersonID

--Q13. List of stock item groups and total quantity purchased, total quantity sold, and the remaining stock quantity (quantity purchased – quantity sold)

WITH cte_sold AS(
	SELECT
		ws.StockItemID,
		SUM(i.Quantity) AS sum_sold
	FROM
		Warehouse.StockItemTransactions ws
	JOIN Sales.InvoiceLines i ON ws.StockItemID = i.StockItemID
	GROUP BY
		ws.StockItemID
), cte_purchase AS(
	SELECT
		ws.StockItemID,
		SUM(CAST(p.OrderedOuters AS BIGINT)) AS sum_purchased
	FROM
		Warehouse.StockItemTransactions ws
	JOIN Purchasing.PurchaseOrderLines p ON ws.StockItemID = p.StockItemID
	GROUP BY
		ws.StockItemID
)
SELECT
	wsg.StockGroupName,
	SUM(CAST(p.sum_purchased AS BIGINT)) AS total_purchased,
	SUM(CAST(s.sum_sold AS BIGINT)) AS total_sold,
	SUM(CAST(p.sum_purchased-s.sum_sold AS BIGINT)) AS remaining_stock
FROM
	Warehouse.StockGroups wsg
JOIN Warehouse.StockItemStockGroups wsistg ON wsg.StockGroupID = wsistg.StockGroupID
JOIN cte_sold s ON s.StockItemID = wsistg.StockItemID
JOIN cte_purchase p ON p.StockItemID = wsistg.StockItemID
GROUP BY
	wsg.StockGroupName

--Q14. List of Cities in the US and the stock item that the city got the most deliveries in 2016. If the city did not purchase any stock items in 2016, print “No Sales”.

WITH cte_count_stock AS(
	SELECT
		ps.DeliveryCityID,
		COUNT(ws.StockItemID) as count_stock
	FROM
		Purchasing.Suppliers ps
	JOIN Warehouse.StockItemTransactions ws ON ps.SupplierID = ws.SupplierID
	WHERE
		YEAR(TransactionOccurredWhen) = 2016
	GROUP BY
		ps.DeliveryCityID
)
SELECT
	ac.CityName,
	COALESCE(CAST(MAX(count_stock) AS CHAR), 'No sales') AS most_stock
FROM
	Application.Cities ac 
LEFT JOIN cte_count_stock cs ON ac.CityID = cs.DeliveryCityID
GROUP BY
	ac.CityName

--Q15. List any orders that had more than one delivery attempt (located in invoice table).

SELECT
	i.OrderID
FROM
	Sales.Invoices i
GROUP BY
	i.OrderID
HAVING COUNT(JSON_VALUE(ReturnedDeliveryData, '$.Events[1].Comment')) >= 1

--Q16. List all stock items that are manufactured in China. (Country of Manufacture)

SELECT
	si.StockItemName
FROM
	Warehouse.StockItems si
WHERE
	JSON_Value(si.CustomFields, '$.CountryOfManufacture' ) = 'China'

--Q17. Total quantity of stock items sold in 2015, group by country of manufacturing.

SELECT
	JSON_VALUE(si.CustomFields, '$.CountryOfManufacture') AS Country_M,
	SUM(i.Quantity) AS sum_sold
FROM
	Warehouse.StockItems si
JOIN Warehouse.StockItemTransactions st ON si.StockItemID = st.StockItemID
JOIN Sales.InvoiceLines i ON st.InvoiceID = i.InvoiceID
WHERE
	YEAR(st.TransactionOccurredWhen) = '2015'
GROUP BY
	JSON_VALUE(si.CustomFields, '$.CountryOfManufacture')

--Q18. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Stock Group Name, 2013, 2014, 2015, 2016, 2017]
IF OBJECT_ID('Sales.v_StockItem', 'view') IS NOT NULL
	DROP VIEW Sales.v_StockItem
GO
CREATE VIEW Sales.v_StockItem 
	WITH SCHEMABINDING 
	AS
	SELECT
		StockGroupName,
		[2013], [2014], [2015], [2016], [2017]
	FROM(
		SELECT
			wsg.StockGroupName,
			YEAR(st.TransactionOccurredWhen) AS T_Year,
			SUM(i.Quantity) AS total_sold
		FROM
			Warehouse.StockItemTransactions st
		JOIN Sales.InvoiceLines i ON st.InvoiceID = i.InvoiceID
		JOIN Warehouse.StockItemStockGroups wsistg ON st.StockItemID = wsistg.StockItemID
		JOIN Warehouse.StockGroups wsg ON wsg.StockGroupID = wsistg.StockGroupID
		WHERE
			YEAR(st.TransactionOccurredWhen) BETWEEN '2013' AND '2017'
		GROUP BY
			wsg.StockGroupName, YEAR(st.TransactionOccurredWhen)
		) sub
	PIVOT(
		SUM(total_sold)
		FOR T_Year IN ([2013], [2014], [2015], [2016], [2017])
	)P_table;

--Q19. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, …, Stock Group Name10]
IF OBJECT_ID('Sales.v_StockItem2', 'view') IS NOT NULL
	DROP VIEW Sales.v_StockItem2
GO
CREATE VIEW Sales.v_StockItem2 
	WITH SCHEMABINDING
	AS
	SELECT
		T_Year,
		[Novelty Items], [Clothing], [Mugs], 
		[T-Shirts], [Airline Novelties], [Computing Novelties],
		[USB Novelties], [Furry Footwear], [Toys]
		,[Packaging Materials]
	FROM
	(
		SELECT
			wsg.StockGroupName,
			YEAR(st.TransactionOccurredWhen) AS T_Year,
			SUM(i.Quantity) AS total_sold
		FROM
			Warehouse.StockItemTransactions st
		JOIN Sales.InvoiceLines i ON st.InvoiceID = i.InvoiceID
		JOIN Warehouse.StockItemStockGroups wsistg ON st.StockItemID = wsistg.StockItemID
		JOIN Warehouse.StockGroups wsg ON wsg.StockGroupID = wsistg.StockGroupID
		WHERE
			YEAR(st.TransactionOccurredWhen) BETWEEN '2013' AND '2017'
		GROUP BY
			wsg.StockGroupName, YEAR(st.TransactionOccurredWhen)
	) sub
	PIVOT(
		SUM(total_sold)
		FOR StockGroupName IN(	[Novelty Items], [Clothing], [Mugs], 
								[T-Shirts], [Airline Novelties], [Computing Novelties],
								[USB Novelties], [Furry Footwear], [Toys]
								,[Packaging Materials])
	)P_table;

--Q20. Create a function, input: order id; return: total of that order. 
-- List invoices and use that function to attach the order total to the other fields of invoices. 
USE [WideWorldImporters]
GO
IF OBJECT_ID('udfGetTotalOrder', 'function') IS NOT NULL
	DROP FUNCTION udfGetTotalOrder
GO
CREATE FUNCTION udfGetTotalOrder(@OrderId int)
RETURNS INT
AS
BEGIN
	DECLARE @total_order INT
	SELECT
		@total_order = COALESCE(SUM(il.Quantity), 0)
	FROM
		Sales.Invoices i
	JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
	WHERE
		@OrderId = i.OrderID
	RETURN @total_order
END

GO
SELECT
	o.OrderID,
	dbo.udfGetTotalOrder(o.OrderID) AS total_quantity
FROM
	Sales.Orders o

--Q20. Create a function, input: order id; return: total of that order. 
-- List invoices and use that function to attach the order total to the other fields of invoices. 
USE [WideWorldImporters]
GO
IF OBJECT_ID('udfGetTotalOrder', 'function') IS NOT NULL
	DROP FUNCTION udfGetTotalOrder
GO
CREATE FUNCTION udfGetTotalOrder(@OrderId int)
RETURNS INT
AS
BEGIN
	DECLARE @total_order INT
	SELECT
		@total_order = COALESCE(SUM(il.Quantity), 0)
	FROM
		Sales.Invoices i
	JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
	WHERE
		@OrderId = i.OrderID
	RETURN @total_order
END

GO
SELECT
	o.OrderID,
	dbo.udfGetTotalOrder(o.OrderID) AS total_quantity
FROM
	Sales.Orders o

--Q21. Create a new table called ods.Orders. Create a stored procedure, with proper error handling and transactions, that input is a date; when executed, it would find orders of that day, calculate order total, and save the information (order id, order date, order total, customer id) into the new table. If a given date is already existing in the new table, throw an error and roll back. Execute the stored procedure 5 times using different dates. 
USE [WideWorldImporters]
GO
CREATE SCHEMA [ods];
GO
DROP TABLE IF EXISTS ods.Orders
CREATE TABLE ods.Orders (
	OrderId INT NOT NULL PRIMARY KEY, 
	OrderDate DATE NOT NULL, 
	OrderTotal BIGINT, 
	CustomerId INT,
	CONSTRAINT FK_OrdersCustomers FOREIGN KEY (CustomerID)
		REFERENCES Sales.Customers(CustomerID)
)
GO
IF OBJECT_ID('Sales.uspGetOrderInfo', 'procedure') IS NOT NULL
	DROP PROCEDURE Sales.uspGetOrderInfo
GO
CREATE PROCEDURE Sales.uspGetOrderInfo
@OrderDate DATE
AS
BEGIN TRY
	IF TRIGGER_NESTLEVEL() > 1
		RETURN
	BEGIN TRANSACTION
		IF EXISTS (SELECT 1 FROM ods.Orders WHERE @OrderDate = OrderDate)
			BEGIN;
				THROW 50000, 'The record does exists', 1
				ROLLBACK TRANSACTION
			END
		ELSE
			BEGIN
			INSERT INTO ods.Orders
				SELECT
					o.OrderID,
					o.OrderDate,
					SUM(il.Quantity) AS Order_Total,
					o.CustomerID
				FROM
					Sales.Orders o
				JOIN Sales.Invoices i ON o.OrderID = i.OrderID
				JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
				WHERE
					@OrderDate = o.OrderDate
				GROUP BY
					o.OrderID,o.OrderDate,o.CustomerID
			END
	COMMIT TRANSACTION
END TRY
BEGIN CATCH
	SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage, XACT_STATE() AS X_STATE 
	IF (XACT_STATE()) = -1
		ROLLBACK TRANSACTION

	IF (XACT_STATE()) = 1
		COMMIT TRANSACTION
END CATCH

GO
EXECUTE Sales.uspGetOrderInfo '2013-01-01';
EXECUTE Sales.uspGetOrderInfo '2013-01-05';
EXECUTE Sales.uspGetOrderInfo '2013-01-10';
EXECUTE Sales.uspGetOrderInfo '2013-01-15';
EXECUTE Sales.uspGetOrderInfo '2013-01-01';

--Q22. Create a new table called ods.StockItem. It has following columns: [StockItemID], [StockItemName] ,[SupplierID] ,[ColorID] ,[UnitPackageID] ,[OuterPackageID] ,[Brand] ,[Size] ,[LeadTimeDays] ,[QuantityPerOuter] ,[IsChillerStock] ,[Barcode] ,[TaxRate]  ,[UnitPrice],[RecommendedRetailPrice] ,[TypicalWeightPerUnit] ,[MarketingComments]  ,[InternalComments], [CountryOfManufacture], [Range], [Shelflife]. Migrate all the data in the original stock item table.

USE [WideWorldImporters]
GO
DROP TABLE IF EXISTS ods.StockItem
CREATE TABLE ods.StockItem (
	StockItemID INT NOT NULL PRIMARY KEY, 
	StockItemName NVARCHAR(100) NOT NULL, 
	SupplierID INT NOT NULL, 
	ColorID INT,
	UnitPackageID INT NOT NULL,
	OuterPackageID INT NOT NULL,
	Brand NVARCHAR(50),
	Size NVARCHAR(20),
	LeadTimeDays INT NOT NULL,
	QuantityPerOuter INT NOT NULL,
	IsChillerStock INT NOT NULL,
	Barcode NVARCHAR(50),
	TaxRate decimal(18,3) NOT NULL,
	UnitPrice decimal(18,2) NOT NULL,
	RecommendedRetailPrice decimal(18,2),
	TypicalWeightPerUnit decimal(18,3) NOT NULL,
	MarketingComments NVARCHAR(MAX),
	InternalComments NVARCHAR(MAX), 
	CountryOfManufacture NVARCHAR(MAX), 
	Range NVARCHAR(20) , 
	Shelflife NVARCHAR(20),
	CONSTRAINT FK_Warehouse_StockItems_ColorID FOREIGN KEY (ColorID)
		REFERENCES Warehouse.Colors (ColorID),
	CONSTRAINT FK_Warehouse_StockItems_OuterPackageID FOREIGN KEY (OuterPackageID)
		REFERENCES Warehouse.PackageTypes (PackageTypeID),
	CONSTRAINT FK_Warehouse_StockItems_SupplierID FOREIGN KEY (SupplierID)
		REFERENCES Purchasing.Suppliers (SupplierID),
	CONSTRAINT FK_Warehouse_StockItems_UnitPackageID FOREIGN KEY (UnitPackageID)
		REFERENCES Warehouse.PackageTypes (PackageTypeID)
)
INSERT INTO ods.StockItem
SELECT
	StockItemID, StockItemName, SupplierID, ColorID, UnitPackageID, OuterPackageID, Brand, Size, LeadTimeDays, QuantityPerOuter, 
	IsChillerStock, Barcode, TaxRate, UnitPrice, RecommendedRetailPrice, TypicalWeightPerUnit, MarketingComments, InternalComments, 
	JSON_VALUE(CustomFields, '$."CountryOfManufacture"'), JSON_VALUE(CustomFields, '$."Range"'), JSON_VALUE(CustomFields, '$."ShelfLife"')
FROM
	Warehouse.StockItems

--Q23. Rewrite your stored procedure in (21). Now with a given date, it should wipe out all the order data prior to the input date and load the order data that was placed in the next 7 days following the input date.

USE [WideWorldImporters]
GO
IF OBJECT_ID('Sales.uspGetOrderInfo', 'procedure') IS NOT NULL
	DROP PROCEDURE Sales.uspGetOrderInfo
GO
CREATE PROCEDURE Sales.uspGetOrderInfo
@OrderDate DATE
AS
BEGIN TRY
	IF TRIGGER_NESTLEVEL() > 1
		RETURN
	BEGIN TRANSACTION
		DELETE FROM ods.Orders
		WHERE @OrderDate >= OrderDate

		INSERT INTO ods.Orders
		SELECT
			o.OrderID,
			o.OrderDate,
			SUM(il.Quantity) AS Order_Total,
			o.CustomerID
		FROM
			Sales.Orders o
		JOIN Sales.Invoices i ON o.OrderID = i.OrderID
		JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
		WHERE
			o.OrderDate BETWEEN @OrderDate AND DATEADD(DAY, 7, @OrderDate)
		GROUP BY
			o.OrderID,o.OrderDate,o.CustomerID
	COMMIT TRANSACTION
END TRY
BEGIN CATCH
	SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage, XACT_STATE() AS X_STATE 
	IF (XACT_STATE()) = -1
		ROLLBACK TRANSACTION

	IF (XACT_STATE()) = 1
		COMMIT TRANSACTION
END CATCH

GO
EXECUTE Sales.uspGetOrderInfo '2013-01-15';

--Q24. 
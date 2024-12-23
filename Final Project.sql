USE DWH_DATA_ANALYST

--Retrieval 1

SELECT borough.BoroughName, COUNT(*) AS Violations
FROM DimLocation loc INNER JOIN FactParkingViolation violation
ON loc.LocationKey = violation.LocationKey
INNER JOIN DimBorough borough
ON loc.BoroughCode=borough.BoroughCode
GROUP BY borough.BoroughName
ORDER BY 2 DESC

GO

CREATE PROCEDURE ViolationsByBorough
@BoroughName VARCHAR(15)
AS
BEGIN
	SELECT borough.BoroughName, COUNT(*) AS Violations
	FROM DimLocation loc INNER JOIN FactParkingViolation violation
	ON loc.LocationKey = violation.LocationKey
	INNER JOIN DimBorough borough
	ON loc.BoroughCode=borough.BoroughCode
	WHERE @BoroughName=borough.BoroughName
	GROUP BY borough.BoroughName
END

EXEC ViolationsByBorough 'Manhattan'

DROP PROCEDURE ViolationsByBorough

-- Retrieval 2

SELECT borough.BoroughName, DATENAME(dw,CAST(violation.IssueDate AS DATE)) AS NameOfDay,
	DATEPART(dw,CAST(violation.IssueDate AS DATE)) AS DayNum, COUNT(*) AS Violations
FROM DimLocation loc INNER JOIN FactParkingViolation violation
ON loc.LocationKey = violation.LocationKey
INNER JOIN DimBorough borough
ON loc.BoroughCode=borough.BoroughCode
GROUP BY borough.BoroughName, DATENAME(dw,CAST(violation.IssueDate AS DATE)), DATEPART(dw,CAST(violation.IssueDate AS DATE))
ORDER BY borough.BoroughName, DATEPART(dw,CAST(violation.IssueDate AS DATE))

GO

CREATE PROCEDURE ViolationByBoroughAndWeekday
@BoroughName VARCHAR(15),
@WeakdayName VARCHAR(10)
AS
BEGIN
	SELECT borough.BoroughName, DATENAME(dw,CAST(violation.IssueDate AS DATE)) AS NameOfDay,
		DATEPART(dw,CAST(violation.IssueDate AS DATE)) AS DayNum, COUNT(*) AS Violations
	FROM DimLocation loc INNER JOIN FactParkingViolation violation
	ON loc.LocationKey = violation.LocationKey
	INNER JOIN DimBorough borough
	ON loc.BoroughCode=borough.BoroughCode
	WHERE @BoroughName=borough.BoroughName AND @WeakdayName=DATENAME(dw,CAST(violation.IssueDate AS DATE))
	GROUP BY borough.BoroughName, DATENAME(dw,CAST(violation.IssueDate AS DATE)), DATEPART(dw,CAST(violation.IssueDate AS DATE))
END

EXEC ViolationByBoroughAndWeekday 'Manhattan','Wednesday'

DROP PROCEDURE ViolationByBoroughAndWeekday

-- Retrieval 3

SELECT TOP(5) ViolationCode, COUNT(*) AS Violations
FROM FactParkingViolation
WHERE YEAR(CAST(IssueDate AS DATE)) BETWEEN 2015 AND 2017
GROUP BY ViolationCode
ORDER BY 2 DESC

GO

CREATE PROCEDURE TopViolationsByCode
@TopNum INT
AS
BEGIN
	SELECT TOP(@TopNum) ViolationCode, COUNT(*) AS Violations
	FROM FactParkingViolation
	WHERE YEAR(CAST(IssueDate AS DATE)) BETWEEN 2015 AND 2017
	GROUP BY ViolationCode
	ORDER BY 2 DESC
END

EXEC TopViolationsByCode 20

DROP PROCEDURE TopViolationsByCode

-- Retrieval 4

SELECT *
FROM ( 
	SELECT color.ColorName, violation.ViolationCode, COUNT(*) AS Violations, RANK() OVER (PARTITION BY color.ColorName ORDER BY COUNT(*) DESC) AS Ranking
	FROM DimVehicle vehicle INNER JOIN FactParkingViolation violation
	ON vehicle.VehicleKey=violation.VehicleKey
	INNER JOIN DimColor color
	ON vehicle.VehicleColorCode=color.ColorCode
	WHERE YEAR(CAST(violation.IssueDate AS DATE)) BETWEEN 2015 AND 2017
		AND color.ColorName != 'UNKNOWN'
	GROUP BY color.ColorName, violation.ViolationCode
) AS R
WHERE R.Ranking < 3
ORDER BY R.ColorName

GO

CREATE PROCEDURE TopViolationsByColor
@Top INT
AS
BEGIN
	SELECT *
	FROM ( 
		SELECT color.ColorName, violation.ViolationCode, COUNT(*) AS Violations, RANK() OVER (PARTITION BY color.ColorName ORDER BY COUNT(*) DESC) AS Ranking
		FROM DimVehicle vehicle INNER JOIN FactParkingViolation violation
		ON vehicle.VehicleKey=violation.VehicleKey
		INNER JOIN DimColor color
		ON vehicle.VehicleColorCode=color.ColorCode
		WHERE YEAR(CAST(violation.IssueDate AS DATE)) BETWEEN 2015 AND 2017
			AND color.ColorName != 'UNKNOWN'
		GROUP BY color.ColorName, violation.ViolationCode
	) AS R
	WHERE R.Ranking < @Top + 1
	ORDER BY R.ColorName
END

EXEC TopViolationsByColor 5

DROP PROCEDURE TopViolationsByColor

-- Retrieval 5

SELECT COUNT(CASE WHEN R.Violation > 10 THEN 1 END) AS 'Over 10',
	COUNT(CASE WHEN R.Violation BETWEEN 5 AND 9 THEN 1 END) AS 'Between 5 And 9',
	COUNT(CASE WHEN R.Violation < 5 THEN 1 END) AS 'Under 5'
FROM (
	SELECT COUNT(*) AS Violation
	FROM FactParkingViolation
	WHERE YEAR(CAST(IssueDate AS DATE)) BETWEEN 2015 AND 2017
	GROUP BY VehicleKey
) AS R

-- Retrieval 6

SELECT *, CAST(ROUND(CAST(R.[Violations in 2017] AS FLOAT)/CAST(R.[Violations in 2015] AS FLOAT) * 100 - 100,2) AS VARCHAR)+'%' AS 'Growth Percentage'
FROM (
	SELECT dstate.StateName,
		COUNT(CASE WHEN YEAR(CAST(violation.IssueDate AS DATE)) = 2015 THEN 1 END) AS 'Violations in 2015',
		COUNT(CASE WHEN YEAR(CAST(violation.IssueDate AS DATE)) = 2016 THEN 1 END) AS 'Violations in 2016',
		COUNT(CASE WHEN YEAR(CAST(violation.IssueDate AS DATE)) = 2017 THEN 1 END) AS 'Violations in 2017'
	FROM DimState dstate INNER JOIN DimVehicle vehicle
	ON dstate.StateCode=vehicle.RegistrationStateCode
	INNER JOIN FactParkingViolation violation
	ON vehicle.VehicleKey=violation.VehicleKey
	WHERE YEAR(CAST(violation.IssueDate AS DATE)) BETWEEN 2015 AND 2017
	GROUP BY dstate.StateName
) AS R
ORDER BY R.StateName
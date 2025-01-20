DROP TABLE IF EXISTS warehouse;
CREATE TABLE warehouse
(
    ID                    VARCHAR(10),
    OnHandQuantity        INT,
    OnHandQuantityDelta   INT,
    event_type            VARCHAR(10),
    event_datetime        DATETIME
);

INSERT INTO warehouse VALUES
('SH0013', 278, 99, 'OutBound', CONVERT(DATETIME, '2020-05-25 00:25')),
('SH0012', 377, 31, 'InBound', CONVERT(DATETIME, '2020-05-24 22:00')),
('SH0011', 346, 1, 'OutBound', CONVERT(DATETIME, '2020-05-24 15:01')),
('SH0010', 346, 1, 'OutBound', CONVERT(DATETIME, '2020-05-23 05:00')),
('SH009', 348, 102, 'InBound', CONVERT(DATETIME, '2020-04-25 18:00')),
('SH008', 246, 43, 'InBound', CONVERT(DATETIME, '2020-04-25 02:00')),
('SH007', 203, 2, 'OutBound', CONVERT(DATETIME, '2020-02-25 09:00')),
('SH006', 205, 129, 'OutBound', CONVERT(DATETIME, '2020-02-18 07:00')),
('SH005', 334, 1, 'OutBound', CONVERT(DATETIME, '2020-02-18 08:00')),
('SH004', 335, 27, 'OutBound', CONVERT(DATETIME, '2020-01-29 05:00')),
('SH003', 362, 120, 'InBound', CONVERT(DATETIME, '2019-12-31 02:00')),
('SH002', 242, 8, 'OutBound', CONVERT(DATETIME, '2019-05-22 00:50')),
('SH001', 250, 250, 'InBound', CONVERT(DATETIME, '2019-05-20 00:45'));


WITH WH AS (
    SELECT * FROM warehouse
),
days AS (
    SELECT TOP 1 
        event_datetime, 
        OnHandQuantity,
        DATEADD(DAY, -90, event_datetime) AS day90,
        DATEADD(DAY, -180, event_datetime) AS day180,
        DATEADD(DAY, -270, event_datetime) AS day270,
        DATEADD(DAY, -365, event_datetime) AS day365
    FROM WH
    ORDER BY event_datetime DESC
),
inv_90_days AS (
    SELECT COALESCE(SUM(WH.OnHandQuantityDelta), 0) AS DaysOld_90
    FROM WH
    CROSS JOIN days
    WHERE WH.event_datetime >= days.day90
      AND event_type = 'InBound'
),
inv_90_days_final AS (
    SELECT 
        CASE 
            WHEN DaysOld_90 > OnHandQuantity THEN OnHandQuantity
            ELSE DaysOld_90
        END AS DaysOld_90
    FROM inv_90_days
    CROSS JOIN days
),
inv_180_days AS (
    SELECT COALESCE(SUM(WH.OnHandQuantityDelta), 0) AS DaysOld_180
    FROM WH
    CROSS JOIN days
    WHERE WH.event_datetime BETWEEN days.day180 AND days.day90
      AND event_type = 'InBound'
),
inv_180_days_final AS (
    SELECT 
        CASE 
            WHEN DaysOld_180 > (OnHandQuantity - DaysOld_90) THEN (OnHandQuantity - DaysOld_90)
            ELSE DaysOld_180
        END AS DaysOld_180
    FROM inv_180_days
    CROSS JOIN days
    CROSS JOIN inv_90_days_final
),
inv_270_days AS (
    SELECT COALESCE(SUM(WH.OnHandQuantityDelta), 0) AS DaysOld_270
    FROM WH
    CROSS JOIN days
    WHERE WH.event_datetime BETWEEN days.day270 AND days.day180
      AND event_type = 'InBound'
),
inv_270_days_final AS (
    SELECT 
        CASE 
            WHEN DaysOld_270 > (OnHandQuantity - (DaysOld_90 + DaysOld_180)) 
            THEN (OnHandQuantity - (DaysOld_90 + DaysOld_180))
            ELSE DaysOld_270
        END AS DaysOld_270
    FROM inv_270_days
    CROSS JOIN days
    CROSS JOIN inv_90_days_final
    CROSS JOIN inv_180_days_final
),
inv_365_days AS (
    SELECT COALESCE(SUM(WH.OnHandQuantityDelta), 0) AS DaysOld_365
    FROM WH
    CROSS JOIN days
    WHERE WH.event_datetime BETWEEN days.day365 AND days.day270
      AND event_type = 'InBound'
),
inv_365_days_final AS (
    SELECT 
        CASE 
            WHEN DaysOld_365 > (OnHandQuantity - (DaysOld_90 + DaysOld_180 + DaysOld_270)) 
            THEN (OnHandQuantity - (DaysOld_90 + DaysOld_180 + DaysOld_270))
            ELSE DaysOld_365
        END AS DaysOld_365
    FROM inv_365_days
    CROSS JOIN days
    CROSS JOIN inv_90_days_final
    CROSS JOIN inv_180_days_final
    CROSS JOIN inv_270_days_final
)
SELECT 
    DaysOld_90 AS "0-90 days old",
    DaysOld_180 AS "91-180 days old",
    DaysOld_270 AS "181-270 days old",
    DaysOld_365 AS "271-365 days old"
FROM inv_90_days_final
CROSS JOIN inv_180_days_final
CROSS JOIN inv_270_days_final
CROSS JOIN inv_365_days_final
CROSS JOIN days;

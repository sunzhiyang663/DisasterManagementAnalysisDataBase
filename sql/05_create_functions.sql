-- 第五部分：函数

-- 5.1 Haversine 距离计算（公里）
CREATE OR ALTER FUNCTION dbo.CalcDistance(
    @lat1 DECIMAL(10,7), @lon1 DECIMAL(10,7),
    @lat2 DECIMAL(10,7), @lon2 DECIMAL(10,7)
) RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @R DECIMAL(10,2) = 6371.0;
    DECLARE @dLat DECIMAL(20,15) = (@lat2 - @lat1) * PI() / 180.0;
    DECLARE @dLon DECIMAL(20,15) = (@lon2 - @lon1) * PI() / 180.0;
    DECLARE @a DECIMAL(20,15) =
        SIN(@dLat / 2) * SIN(@dLat / 2)
        + COS(@lat1 * PI() / 180.0) * COS(@lat2 * PI() / 180.0)
        * SIN(@dLon / 2) * SIN(@dLon / 2);
    DECLARE @c DECIMAL(20,15) = 2 * ATN2(SQRT(@a), SQRT(1 - @a));
    RETURN @R * @c;
END;
GO


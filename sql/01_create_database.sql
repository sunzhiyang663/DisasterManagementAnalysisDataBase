
-- 第一部分：数据库创建
IF DB_ID('DisasterResourceDB') IS NOT NULL
    DROP DATABASE DisasterResourceDB;
GO

CREATE DATABASE DisasterResourceDB;
GO

USE DisasterResourceDB;
GO


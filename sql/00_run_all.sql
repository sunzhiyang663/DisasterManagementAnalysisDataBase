-- 自然灾害资源调度与协同管理数据库 — 一键执行脚本
-- 使用方法（SSMS 中）：
--   1. 菜单 → 查询 → SQLCMD 模式
--   2. 打开此文件，按 F5 执行
-- 使用方法（命令行）：
--   sqlcmd -S <服务器> -U <用户名> -P <密码> -i "00_run_all.sql"
:setvar SQLDIR "C:\Users\zhiyangsun\Desktop\数据库大作业\sql"

-- 1. 创建数据库
:r $(SQLDIR)\01_create_database.sql

-- 2. 创建表
:r $(SQLDIR)\02_create_tables.sql

-- 3. 创建索引
:r $(SQLDIR)\03_create_indexes.sql

-- 4. 创建视图
:r $(SQLDIR)\04_create_views.sql

-- 5. 创建函数
:r $(SQLDIR)\05_create_functions.sql

-- 6. 创建存储过程
:r $(SQLDIR)\06_create_procedures.sql

-- 7. 创建触发器
:r $(SQLDIR)\07_create_triggers.sql

-- 8. 插入测试数据
:r $(SQLDIR)\08_insert_testdata.sql

-- 9. 创建作业（按需手动执行）
-- :r $(SQLDIR)\09_create_jobs.sql

-- 10. 验证查询（注释掉的示例，需要时自行执行）
-- :r $(SQLDIR)\10_verify_queries.sql

PRINT '========================================';
PRINT '  一键部署完成！数据库 DisasterResourceDB 已就绪';
PRINT '========================================';
GO

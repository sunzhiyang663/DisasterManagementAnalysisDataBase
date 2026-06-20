-- 第十部分：功能验证查询

-- 查看灾情总览
-- SELECT * FROM vw_DisasterOverview;

-- 查看仓库库存
-- SELECT * FROM vw_WarehouseStock ORDER BY warehouse_id;

-- 查看医院接诊能力
-- SELECT * FROM vw_HospitalCapacity;

-- 查看物资分类树
-- EXEC sp_GetCategoryTree;

-- 为汶川县(1)查看布洛芬(spec_id=1)的调拨推荐方案
-- EXEC sp_GetDispatchPlan @p_site_id = 1, @p_spec_id = 1, @p_quantity = 300;

-- 查看汶川县的物资需求汇总
-- EXEC sp_GetSiteDemandSummary @p_site_id = 1;

-- 查看汶川县周边 100 公里范围内资源
-- EXEC sp_GetNearbyResources @p_site_id = 1, @p_radius_km = 100;

-- 执行过期标记
-- EXEC sp_MarkExpiredBatches;

-- 脚本结束
PRINT N'========================================';
PRINT N'数据库创建完成！';
PRINT N'数据库名: DisasterResourceDB';

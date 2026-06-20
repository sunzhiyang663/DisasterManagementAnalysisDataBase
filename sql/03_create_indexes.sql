-- 第三部分：索引

-- 受灾点空间查询
CREATE NONCLUSTERED INDEX IX_disaster_sites_location
    ON disaster_sites(longitude, latitude);
GO

-- 库存调拨核心查询
CREATE NONCLUSTERED INDEX IX_batches_dispatch
    ON inventory_batches(warehouse_id, spec_id, is_expired, is_reserved)
    INCLUDE (current_quantity, expiry_date);
GO

-- 过期批次扫描
CREATE NONCLUSTERED INDEX IX_batches_expiry
    ON inventory_batches(expiry_date)
    WHERE is_expired = 0 AND current_quantity > 0;
GO

-- 受灾点需求查询
CREATE NONCLUSTERED INDEX IX_demands_site_status
    ON material_demands(site_id, status);
GO

-- 物资需求汇总
CREATE NONCLUSTERED INDEX IX_demands_spec
    ON material_demands(spec_id);
GO

-- 调拨需求关联
CREATE NONCLUSTERED INDEX IX_dispatch_demand
    ON dispatch_records(demand_id);
GO

-- 调拨状态筛选
CREATE NONCLUSTERED INDEX IX_dispatch_status
    ON dispatch_records(status);
GO

-- 床位历史查询
CREATE NONCLUSTERED INDEX IX_bedlogs_hospital_time
    ON bed_logs(hospital_id, changed_at);
GO

-- 分类树递归
CREATE NONCLUSTERED INDEX IX_categories_parent
    ON material_categories(parent_id);
GO

-- 医院空间查询
CREATE NONCLUSTERED INDEX IX_hospitals_location
    ON hospitals(longitude, latitude);
GO


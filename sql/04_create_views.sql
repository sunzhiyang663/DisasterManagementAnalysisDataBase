-- 第四部分：视图

-- 4.1 灾情总览
CREATE OR ALTER VIEW vw_DisasterOverview AS
SELECT
    ds.site_id,
    ds.site_name,
    ds.disaster_type,
    ds.severity_level,
    ds.status,
    COUNT(md.demand_id) AS total_demands,
    SUM(CASE WHEN md.status = N'已满足' THEN 1 ELSE 0 END) AS satisfied_demands,
    ISNULL(SUM(md.requested_quantity), 0) AS total_requested,
    ISNULL(SUM(md.fulfilled_quantity), 0) AS total_fulfilled,
    CAST(
        CASE WHEN ISNULL(SUM(md.requested_quantity), 0) > 0
        THEN SUM(md.fulfilled_quantity) * 100.0 / SUM(md.requested_quantity)
        ELSE 0 END AS DECIMAL(5,2)
    ) AS satisfaction_rate
FROM disaster_sites ds
LEFT JOIN material_demands md ON ds.site_id = md.site_id
GROUP BY ds.site_id, ds.site_name, ds.disaster_type, ds.severity_level, ds.status;
GO

-- 4.2 仓库库存总览
CREATE OR ALTER VIEW vw_WarehouseStock AS
SELECT
    w.warehouse_id,
    w.warehouse_name,
    w.warehouse_level,
    mc.category_name,
    ms.material_name,
    ms.specification,
    ms.unit,
    SUM(ib.current_quantity) AS total_stock,
    SUM(CASE WHEN ib.is_expired = 1 THEN ib.current_quantity ELSE 0 END) AS expired_stock,
    SUM(CASE WHEN ib.is_reserved = 1 THEN ib.current_quantity ELSE 0 END) AS reserved_stock,
    SUM(CASE WHEN ib.is_expired = 0 AND ib.is_reserved = 0
        THEN ib.current_quantity ELSE 0 END) AS available_stock
FROM warehouses w
INNER JOIN inventory_batches ib ON w.warehouse_id = ib.warehouse_id
INNER JOIN material_specs ms ON ib.spec_id = ms.spec_id
INNER JOIN material_categories mc ON ms.category_id = mc.category_id
GROUP BY w.warehouse_id, w.warehouse_name, w.warehouse_level,
         mc.category_name, ms.material_name, ms.specification, ms.unit;
GO

-- 4.3 医院接诊能力总览
CREATE OR ALTER VIEW vw_HospitalCapacity AS
SELECT
    hospital_id,
    hospital_name,
    hospital_level,
    total_beds,
    available_beds,
    total_beds - available_beds AS occupied_beds,
    CAST(available_beds * 100.0 / NULLIF(total_beds, 0) AS DECIMAL(5,2)) AS vacancy_rate,
    emergency_capacity,
    status
FROM hospitals;
GO


-- 第七部分：触发器

-- 7.1 调拨签收 → 自动更新需求状态
CREATE OR ALTER TRIGGER trg_DispatchSigned_UpdateDemand
ON dispatch_records
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted WHERE status = N'已签收')
    BEGIN
        UPDATE md
        SET fulfilled_quantity = ISNULL((
                SELECT SUM(dr.dispatch_quantity)
                FROM dispatch_records dr
                WHERE dr.demand_id = md.demand_id AND dr.status = N'已签收'
            ), 0),
            status = CASE
                WHEN ISNULL((
                    SELECT SUM(dr.dispatch_quantity)
                    FROM dispatch_records dr
                    WHERE dr.demand_id = md.demand_id AND dr.status = N'已签收'
                ), 0) >= md.requested_quantity THEN N'已满足'
                WHEN ISNULL((
                    SELECT SUM(dr.dispatch_quantity)
                    FROM dispatch_records dr
                    WHERE dr.demand_id = md.demand_id AND dr.status = N'已签收'
                ), 0) > 0 THEN N'部分满足'
                ELSE N'待满足'
            END,
            updated_at = GETDATE()
        FROM material_demands md
        INNER JOIN inserted i ON md.demand_id = i.demand_id
        WHERE i.status = N'已签收';
    END
END;
GO

-- 7.2 床位变动 → 自动更新医院空余床位
CREATE OR ALTER TRIGGER trg_BedLog_UpdateHospital
ON bed_logs
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE h
    SET available_beds = i.available_beds_after,
        status = CASE
            WHEN i.available_beds_after <= 0 THEN N'满载'
            WHEN i.available_beds_after < h.total_beds * 0.1 THEN N'超负荷'
            ELSE N'正常'
        END,
        updated_at = GETDATE()
    FROM hospitals h
    INNER JOIN inserted i ON h.hospital_id = i.hospital_id;
END;
GO

-- 7.3（已移除 trg_InventoryChange_Log）
-- 库存变动日志由存储过程 sp_ReserveBatch / sp_ConfirmDispatch / sp_MarkExpiredBatches
-- 及测试数据脚本显式写入 inventory_change_logs，避免触发器与存储过程双写

-- 7.4 灾情变更 → 自动记录状态历史
CREATE OR ALTER TRIGGER trg_DisasterSite_StatusLog
ON disaster_sites
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- severity_level 变更
    INSERT INTO site_status_logs
        (site_id, changed_field, old_value, new_value, operator_name, remark)
    SELECT i.site_id, N'severity_level',
           CAST(d.severity_level AS NVARCHAR(10)),
           CAST(i.severity_level AS NVARCHAR(10)),
           N'系统', N'严重程度等级变更'
    FROM inserted i
    INNER JOIN deleted d ON i.site_id = d.site_id
    WHERE i.severity_level != d.severity_level;

    -- affected_population 变更
    INSERT INTO site_status_logs
        (site_id, changed_field, old_value, new_value, operator_name, remark)
    SELECT i.site_id, N'affected_population',
           CAST(d.affected_population AS NVARCHAR(20)),
           CAST(i.affected_population AS NVARCHAR(20)),
           N'系统', N'受影响人数更新'
    FROM inserted i
    INNER JOIN deleted d ON i.site_id = d.site_id
    WHERE i.affected_population != d.affected_population;

    -- status 变更
    INSERT INTO site_status_logs
        (site_id, changed_field, old_value, new_value, operator_name, remark)
    SELECT i.site_id, N'status',
           CAST(d.status AS NVARCHAR(20)),
           CAST(i.status AS NVARCHAR(20)),
           N'系统', N'救援状态变更'
    FROM inserted i
    INNER JOIN deleted d ON i.site_id = d.site_id
    WHERE i.status != d.status;
END;
GO

-- 7.5 入库自动计算到期日期
CREATE OR ALTER TRIGGER trg_AutoSetExpiryDate
ON inventory_batches
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO inventory_batches
        (warehouse_id, spec_id, initial_quantity, current_quantity,
         production_date, expiry_date, is_expired, is_reserved,
         reserved_for_demand_id, stored_at, updated_at)
    SELECT
        i.warehouse_id,
        i.spec_id,
        i.initial_quantity,
        i.current_quantity,
        i.production_date,
        CASE
            WHEN ms.shelf_life_days IS NOT NULL
            THEN DATEADD(DAY, ms.shelf_life_days, i.production_date)
            ELSE NULL
        END,
        CASE
            WHEN ms.shelf_life_days IS NOT NULL
                 AND DATEADD(DAY, ms.shelf_life_days, i.production_date) < CAST(GETDATE() AS DATE)
            THEN 1 ELSE 0
        END,
        ISNULL(i.is_reserved, 0),
        i.reserved_for_demand_id,
        ISNULL(i.stored_at, GETDATE()),
        ISNULL(i.updated_at, GETDATE())
    FROM inserted i
    INNER JOIN material_specs ms ON i.spec_id = ms.spec_id;

    -- 入库日志交由调用方（存储过程或测试数据脚本）显式记录
END;
GO


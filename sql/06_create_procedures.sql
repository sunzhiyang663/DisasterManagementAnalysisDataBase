-- 第六部分：存储过程

-- 6.1 智能调拨推荐方案
CREATE OR ALTER PROCEDURE sp_GetDispatchPlan
    @p_site_id      INT,
    @p_spec_id      INT,
    @p_quantity     INT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #dispatch_plan (
        warehouse_id        INT,
        warehouse_name      NVARCHAR(100),
        distance_km         DECIMAL(10,2),
        batch_id            INT,
        spec_name           NVARCHAR(100),
        current_quantity    INT,
        allocatable_qty     INT,
        expiry_date         DATE,
        priority_rank       INT
    );

    INSERT INTO #dispatch_plan
    SELECT
        w.warehouse_id,
        w.warehouse_name,
        dbo.CalcDistance(s.latitude, s.longitude, w.latitude, w.longitude),
        ib.batch_id,
        ms.material_name,
        ib.current_quantity,
        CASE
            WHEN SUM(ib.current_quantity) OVER (
                ORDER BY
                    dbo.CalcDistance(s.latitude, s.longitude, w.latitude, w.longitude),
                    ib.expiry_date ASC
            ) <= @p_quantity THEN ib.current_quantity
            ELSE @p_quantity - ISNULL(SUM(ib.current_quantity) OVER (
                ORDER BY
                    dbo.CalcDistance(s.latitude, s.longitude, w.latitude, w.longitude),
                    ib.expiry_date ASC
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0)
        END,
        ib.expiry_date,
        ROW_NUMBER() OVER (
            ORDER BY
                dbo.CalcDistance(s.latitude, s.longitude, w.latitude, w.longitude),
                ib.expiry_date ASC
        )
    FROM disaster_sites s
    CROSS JOIN warehouses w
    INNER JOIN inventory_batches ib ON w.warehouse_id = ib.warehouse_id
    INNER JOIN material_specs ms ON ib.spec_id = ms.spec_id
    WHERE s.site_id = @p_site_id
        AND ib.spec_id = @p_spec_id
        AND ib.is_expired = 0
        AND ib.is_reserved = 0
        AND ib.current_quantity > 0
        AND w.status = N'正常';

    SELECT
        warehouse_id,
        warehouse_name,
        distance_km,
        batch_id,
        spec_name,
        current_quantity,
        allocatable_qty,
        expiry_date,
        priority_rank
    FROM #dispatch_plan
    WHERE allocatable_qty > 0
    ORDER BY priority_rank;

    DROP TABLE #dispatch_plan;
END;
GO

-- 6.2 执行预留
CREATE OR ALTER PROCEDURE sp_ReserveBatch
    @p_batch_id         INT,
    @p_demand_id        INT,
    @p_quantity         INT,
    @p_operator_name    NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    DECLARE @p_site_id INT;
    SELECT @p_site_id = site_id FROM material_demands WHERE demand_id = @p_demand_id;

    IF NOT EXISTS (
        SELECT 1 FROM inventory_batches WITH (UPDLOCK, HOLDLOCK)
        WHERE batch_id = @p_batch_id
          AND is_expired = 0
          AND is_reserved = 0
          AND current_quantity >= @p_quantity
    )
    BEGIN
        ROLLBACK;
        THROW 50001, '库存不足或已被预留，请刷新后重试', 1;
        RETURN;
    END

    UPDATE inventory_batches
    SET is_reserved = 1,
        reserved_for_demand_id = @p_demand_id,
        updated_at = GETDATE()
    WHERE batch_id = @p_batch_id;

    INSERT INTO inventory_change_logs
        (batch_id, change_type, change_quantity, quantity_after,
         related_site_id, related_demand_id, operator_name, remark)
    VALUES
        (@p_batch_id, N'预留', 0,
         (SELECT current_quantity FROM inventory_batches WHERE batch_id = @p_batch_id),
         @p_site_id, @p_demand_id, @p_operator_name, N'预留物资待调拨');

    COMMIT;
    PRINT N'预留成功';
END;
GO

-- 6.3 确认出库
CREATE OR ALTER PROCEDURE sp_ConfirmDispatch
    @p_demand_id        INT,
    @p_batch_id         INT,
    @p_quantity         INT,
    @p_operator_name    NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    DECLARE @site_id INT;
    SELECT @site_id = site_id FROM material_demands WHERE demand_id = @p_demand_id;

    IF NOT EXISTS (
        SELECT 1 FROM inventory_batches
        WHERE batch_id = @p_batch_id
          AND is_reserved = 1
          AND reserved_for_demand_id = @p_demand_id
          AND current_quantity >= @p_quantity
    )
    BEGIN
        ROLLBACK;
        THROW 50002, '批次未预留或预留与需求不匹配，无法出库', 1;
        RETURN;
    END

    UPDATE inventory_batches
    SET current_quantity = current_quantity - @p_quantity,
        is_reserved = CASE WHEN current_quantity - @p_quantity <= 0
                           THEN 0 ELSE 1 END,
        reserved_for_demand_id = CASE WHEN current_quantity - @p_quantity <= 0
                                      THEN NULL ELSE reserved_for_demand_id END,
        updated_at = GETDATE()
    WHERE batch_id = @p_batch_id;

    INSERT INTO dispatch_records
        (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id,
         status, dispatched_by)
    SELECT @p_demand_id, @p_batch_id, @p_quantity, ib.warehouse_id, @site_id,
           N'运输中', @p_operator_name
    FROM inventory_batches ib
    WHERE ib.batch_id = @p_batch_id;

    INSERT INTO inventory_change_logs
        (batch_id, change_type, change_quantity, quantity_after,
         related_site_id, related_demand_id, operator_name, remark)
    SELECT @p_batch_id, N'出库', -@p_quantity, current_quantity,
           @site_id, @p_demand_id, @p_operator_name, N'确认调拨出库'
    FROM inventory_batches
    WHERE batch_id = @p_batch_id;

    COMMIT;
    PRINT N'出库成功';
END;
GO

-- 6.4 标记过期批次
CREATE OR ALTER PROCEDURE sp_MarkExpiredBatches
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO inventory_change_logs
        (batch_id, change_type, change_quantity, quantity_after,
         operator_name, remark)
    SELECT batch_id, N'过期报废', -current_quantity, 0,
           N'系统', N'系统自动标记过期'
    FROM inventory_batches
    WHERE expiry_date < CAST(GETDATE() AS DATE)
      AND is_expired = 0
      AND current_quantity > 0;

    UPDATE inventory_batches
    SET is_expired = 1,
        updated_at = GETDATE()
    WHERE expiry_date < CAST(GETDATE() AS DATE)
      AND is_expired = 0
      AND current_quantity > 0;

    PRINT N'过期批次标记完成';
END;
GO

-- 6.5 递归查询物资分类树
CREATE OR ALTER PROCEDURE sp_GetCategoryTree
AS
BEGIN
    SET NOCOUNT ON;

    WITH category_tree AS (
        SELECT
            category_id,
            parent_id,
            category_name,
            CAST(category_name AS NVARCHAR(500)) AS full_path,
            0 AS depth
        FROM material_categories
        WHERE parent_id IS NULL
        UNION ALL
        SELECT
            c.category_id,
            c.parent_id,
            c.category_name,
            CAST(t.full_path + N' → ' + c.category_name AS NVARCHAR(500)),
            t.depth + 1
        FROM material_categories c
        INNER JOIN category_tree t ON c.parent_id = t.category_id
    )
    SELECT * FROM category_tree ORDER BY full_path;
END;
GO

-- 6.6 受灾点需求汇总
CREATE OR ALTER PROCEDURE sp_GetSiteDemandSummary
    @p_site_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        md.demand_id,
        ds.site_name,
        ms.material_name,
        ms.specification,
        ms.unit,
        md.requested_quantity,
        md.fulfilled_quantity,
        md.requested_quantity - md.fulfilled_quantity AS shortage,
        md.urgency_level,
        md.status,
        md.publisher_name,
        md.published_at
    FROM material_demands md
    INNER JOIN disaster_sites ds ON md.site_id = ds.site_id
    INNER JOIN material_specs ms ON md.spec_id = ms.spec_id
    WHERE (@p_site_id IS NULL OR md.site_id = @p_site_id)
    ORDER BY
        CASE md.urgency_level WHEN N'特急' THEN 1 WHEN N'紧急' THEN 2 ELSE 3 END,
        md.published_at DESC;
END;
GO

-- 6.7 查询受灾点周边资源
CREATE OR ALTER PROCEDURE sp_GetNearbyResources
    @p_site_id      INT,
    @p_radius_km    DECIMAL(10,2) = 50
AS
BEGIN
    SET NOCOUNT ON;

    -- 周边仓库
    SELECT
        N'仓库' AS resource_type,
        w.warehouse_name AS name,
        w.warehouse_level AS level_or_specialty,
        dbo.CalcDistance(
            (SELECT latitude FROM disaster_sites WHERE site_id = @p_site_id),
            (SELECT longitude FROM disaster_sites WHERE site_id = @p_site_id),
            w.latitude, w.longitude
        ) AS distance_km,
        w.contact_person,
        w.contact_phone
    FROM warehouses w
    WHERE dbo.CalcDistance(
        (SELECT latitude FROM disaster_sites WHERE site_id = @p_site_id),
        (SELECT longitude FROM disaster_sites WHERE site_id = @p_site_id),
        w.latitude, w.longitude
    ) <= @p_radius_km
      AND w.status = N'正常'

    UNION ALL

    -- 周边医院
    SELECT
        N'医院' AS resource_type,
        h.hospital_name AS name,
        h.hospital_level AS level_or_specialty,
        dbo.CalcDistance(
            (SELECT latitude FROM disaster_sites WHERE site_id = @p_site_id),
            (SELECT longitude FROM disaster_sites WHERE site_id = @p_site_id),
            h.latitude, h.longitude
        ) AS distance_km,
        h.contact_person,
        h.contact_phone
    FROM hospitals h
    WHERE dbo.CalcDistance(
        (SELECT latitude FROM disaster_sites WHERE site_id = @p_site_id),
        (SELECT longitude FROM disaster_sites WHERE site_id = @p_site_id),
        h.latitude, h.longitude
    ) <= @p_radius_km
      AND h.status != N'停诊'

    ORDER BY distance_km;
END;
GO

-- 6.8 更新医院床位
CREATE OR ALTER PROCEDURE sp_UpdateBedStatus
    @p_hospital_id      INT,
    @p_change_type      NVARCHAR(10),
    @p_change_amount    INT,
    @p_operator_name    NVARCHAR(50),
    @p_remark           NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRANSACTION;

    DECLARE @new_available INT;

    IF @p_change_type IN (N'收治', N'转院')
        SET @new_available = (SELECT available_beds FROM hospitals
                              WHERE hospital_id = @p_hospital_id) + @p_change_amount;
    ELSE IF @p_change_type IN (N'出院', N'扩容')
        SET @new_available = (SELECT available_beds FROM hospitals
                              WHERE hospital_id = @p_hospital_id) + @p_change_amount;
    ELSE IF @p_change_type = N'缩容'
        SET @new_available = (SELECT available_beds FROM hospitals
                              WHERE hospital_id = @p_hospital_id) + @p_change_amount;

    IF @new_available < 0
    BEGIN
        ROLLBACK;
        THROW 50003, '床位不足，操作失败', 1;
        RETURN;
    END

    IF @new_available > (SELECT total_beds FROM hospitals WHERE hospital_id = @p_hospital_id)
       AND @p_change_type NOT IN (N'扩容', N'缩容')
    BEGIN
        ROLLBACK;
        THROW 50004, '空余床位不能超过总床位数', 1;
        RETURN;
    END

    -- 写入日志
    INSERT INTO bed_logs
        (hospital_id, change_type, change_amount,
         available_beds_after, operator_name, remark)
    VALUES
        (@p_hospital_id, @p_change_type, @p_change_amount,
         @new_available, @p_operator_name, @p_remark);

    -- 更新医院（触发器会进一步更新 status）
    UPDATE hospitals
    SET available_beds = @new_available,
        updated_at = GETDATE()
    WHERE hospital_id = @p_hospital_id;

    COMMIT;
    PRINT N'床位更新成功';
END;
GO

-- 6.9 释放超时预留
CREATE OR ALTER PROCEDURE sp_ReleaseStaleReservations
    @p_timeout_hours INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO inventory_change_logs
        (batch_id, change_type, change_quantity, quantity_after,
         operator_name, remark)
    SELECT batch_id, N'取消预留', 0, current_quantity,
           N'系统', N'预留超时自动释放'
    FROM inventory_batches
    WHERE is_reserved = 1
      AND updated_at < DATEADD(HOUR, -@p_timeout_hours, GETDATE());

    UPDATE inventory_batches
    SET is_reserved = 0,
        reserved_for_demand_id = NULL,
        updated_at = GETDATE()
    WHERE is_reserved = 1
      AND updated_at < DATEADD(HOUR, -@p_timeout_hours, GETDATE());

    PRINT N'超时预留已释放';
END;
GO


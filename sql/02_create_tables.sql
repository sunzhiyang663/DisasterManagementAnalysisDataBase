-- 第二部分：建表语句（14 张表）

-- 2.1 受灾点表
CREATE TABLE disaster_sites (
    site_id             INT IDENTITY(1,1) PRIMARY KEY,
    site_name           NVARCHAR(100)   NOT NULL,
    disaster_type       NVARCHAR(20)    NOT NULL,
    severity_level      TINYINT         NOT NULL,
    affected_population INT             NOT NULL DEFAULT 0,
    longitude           DECIMAL(10,7)   NOT NULL,
    latitude            DECIMAL(10,7)   NOT NULL,
    rescue_progress     NVARCHAR(500)   NULL,
    status              NVARCHAR(10)    NOT NULL DEFAULT N'救援中',
    reported_at         DATETIME2       NOT NULL DEFAULT GETDATE(),
    contact_person      NVARCHAR(50)    NOT NULL,
    contact_phone       NVARCHAR(20)    NOT NULL,

    CONSTRAINT CK_disaster_sites_type
        CHECK (disaster_type IN (N'地震', N'洪水', N'台风', N'山体滑坡', N'泥石流', N'其他')),
    CONSTRAINT CK_disaster_sites_severity
        CHECK (severity_level BETWEEN 1 AND 5),
    CONSTRAINT CK_disaster_sites_status
        CHECK (status IN (N'救援中', N'已控制', N'已解除'))
);
GO

-- 2.2 物资分类表（自引用树形结构）
CREATE TABLE material_categories (
    category_id     INT IDENTITY(1,1) PRIMARY KEY,
    parent_id       INT             NULL,
    category_name   NVARCHAR(100)   NOT NULL,
    description     NVARCHAR(200)   NULL,

    CONSTRAINT FK_categories_parent
        FOREIGN KEY (parent_id) REFERENCES material_categories(category_id)
);
GO

-- 2.3 物资规格表
CREATE TABLE material_specs (
    spec_id         INT IDENTITY(1,1) PRIMARY KEY,
    category_id     INT             NOT NULL,
    material_name   NVARCHAR(100)   NOT NULL,
    specification   NVARCHAR(100)   NULL,
    unit            NVARCHAR(20)    NOT NULL,
    shelf_life_days INT             NULL,
    description     NVARCHAR(200)   NULL,

    CONSTRAINT FK_specs_category
        FOREIGN KEY (category_id) REFERENCES material_categories(category_id)
);
GO

-- 2.4 仓库表
CREATE TABLE warehouses (
    warehouse_id    INT IDENTITY(1,1) PRIMARY KEY,
    warehouse_name  NVARCHAR(100)   NOT NULL,
    warehouse_level NVARCHAR(10)    NOT NULL,
    longitude       DECIMAL(10,7)   NOT NULL,
    latitude        DECIMAL(10,7)   NOT NULL,
    address         NVARCHAR(200)   NOT NULL,
    status          NVARCHAR(10)    NOT NULL DEFAULT N'正常',
    contact_person  NVARCHAR(50)    NOT NULL,
    contact_phone   NVARCHAR(20)    NOT NULL,

    CONSTRAINT CK_warehouses_level
        CHECK (warehouse_level IN (N'国家级', N'省级', N'市级', N'县级')),
    CONSTRAINT CK_warehouses_status
        CHECK (status IN (N'正常', N'满仓', N'维护中'))
);
GO

-- 2.5 库存批次表
CREATE TABLE inventory_batches (
    batch_id                INT IDENTITY(1,1) PRIMARY KEY,
    warehouse_id            INT             NOT NULL,
    spec_id                 INT             NOT NULL,
    initial_quantity        INT             NOT NULL,
    current_quantity        INT             NOT NULL,
    production_date         DATE            NOT NULL,
    expiry_date             DATE            NULL,
    is_expired              BIT             NOT NULL DEFAULT 0,
    is_reserved             BIT             NOT NULL DEFAULT 0,
    reserved_for_demand_id  INT             NULL,
    stored_at               DATETIME2       NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_batches_initial_qty CHECK (initial_quantity > 0),
    CONSTRAINT CK_batches_current_qty CHECK (current_quantity >= 0),

    CONSTRAINT FK_batches_warehouse
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT FK_batches_spec
        FOREIGN KEY (spec_id) REFERENCES material_specs(spec_id)
);
GO

-- 2.6 库存变动日志表
CREATE TABLE inventory_change_logs (
    log_id              INT IDENTITY(1,1) PRIMARY KEY,
    batch_id            INT             NOT NULL,
    change_type         NVARCHAR(10)    NOT NULL,
    change_quantity     INT             NOT NULL,
    quantity_after      INT             NOT NULL,
    related_site_id     INT             NULL,
    related_demand_id   INT             NULL,
    operator_name       NVARCHAR(50)    NOT NULL,
    remark              NVARCHAR(200)   NULL,
    changed_at          DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_logs_change_type
        CHECK (change_type IN (N'入库', N'出库', N'过期报废', N'预留', N'取消预留', N'盘点调整')),

    CONSTRAINT FK_logs_batch
        FOREIGN KEY (batch_id) REFERENCES inventory_batches(batch_id),
    CONSTRAINT FK_logs_site
        FOREIGN KEY (related_site_id) REFERENCES disaster_sites(site_id)
);
GO

-- 2.7 物资需求表
CREATE TABLE material_demands (
    demand_id           INT IDENTITY(1,1) PRIMARY KEY,
    site_id             INT             NOT NULL,
    spec_id             INT             NOT NULL,
    requested_quantity  INT             NOT NULL,
    fulfilled_quantity  INT             NOT NULL DEFAULT 0,
    urgency_level       NVARCHAR(5)     NOT NULL,
    status              NVARCHAR(10)    NOT NULL DEFAULT N'待满足',
    publisher_name      NVARCHAR(50)    NOT NULL,
    remark              NVARCHAR(200)   NULL,
    published_at        DATETIME2       NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_demands_requested_qty CHECK (requested_quantity > 0),
    CONSTRAINT CK_demands_urgency
        CHECK (urgency_level IN (N'一般', N'紧急', N'特急')),
    CONSTRAINT CK_demands_status
        CHECK (status IN (N'待满足', N'部分满足', N'已满足', N'已关闭')),

    CONSTRAINT FK_demands_site
        FOREIGN KEY (site_id) REFERENCES disaster_sites(site_id),
    CONSTRAINT FK_demands_spec
        FOREIGN KEY (spec_id) REFERENCES material_specs(spec_id)
);
GO

-- 补建 inventory_batches 对 material_demands 的外键（因建表顺序先于 material_demands）
ALTER TABLE inventory_batches
    ADD CONSTRAINT FK_batches_reserved_demand
        FOREIGN KEY (reserved_for_demand_id) REFERENCES material_demands(demand_id);
GO

-- 2.8 物资调拨记录表
CREATE TABLE dispatch_records (
    dispatch_id         INT IDENTITY(1,1) PRIMARY KEY,
    demand_id           INT             NOT NULL,
    batch_id            INT             NOT NULL,
    dispatch_quantity   INT             NOT NULL,
    from_warehouse_id   INT             NOT NULL,
    to_site_id          INT             NOT NULL,
    status              NVARCHAR(10)    NOT NULL DEFAULT N'运输中',
    dispatched_by       NVARCHAR(50)    NOT NULL,
    dispatched_at       DATETIME2       NOT NULL DEFAULT GETDATE(),
    arrived_at          DATETIME2       NULL,
    signed_at           DATETIME2       NULL,

    CONSTRAINT CK_dispatch_qty CHECK (dispatch_quantity > 0),
    CONSTRAINT CK_dispatch_status
        CHECK (status IN (N'运输中', N'已到达', N'已签收')),

    CONSTRAINT FK_dispatch_demand
        FOREIGN KEY (demand_id) REFERENCES material_demands(demand_id),
    CONSTRAINT FK_dispatch_batch
        FOREIGN KEY (batch_id) REFERENCES inventory_batches(batch_id),
    CONSTRAINT FK_dispatch_warehouse
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT FK_dispatch_site
        FOREIGN KEY (to_site_id) REFERENCES disaster_sites(site_id)
);
GO

-- 2.9 医院表
CREATE TABLE hospitals (
    hospital_id         INT IDENTITY(1,1) PRIMARY KEY,
    hospital_name       NVARCHAR(100)   NOT NULL,
    hospital_level      NVARCHAR(10)    NOT NULL,
    total_beds          INT             NOT NULL,
    available_beds      INT             NOT NULL,
    emergency_capacity  INT             NOT NULL,
    longitude           DECIMAL(10,7)   NOT NULL,
    latitude            DECIMAL(10,7)   NOT NULL,
    address             NVARCHAR(200)   NOT NULL,
    status              NVARCHAR(10)    NOT NULL DEFAULT N'正常',
    contact_person      NVARCHAR(50)    NOT NULL,
    contact_phone       NVARCHAR(20)    NOT NULL,
    updated_at          DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_hospitals_level
        CHECK (hospital_level IN (N'三甲', N'三乙', N'二甲', N'二乙', N'社区')),
    CONSTRAINT CK_hospitals_total_beds CHECK (total_beds >= 0),
    CONSTRAINT CK_hospitals_avail_beds CHECK (available_beds >= 0),
    CONSTRAINT CK_hospitals_emergency CHECK (emergency_capacity >= 0),
    CONSTRAINT CK_hospitals_status
        CHECK (status IN (N'正常', N'满载', N'超负荷', N'停诊'))
);
GO

-- 2.10 床位变动日志表
CREATE TABLE bed_logs (
    log_id              INT IDENTITY(1,1) PRIMARY KEY,
    hospital_id         INT             NOT NULL,
    change_type         NVARCHAR(10)    NOT NULL,
    change_amount       INT             NOT NULL,
    available_beds_after INT            NOT NULL,
    operator_name       NVARCHAR(50)    NOT NULL,
    remark              NVARCHAR(200)   NULL,
    changed_at          DATETIME2       NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_bedlogs_change_type
        CHECK (change_type IN (N'收治', N'出院', N'转院', N'扩容', N'缩容')),

    CONSTRAINT FK_bedlogs_hospital
        FOREIGN KEY (hospital_id) REFERENCES hospitals(hospital_id)
);
GO

-- 2.11 灾情状态日志表
CREATE TABLE site_status_logs (
    log_id          INT IDENTITY(1,1) PRIMARY KEY,
    site_id         INT             NOT NULL,
    changed_field   NVARCHAR(30)    NOT NULL,
    old_value       NVARCHAR(100)   NULL,
    new_value       NVARCHAR(100)   NOT NULL,
    operator_name   NVARCHAR(50)    NOT NULL,
    changed_at      DATETIME2       NOT NULL DEFAULT GETDATE(),
    remark          NVARCHAR(200)   NULL,

    CONSTRAINT FK_sitestatus_site
        FOREIGN KEY (site_id) REFERENCES disaster_sites(site_id)
);
GO

-- 2.12 应急行动记录表（父表）
CREATE TABLE emergency_operations (
    operation_id        INT IDENTITY(1,1) PRIMARY KEY,
    operation_type      NVARCHAR(10)    NOT NULL,
    from_location_type  NVARCHAR(10)    NOT NULL,
    from_site_id        INT             NULL,
    from_hospital_id    INT             NULL,
    to_location_type    NVARCHAR(10)    NOT NULL,
    to_site_id          INT             NULL,
    to_hospital_id      INT             NULL,
    vehicle_info        NVARCHAR(100)   NULL,
    status              NVARCHAR(10)    NOT NULL DEFAULT N'待出发',
    created_by          NVARCHAR(50)    NOT NULL,
    commander           NVARCHAR(50)    NULL,
    scheduled_at        DATETIME2       NOT NULL,
    departed_at         DATETIME2       NULL,
    arrived_at          DATETIME2       NULL,
    completed_at        DATETIME2       NULL,
    remark              NVARCHAR(300)   NULL,

    CONSTRAINT CK_emergency_type
        CHECK (operation_type IN (N'患者转运', N'医疗派遣')),
    CONSTRAINT CK_emergency_from_loc
        CHECK (from_location_type IN (N'受灾点', N'医院')),
    CONSTRAINT CK_emergency_to_loc
        CHECK (to_location_type IN (N'受灾点', N'医院')),
    CONSTRAINT CK_emergency_status
        CHECK (status IN (N'待出发', N'行进中', N'已到达', N'已完成', N'已取消')),
    CONSTRAINT CK_emergency_from_logical
        CHECK (
            (from_location_type = N'受灾点' AND from_site_id IS NOT NULL AND from_hospital_id IS NULL) OR
            (from_location_type = N'医院'   AND from_site_id IS NULL     AND from_hospital_id IS NOT NULL)
        ),
    CONSTRAINT CK_emergency_to_logical
        CHECK (
            (to_location_type = N'受灾点' AND to_site_id IS NOT NULL AND to_hospital_id IS NULL) OR
            (to_location_type = N'医院'   AND to_site_id IS NULL     AND to_hospital_id IS NOT NULL)
        ),

    CONSTRAINT FK_emergency_from_site
        FOREIGN KEY (from_site_id) REFERENCES disaster_sites(site_id),
    CONSTRAINT FK_emergency_from_hosp
        FOREIGN KEY (from_hospital_id) REFERENCES hospitals(hospital_id),
    CONSTRAINT FK_emergency_to_site
        FOREIGN KEY (to_site_id) REFERENCES disaster_sites(site_id),
    CONSTRAINT FK_emergency_to_hosp
        FOREIGN KEY (to_hospital_id) REFERENCES hospitals(hospital_id)
);
GO

-- 2.13 患者转运记录表（子表，共享主键）
CREATE TABLE patient_transfers (
    operation_id                INT             PRIMARY KEY,
    patient_count               INT             NOT NULL,
    mild_count                  INT             NOT NULL DEFAULT 0,
    severe_count                INT             NOT NULL DEFAULT 0,
    critical_count              INT             NOT NULL DEFAULT 0,
    triage_level                NVARCHAR(10)    NOT NULL,
    accompanying_doctor_count   INT             NOT NULL DEFAULT 0,
    accompanying_nurse_count    INT             NOT NULL DEFAULT 0,
    medical_equipment           NVARCHAR(200)   NULL,
    destination_department      NVARCHAR(50)    NULL,
    special_requirements        NVARCHAR(200)   NULL,

    CONSTRAINT CK_transfer_patient_count CHECK (patient_count > 0),
    CONSTRAINT CK_transfer_sum
        CHECK (mild_count + severe_count + critical_count = patient_count),
    CONSTRAINT CK_transfer_triage
        CHECK (triage_level IN (N'一级', N'二级', N'三级')),

    CONSTRAINT FK_transfer_operation
        FOREIGN KEY (operation_id) REFERENCES emergency_operations(operation_id)
);
GO

-- 2.14 医疗派遣记录表（子表，共享主键）
CREATE TABLE medical_deployments (
    operation_id            INT             PRIMARY KEY,
    team_name               NVARCHAR(100)   NOT NULL,
    specialty               NVARCHAR(20)    NOT NULL,
    doctor_count            INT             NOT NULL DEFAULT 0,
    nurse_count             INT             NOT NULL DEFAULT 0,
    pharmacist_count        INT             NOT NULL DEFAULT 0,
    total_personnel         INT             NOT NULL,
    service_capacity        INT             NOT NULL DEFAULT 0,
    equipment_list          NVARCHAR(500)   NULL,
    supply_list             NVARCHAR(500)   NULL,
    has_mobile_clinic       BIT             NOT NULL DEFAULT 0,
    estimated_duration_days INT             NULL,
    site_setup_status       NVARCHAR(10)    NOT NULL DEFAULT N'未搭建',

    CONSTRAINT CK_deploy_total CHECK (total_personnel > 0),
    CONSTRAINT CK_deploy_personnel
        CHECK (doctor_count + nurse_count + pharmacist_count <= total_personnel),
    CONSTRAINT CK_deploy_specialty
        CHECK (specialty IN (N'外科', N'内科', N'急救', N'妇产', N'儿科', N'防疫', N'心理')),
    CONSTRAINT CK_deploy_setup
        CHECK (site_setup_status IN (N'未搭建', N'搭建中', N'已就绪')),

    CONSTRAINT FK_deploy_operation
        FOREIGN KEY (operation_id) REFERENCES emergency_operations(operation_id)
);
GO


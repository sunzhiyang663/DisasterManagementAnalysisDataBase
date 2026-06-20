-- 青川 6.8 级地震 完整演示数据
-- 6 个受灾点 | 3 个仓库 | 2 家医院
-- 全部点位在 15km 范围内，地图一屏全览

USE DisasterResourceDB;
GO

-- 禁用入库触发器（测试数据手动指定批次详情）
DISABLE TRIGGER trg_AutoSetExpiryDate ON inventory_batches;
GO

-- 一、受灾点（6 个）

INSERT INTO disaster_sites (site_name, disaster_type, severity_level, affected_population, longitude, latitude, rescue_progress, status, contact_person, contact_phone)
VALUES
(N'木鱼镇', N'地震', 5, 3500, 105.0800, 32.4200, N'房屋倒塌率 60%，道路中断，正在打通救援通道', N'救援中', N'张建国', '13880010001'),
(N'沙州镇', N'地震', 4, 2100, 105.1200, 32.3800, N'被困 2000 余人，部分道路可通行',              N'救援中', N'李明辉', '13880010002'),
(N'姚渡镇', N'地震', 4, 1800, 104.9800, 32.3500, N'山体滑坡阻断主路，物资严重短缺',                N'救援中', N'王永强', '13880010003'),
(N'营盘乡', N'地震', 3,  900, 105.0300, 32.4400, N'桥梁断裂，急需药品和医疗队',                    N'救援中', N'赵志刚', '13880010004'),
(N'凉水镇', N'地震', 3, 1200, 105.1600, 32.3600, N'部分道路可通行，通信中断，饮用水短缺',           N'救援中', N'陈志强', '13880010005'),
(N'前进乡', N'地震', 4,  600, 105.0600, 32.4000, N'山体滑坡阻断道路，急需帐篷和急救药品',           N'救援中', N'刘建国', '13880010006');
GO

-- 二、物资分类（树形结构）

SET IDENTITY_INSERT material_categories ON;
GO

INSERT INTO material_categories (category_id, parent_id, category_name, description) VALUES
(1, NULL, N'食品',      N'饮用水、食品等'),
(2, NULL, N'药品',      N'急救药品、抗生素等'),
(3, NULL, N'帐篷被褥',  N'救灾帐篷及被褥'),
(4, NULL, N'器械耗材',  N'救援器械与耗材'),
-- 子类
(5, 1, N'饮用水',       N'瓶装水及净水设备'),
(6, 1, N'方便食品',     N'压缩饼干、方便面等'),
(7, 2, N'止痛消炎',     N'各类止痛消炎药品'),
(8, 2, N'抗生素',       N'广谱抗生素'),
(9, 3, N'救灾帐篷',     N'12㎡ 救灾帐篷');
GO

SET IDENTITY_INSERT material_categories OFF;
GO

-- 三、物资规格（8 种）

SET IDENTITY_INSERT material_specs ON;
GO

INSERT INTO material_specs (spec_id, category_id, material_name, specification, unit, shelf_life_days, description) VALUES
(1, 5, N'矿泉水',          N'550ml×24瓶/箱',   N'箱', 365,  N'瓶装饮用水'),
(2, 6, N'压缩饼干',        N'5kg/箱',           N'箱', 730,  N'高能量压缩饼干'),
(3, 6, N'方便面',          N'24包/箱',          N'箱', 180,  N'桶装方便面'),
(4, 7, N'布洛芬缓释胶囊',  N'0.3g×24粒/盒',     N'盒', 730,  N'消炎止痛'),
(5, 8, N'阿莫西林胶囊',    N'0.5g×24粒/盒',     N'盒', 730,  N'广谱抗生素'),
(6, 9, N'12㎡救灾帐篷',    N'12㎡/顶',          N'顶', NULL, N'含防潮垫'),
(7, 9, N'棉被',            N'2m×2.3m/床',      N'床', NULL, N'加厚棉被'),
(8, 7, N'创可贴',          N'100片/盒',         N'盒', 1095, N'伤口处理');
GO

SET IDENTITY_INSERT material_specs OFF;
GO

-- 四、仓库（3 个）

INSERT INTO warehouses (warehouse_name, warehouse_level, longitude, latitude, address, status, contact_person, contact_phone)
VALUES
(N'青川县物资储备库', N'县级', 105.2300, 32.3900, N'青川县乔庄镇解放路 18 号',  N'正常', N'陈伟',  '13980020001'),
(N'广元市救灾仓库',   N'市级', 105.2500, 32.4200, N'广元市利州区滨江路 56 号',  N'正常', N'刘建明','13980020002'),
(N'木鱼镇临时物资点', N'县级', 105.0850, 32.4180, N'木鱼镇小学操场临时仓库',    N'正常', N'周建华','13980020003');
GO

-- 五、库存批次（25 批次）

-- 5.1 青川县仓库（仓库 ID=1，库存偏少）
INSERT INTO inventory_batches (warehouse_id, spec_id, initial_quantity, current_quantity, production_date, expiry_date)
VALUES
(1, 1, 200,  50, '2025-12-01', '2026-12-01'),
(1, 2, 100,  20, '2025-11-15', '2027-11-15'),
(1, 3, 300, 270, '2026-03-01', '2026-09-01'),  -- 已调拨 30 箱至木鱼镇
(1, 4,  50,   5, '2025-10-01', '2027-10-01'),
(1, 5, 100, 100, '2026-04-01', '2028-04-01'),
(1, 6,  30,  30, '2026-01-15', NULL),
(1, 3, 200, 200, '2026-05-01', '2026-11-01'),
(1, 7,  80,  80, '2025-08-01', NULL),
(1, 8, 200, 120, '2026-01-01', '2028-01-01');  -- 已调拨 30 盒至营盘乡

-- 5.2 广元市仓库（仓库 ID=2，库存充足）
INSERT INTO inventory_batches (warehouse_id, spec_id, initial_quantity, current_quantity, production_date, expiry_date)
VALUES
(2, 1, 500, 420, '2026-04-01', '2027-04-01'),  -- 已调拨 80 箱至沙州镇
(2, 2, 300, 240, '2026-02-01', '2028-02-01'),  -- 已调拨 60 箱至沙州镇
(2, 3, 400, 400, '2026-05-01', '2026-11-01'),
(2, 4, 200, 200, '2026-01-15', '2028-01-15'),
(2, 4, 100, 100, '2026-05-15', '2028-05-15'),
(2, 5, 300, 250, '2026-03-01', '2028-03-01'),  -- 已调拨 50 盒至姚渡镇
(2, 5, 200, 200, '2026-05-01', '2028-05-01'),
(2, 8, 300, 300, '2026-03-01', '2029-03-01'),
(2, 6,  50,  50, '2025-12-01', NULL),
(2, 7, 200, 200, '2026-02-15', NULL);

-- 5.3 木鱼镇临时物资点（仓库 ID=3，靠近灾区前沿）
INSERT INTO inventory_batches (warehouse_id, spec_id, initial_quantity, current_quantity, production_date, expiry_date)
VALUES
(3, 1, 100, 100, '2026-05-01', '2027-05-01'),
(3, 2,  50,  50, '2026-03-15', '2028-03-15'),
(3, 4,  20,  20, '2026-02-01', '2028-02-01'),
(3, 7,  30,  30, '2026-01-01', NULL),
(3, 8, 100, 100, '2026-04-01', '2029-04-01');
GO

-- 六、物资需求（23 条，覆盖四种状态）

-- 6.1 待满足需求（15 条 → ID 1~11, 12~15）
INSERT INTO material_demands (site_id, spec_id, requested_quantity, fulfilled_quantity, urgency_level, status, publisher_name, remark)
VALUES
-- 木鱼镇（site_id=1）
(1, 1, 200, 0, N'特急', N'待满足', N'张建国', N'木鱼镇饮用水极度短缺'),
(1, 4,  50, 0, N'特急', N'待满足', N'张建国', N'重伤员急需止痛药'),
(1, 6,  20, 0, N'紧急', N'待满足', N'张建国', N'需要帐篷安置灾民'),
-- 沙州镇（site_id=2）
(2, 1, 100, 0, N'紧急', N'待满足', N'李明辉', N'饮用水缺口大'),
(2, 2,  50, 0, N'一般', N'待满足', N'李明辉', N'食品短缺'),
(2, 4,  40, 0, N'紧急', N'待满足', N'李明辉', N'沙州镇伤员急需止痛消炎药品'),
-- 姚渡镇（site_id=3）
(3, 1,  80, 0, N'紧急', N'待满足', N'王永强', N'姚渡镇饮用水缺口'),
(3, 7,  50, 0, N'一般', N'待满足', N'王永强', N'姚渡镇夜间气温低，棉被短缺'),
-- 营盘乡（site_id=4）
(4, 4,  30, 0, N'特急', N'待满足', N'赵志刚', N'桥梁断，急需药品空投'),
(4, 7,  20, 0, N'紧急', N'待满足', N'赵志刚', N'营盘乡桥梁断裂，急需棉被保暖'),
-- 木鱼镇追加
(1, 2, 100, 0, N'紧急', N'待满足', N'张建国', N'木鱼镇食品严重短缺'),
-- 凉水镇（site_id=5）
(5, 1,  60, 0, N'紧急', N'待满足', N'陈志强', N'凉水镇饮用水不足'),
(5, 3,  40, 0, N'一般', N'待满足', N'陈志强', N'凉水镇方便食品短缺'),
(5, 5,  30, 0, N'紧急', N'待满足', N'陈志强', N'凉水镇多名伤员需抗生素治疗'),
-- 前进乡（site_id=6）
(6, 6,  15, 0, N'特急', N'待满足', N'刘建国', N'前进乡房屋倒塌严重，急需帐篷'),
(6, 5,  20, 0, N'特急', N'待满足', N'刘建国', N'前进乡多名伤员伤口感染需抗生素'),
(6, 4,  30, 0, N'紧急', N'待满足', N'刘建国', N'前进乡止痛药品短缺'),
(6, 7,  30, 0, N'一般', N'待满足', N'刘建国', N'前进乡棉被短缺');

-- 6.2 部分满足需求（2 条 → ID 19~20）
INSERT INTO material_demands (site_id, spec_id, requested_quantity, fulfilled_quantity, urgency_level, status, publisher_name, remark)
VALUES
(2, 2, 100, 60, N'一般', N'部分满足', N'李明辉', N'沙州镇食品已从广元仓库调拨 60 箱'),
(1, 3,  50, 30, N'一般', N'部分满足', N'张建国', N'木鱼镇方便面已从青川仓库调拨 30 箱');

-- 6.3 已满足/已关闭需求（3 条 → ID 21~23）
INSERT INTO material_demands (site_id, spec_id, requested_quantity, fulfilled_quantity, urgency_level, status, publisher_name, remark, published_at)
VALUES
(3, 8,  50, 50, N'一般', N'已满足', N'王永强', N'姚渡镇创可贴已从广元仓库调拨',   '2026-06-14 10:00:00'),
(4, 8,  30, 30, N'一般', N'已关闭', N'赵志刚', N'营盘乡创可贴已从青川仓库调拨',   '2026-06-14 11:00:00'),
(2, 1,  80, 80, N'紧急', N'已满足', N'李明辉', N'沙州镇饮用水已从广元仓库完成调拨', '2026-06-15 09:00:00');
GO

-- 七、调拨记录 + 库存变动日志

DECLARE @b_gy_bandage INT, @b_qc_bandage INT;

-- 查找创可贴批次
SELECT TOP 1 @b_qc_bandage = batch_id FROM inventory_batches
WHERE warehouse_id = 1 AND spec_id = 8 AND current_quantity >= 30
ORDER BY expiry_date ASC;

SELECT TOP 1 @b_gy_bandage = batch_id FROM inventory_batches
WHERE warehouse_id = 2 AND spec_id = 8 AND current_quantity >= 50
ORDER BY expiry_date ASC;

-- 7.1 插入调拨记录（5 条）

-- 沙州镇食品：已到达
INSERT INTO dispatch_records (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id, status, dispatched_by, dispatched_at, arrived_at)
VALUES (19, 11, 60, 2, 2, N'已到达', N'管理员', '2026-06-15 14:00:00', '2026-06-15 17:30:00');

-- 木鱼镇方便面：运输中
INSERT INTO dispatch_records (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id, status, dispatched_by, dispatched_at)
VALUES (20, 3, 30, 1, 1, N'运输中', N'管理员', '2026-06-16 08:00:00');

-- 姚渡镇创可贴：已签收
IF @b_gy_bandage IS NOT NULL
    INSERT INTO dispatch_records (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id, status, dispatched_by, dispatched_at, arrived_at, signed_at)
    VALUES (21, @b_gy_bandage, 50, 2, 3, N'已签收', N'管理员', '2026-06-14 14:00:00', '2026-06-14 17:00:00', '2026-06-14 18:30:00');

-- 营盘乡创可贴：已签收
IF @b_qc_bandage IS NOT NULL
    INSERT INTO dispatch_records (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id, status, dispatched_by, dispatched_at, arrived_at, signed_at)
    VALUES (22, @b_qc_bandage, 30, 1, 4, N'已签收', N'管理员', '2026-06-14 15:00:00', '2026-06-14 17:30:00', '2026-06-14 19:00:00');

-- 沙州镇饮用水：已签收
INSERT INTO dispatch_records (demand_id, batch_id, dispatch_quantity, from_warehouse_id, to_site_id, status, dispatched_by, dispatched_at, arrived_at, signed_at)
VALUES (23, 10, 80, 2, 2, N'已签收', N'管理员', '2026-06-15 10:00:00', '2026-06-15 13:00:00', '2026-06-15 14:20:00');

-- 7.2 库存变动日志

INSERT INTO inventory_change_logs (batch_id, change_type, change_quantity, quantity_after, related_site_id, related_demand_id, operator_name, remark, changed_at)
SELECT batch_id, N'入库', initial_quantity, current_quantity, NULL, NULL, N'系统', N'初始入库', stored_at
FROM inventory_batches;

INSERT INTO inventory_change_logs (batch_id, change_type, change_quantity, quantity_after, related_site_id, related_demand_id, operator_name, remark, changed_at)
SELECT 11, N'出库', -60, current_quantity, 2, 19, N'管理员', N'沙州镇食品调拨出库',     '2026-06-15 14:00:00' FROM inventory_batches WHERE batch_id = 11
UNION ALL
SELECT 3,  N'出库', -30, current_quantity, 1, 20, N'管理员', N'木鱼镇方便面调拨出库',     '2026-06-16 08:00:00' FROM inventory_batches WHERE batch_id = 3
UNION ALL
SELECT 10, N'出库', -80, current_quantity, 2, 23, N'管理员', N'沙州镇饮用水调拨出库',     '2026-06-15 10:00:00' FROM inventory_batches WHERE batch_id = 10;

IF @b_gy_bandage IS NOT NULL
    INSERT INTO inventory_change_logs (batch_id, change_type, change_quantity, quantity_after, related_site_id, related_demand_id, operator_name, remark, changed_at)
    SELECT @b_gy_bandage, N'出库', -50, current_quantity, 3, 21, N'管理员', N'姚渡镇创可贴调拨出库', '2026-06-14 14:00:00'
    FROM inventory_batches WHERE batch_id = @b_gy_bandage;

IF @b_qc_bandage IS NOT NULL
    INSERT INTO inventory_change_logs (batch_id, change_type, change_quantity, quantity_after, related_site_id, related_demand_id, operator_name, remark, changed_at)
    SELECT @b_qc_bandage, N'出库', -30, current_quantity, 4, 22, N'管理员', N'营盘乡创可贴调拨出库', '2026-06-14 15:00:00'
    FROM inventory_batches WHERE batch_id = @b_qc_bandage;
GO

-- 八、医院（2 家）

INSERT INTO hospitals (hospital_name, hospital_level, total_beds, available_beds, emergency_capacity, longitude, latitude, address, status, contact_person, contact_phone)
VALUES
(N'青川县人民医院', N'二甲', 200, 119, 80, 105.2400, 32.4000, N'青川县乔庄镇平安路 8 号', N'超负荷', N'周院长', '13780030001'),
(N'临时野战医院',   N'社区',  50,  16,  100, 105.1000, 32.4100, N'木鱼镇中学操场',           N'正常',   N'孙队长', '13780030002');
GO

-- 九、床位变动日志（11 条）

INSERT INTO bed_logs (hospital_id, change_type, change_amount, available_beds_after, operator_name, remark, changed_at)
VALUES
(1, N'收治', -15, 185, N'周院长', N'地震后首批伤员',             '2026-06-14 08:30:00'),
(1, N'收治', -20, 165, N'周院长', N'木鱼镇重伤员转运到达',       '2026-06-14 14:00:00'),
(1, N'收治', -18, 147, N'周院长', N'沙州镇伤员到达',             '2026-06-15 10:00:00'),
(1, N'收治', -10, 137, N'周院长', N'姚渡镇伤员到达',             '2026-06-16 09:00:00'),
(1, N'收治',  -8, 129, N'周院长', N'沙州镇伤员转运到达',         '2026-06-15 09:30:00'),
(1, N'出院',   5, 134, N'周院长', N'轻伤员出院',                 '2026-06-15 14:00:00'),
(1, N'收治', -12, 122, N'周院长', N'木鱼镇第二批伤员到达',       '2026-06-16 08:00:00'),
(1, N'转院',  -3, 119, N'周院长', N'3名危重患者转至广元市中心医院', '2026-06-16 11:00:00'),
(2, N'扩容',  20,  20, N'孙队长', N'野战医院搭建完成',           '2026-06-14 12:00:00'),
(2, N'收治',  -8,  12, N'孙队长', N'木鱼镇轻伤员',               '2026-06-14 16:00:00'),
(2, N'收治',  -6,   6, N'孙队长', N'营盘乡伤员转运到达',         '2026-06-15 11:00:00'),
(2, N'收治',  -5,  13, N'孙队长', N'前进乡轻伤员到达',           '2026-06-16 10:00:00'),
(2, N'扩容',  10,  23, N'孙队长', N'临时增加床位应对前进乡伤员',  '2026-06-16 12:00:00'),
(2, N'收治',  -7,  16, N'孙队长', N'姚渡镇伤员转运到达',         '2026-06-16 14:00:00');
GO

-- 十、应急行动（1 转运 + 1 派遣 + 3 追加）

-- 10.1 木鱼镇 → 青川县人民医院（患者转运，已完成）
INSERT INTO emergency_operations
    (operation_type, from_location_type, from_site_id, to_location_type, to_hospital_id,
     vehicle_info, status, created_by, commander, scheduled_at, departed_at, remark)
VALUES
    (N'患者转运', N'受灾点', 1, N'医院', 1,
     N'川A·S1234 负压救护车', N'已完成', N'李明', N'周队长',
     '2026-06-14 13:00:00', '2026-06-14 13:15:00', N'转运木鱼镇重伤员至县医院');

DECLARE @op1 INT = SCOPE_IDENTITY();

INSERT INTO patient_transfers
    (operation_id, patient_count, mild_count, severe_count, critical_count, triage_level,
     accompanying_doctor_count, accompanying_nurse_count, medical_equipment, destination_department, special_requirements)
VALUES
    (@op1, 20, 5, 10, 5, N'二级',
     3, 6, N'便携呼吸机×1, 除颤仪×1, 急救箱×4', N'急诊科', N'危重患者需绿色通道');

-- 10.2 青川县人民医院 → 木鱼镇（医疗派遣，行进中）
INSERT INTO emergency_operations
    (operation_type, from_location_type, from_hospital_id, to_location_type, to_site_id,
     vehicle_info, status, created_by, commander, scheduled_at, departed_at, remark)
VALUES
    (N'医疗派遣', N'医院', 1, N'受灾点', 1,
     N'川A·H5678 救护车 + 物资车×1', N'行进中', N'王芳', N'张队长',
     '2026-06-15 08:00:00', '2026-06-15 08:20:00', N'向木鱼镇派出急救医疗队');

DECLARE @op2 INT = SCOPE_IDENTITY();

INSERT INTO medical_deployments
    (operation_id, team_name, specialty, doctor_count, nurse_count, pharmacist_count,
     total_personnel, service_capacity, equipment_list, supply_list, has_mobile_clinic, estimated_duration_days)
VALUES
    (@op2, N'青川县人民医院救援一队', N'急救',
     5, 12, 2, 19, 80,
     N'急救箱×10, 除颤仪×2, 便携B超×1, 担架×8',
     N'布洛芬×50盒, 阿莫西林×100盒, 创可贴×200盒, 生理盐水×100袋',
     0, 14);

-- 10.3 沙州镇 → 青川县人民医院（患者转运，已完成）
INSERT INTO emergency_operations
    (operation_type, from_location_type, from_site_id, to_location_type, to_hospital_id,
     vehicle_info, status, created_by, commander, scheduled_at, departed_at, arrived_at, completed_at, remark)
VALUES
    (N'患者转运', N'受灾点', 2, N'医院', 1,
     N'川A·S2345 急救车 + 川A·S2346 急救车', N'已完成', N'王芳', N'赵队长',
     '2026-06-15 08:00:00', '2026-06-15 08:30:00', '2026-06-15 09:10:00', '2026-06-15 09:45:00',
     N'转运沙州镇重伤员至县医院');

DECLARE @op3 INT = SCOPE_IDENTITY();

INSERT INTO patient_transfers
    (operation_id, patient_count, mild_count, severe_count, critical_count, triage_level,
     accompanying_doctor_count, accompanying_nurse_count, medical_equipment, destination_department, special_requirements)
VALUES
    (@op3, 15, 6, 7, 2, N'二级',
     2, 4, N'急救箱×6, 担架×4, 氧气瓶×4', N'急诊科', N'2名危重需立即手术');

-- 10.4 青川县人民医院 → 前进乡（医疗派遣，行进中）
INSERT INTO emergency_operations
    (operation_type, from_location_type, from_hospital_id, to_location_type, to_site_id,
     vehicle_info, status, created_by, commander, scheduled_at, departed_at, remark)
VALUES
    (N'医疗派遣', N'医院', 1, N'受灾点', 6,
     N'川A·H6789 救护车 + 物资车×1', N'行进中', N'李明', N'孙队长',
     '2026-06-16 07:00:00', '2026-06-16 07:30:00', N'向新发现的前进乡重灾区派出医疗队');

DECLARE @op4 INT = SCOPE_IDENTITY();

INSERT INTO medical_deployments
    (operation_id, team_name, specialty, doctor_count, nurse_count, pharmacist_count,
     total_personnel, service_capacity, equipment_list, supply_list, has_mobile_clinic, estimated_duration_days)
VALUES
    (@op4, N'青川县人民医院救援二队', N'外科',
     4, 8, 1, 13, 60,
     N'急救箱×8, 除颤仪×1, 外科手术包×5, 担架×6',
     N'阿莫西林×80盒, 布洛芬×40盒, 绷带×100卷, 生理盐水×80袋',
     0, 10);

-- 10.5 姚渡镇 → 临时野战医院（患者转运，行进中）
INSERT INTO emergency_operations
    (operation_type, from_location_type, from_site_id, to_location_type, to_hospital_id,
     vehicle_info, status, created_by, commander, scheduled_at, departed_at, remark)
VALUES
    (N'患者转运', N'受灾点', 3, N'医院', 2,
     N'川A·S3456 急救车', N'行进中', N'王芳', N'刘队长',
     '2026-06-16 09:00:00', '2026-06-16 09:20:00', N'转运姚渡镇伤员至野战医院');

DECLARE @op5 INT = SCOPE_IDENTITY();

INSERT INTO patient_transfers
    (operation_id, patient_count, mild_count, severe_count, critical_count, triage_level,
     accompanying_doctor_count, accompanying_nurse_count, medical_equipment, destination_department, special_requirements)
VALUES
    (@op5, 10, 4, 5, 1, N'三级',
     1, 3, N'急救箱×4, 担架×2, 氧气瓶×2', N'急诊科', N'道路颠簸注意骨折固定');
GO

-- 十一、灾情状态日志（8 条）

INSERT INTO site_status_logs (site_id, changed_field, old_value, new_value, operator_name, remark, changed_at)
VALUES
(1, N'severity_level',      N'4',    N'5',    N'系统', N'余震导致灾情加重',                      '2026-06-14 16:00:00'),
(1, N'affected_population', N'2800', N'3500', N'系统', N'排查后发现更多受灾群众',                 '2026-06-15 08:00:00'),
(1, N'rescue_progress',
    N'房屋倒塌率 60%，道路中断，正在打通救援通道',
    N'主路已抢通，救援车辆可到达，正搜救被困群众',
    N'系统', N'木鱼镇救援通道打通', '2026-06-16 10:00:00'),
(2, N'severity_level',      N'3',    N'4',    N'系统', N'道路桥梁断裂，救援难度升级',              '2026-06-15 14:00:00'),
(3, N'affected_population', N'1500', N'1800', N'系统', N'通信恢复后发现更多被困群众',              '2026-06-16 06:00:00'),
(5, N'severity_level',      N'2',    N'3',    N'系统', N'凉水镇灾情评估上调',                      '2026-06-15 16:00:00'),
(6, N'severity_level',      N'3',    N'4',    N'系统', N'前进乡房屋倒塌率超70%，提高响应等级',     '2026-06-16 08:00:00');
GO

-- 十二、收尾

-- 刷新部分满足需求的时间戳
UPDATE material_demands SET updated_at = GETDATE()
WHERE demand_id IN (19, 20);
GO

-- 重新启用触发器
ENABLE TRIGGER trg_AutoSetExpiryDate ON inventory_batches;
GO

-- 验证

SELECT N'受灾点'     AS 类别, COUNT(*) AS 数量 FROM disaster_sites
UNION ALL SELECT N'仓库',       COUNT(*) FROM warehouses
UNION ALL SELECT N'医院',       COUNT(*) FROM hospitals
UNION ALL SELECT N'物资分类',   COUNT(*) FROM material_categories
UNION ALL SELECT N'物资规格',   COUNT(*) FROM material_specs
UNION ALL SELECT N'物资需求',   COUNT(*) FROM material_demands
UNION ALL SELECT N'库存批次',   COUNT(*) FROM inventory_batches
UNION ALL SELECT N'应急行动',   COUNT(*) FROM emergency_operations
UNION ALL SELECT N'调拨记录',   COUNT(*) FROM dispatch_records
UNION ALL SELECT N'库存日志',   COUNT(*) FROM inventory_change_logs
UNION ALL SELECT N'床位日志',   COUNT(*) FROM bed_logs
UNION ALL SELECT N'灾情日志',   COUNT(*) FROM site_status_logs;
GO

-- 需求状态分布
SELECT status AS 需求状态, COUNT(*) AS 数量
FROM material_demands GROUP BY status ORDER BY status;
GO

-- 调拨状态分布
SELECT status AS 调拨状态, COUNT(*) AS 数量
FROM dispatch_records GROUP BY status ORDER BY status;
GO

PRINT N'========================================';
PRINT N'青川地震完整演示数据导入完成！';
PRINT N'6 个受灾点 | 3 个仓库 | 2 家医院';
PRINT N'25 库存批次 | 23 物资需求 | 5 调拨记录';
PRINT N'5 应急行动 | 14 床位日志 | 7 灾情日志';
PRINT N'========================================';
GO

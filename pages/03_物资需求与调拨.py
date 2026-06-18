import streamlit as st
from sidebar import render
render()

from db import execute_query, execute_query_nocache, execute_proc, execute_proc_non_query

st.set_page_config(page_title="需求与调拨", page_icon="📦", layout="wide")

sites_df = execute_query("SELECT site_id, site_name FROM disaster_sites")
specs_df = execute_query("SELECT spec_id, material_name, unit FROM material_specs")

t1,t2,t3,t4 = st.tabs(["📋 需求列表","🚚 智能调拨","📮 调拨追踪","🏭 库存总览"])

with t1:
    # 无缓存：需求列表需要实时数据
    dm = execute_query_nocache("SELECT * FROM material_demands ORDER BY published_at DESC")
    if not dm.empty:
        c1,c2,c3 = st.columns(3)
        sf = c1.multiselect("受灾点", sites_df["site_id"].tolist(),
            format_func=lambda x: sites_df[sites_df["site_id"]==x]["site_name"].iloc[0], key="f1")
        uf = c2.multiselect("紧急程度", ["特急","紧急","一般"], key="f2")
        stf = c3.multiselect("状态", ["待满足","部分满足","已满足","已关闭"], default=["待满足","部分满足"], key="f3")
        d = dm.copy()
        if sf: d = d[d["site_id"].isin(sf)]
        if uf: d = d[d["urgency_level"].isin(uf)]
        if stf: d = d[d["status"].isin(stf)]
        sm = sites_df.set_index("site_id")["site_name"].to_dict()
        pm = specs_df.set_index("spec_id")["material_name"].to_dict()
        d["受灾点"] = d["site_id"].map(sm); d["物资"] = d["spec_id"].map(pm)
        st.dataframe(d[["demand_id","受灾点","物资","requested_quantity","fulfilled_quantity","urgency_level","status","published_at"]],
                     use_container_width=True, hide_index=True)

with t2:
    # 无缓存：实时查询待满足的需求
    ad = execute_query_nocache("SELECT * FROM material_demands WHERE status IN ('待满足','部分满足') ORDER BY urgency_level DESC")
    if ad.empty:
        st.success("所有需求已满足")
    else:
        sid = st.selectbox("选择需求", ad["demand_id"].tolist(),
            format_func=lambda x: f"#{x} | {sites_df[sites_df['site_id']==ad[ad['demand_id']==x]['site_id'].iloc[0]]['site_name'].iloc[0]} | 需{ad[ad['demand_id']==x]['requested_quantity'].iloc[0]}", key="plan")
        row = ad[ad["demand_id"]==sid].iloc[0]
        need = int(row["requested_quantity"]) - int(row["fulfilled_quantity"])
        qty = st.number_input("数量", 1, max(need,1), min(need,100), 10)
        if st.button("🔍 生成推荐方案", type="primary"):
            try:
                plan = execute_proc("sp_GetDispatchPlan", {"p_site_id":int(row["site_id"]),"p_spec_id":int(row["spec_id"]),"p_quantity":qty})
                if plan.empty: st.warning("无可用库存")
                else: st.success(f"{len(plan)} 个批次"); st.session_state.plan = plan; st.session_state.pid = sid
            except Exception as e: st.error(str(e))
        if "plan" in st.session_state and st.session_state.plan is not None:
            plan = st.session_state.plan
            st.dataframe(plan, use_container_width=True)
            bts = st.multiselect("选择批次", plan["batch_id"].tolist(),
                format_func=lambda x: f"#{x} | {plan[plan['batch_id']==x]['warehouse_name'].iloc[0]} | {plan[plan['batch_id']==x]['allocatable_quantity'].iloc[0]}")
            if bts:
                c1,c2 = st.columns(2)
                if c1.button("🔒 预留", type="primary"):
                    ok=True
                    for b in bts:
                        q=int(plan[plan["batch_id"]==b]["allocatable_quantity"].iloc[0])
                        if not execute_proc_non_query("sp_ReserveBatch",{"p_batch_id":b,"p_demand_id":st.session_state.pid,"p_quantity":q,"p_operator_name":"管理员"}): ok=False
                    if ok: st.success("预留成功"); st.session_state.rv=bts; st.cache_data.clear(); st.rerun()
                if "rv" in st.session_state and st.session_state.rv and c2.button("📤 确认出库", type="primary"):
                    ok=True
                    for b in st.session_state.rv:
                        q=int(plan[plan["batch_id"]==b]["allocatable_quantity"].iloc[0])
                        if not execute_proc_non_query("sp_ConfirmDispatch",{"p_demand_id":st.session_state.pid,"p_batch_id":b,"p_quantity":q,"p_operator_name":"管理员"}): ok=False
                    if ok: st.success("出库成功"); st.session_state.pop("plan",None); st.session_state.pop("rv",None); st.cache_data.clear(); st.rerun()

with t3:
    # 无缓存：调拨追踪需要实时数据
    dp = execute_query_nocache("""
        SELECT dr.*, ds.site_name, w.warehouse_name, ms.material_name
        FROM dispatch_records dr JOIN disaster_sites ds ON dr.to_site_id=ds.site_id
        JOIN warehouses w ON dr.from_warehouse_id=w.warehouse_id
        JOIN inventory_batches ib ON dr.batch_id=ib.batch_id JOIN material_specs ms ON ib.spec_id=ms.spec_id
        ORDER BY dr.dispatched_at DESC
    """)
    if not dp.empty:
        sf2 = st.multiselect("状态", ["运输中","已到达","已签收"], default=["运输中","已到达"], key="ds")
        fd = dp[dp["status"].isin(sf2)] if sf2 else dp
        st.dataframe(fd[["dispatch_id","site_name","warehouse_name","material_name","dispatch_quantity","status","dispatched_at"]],
                     use_container_width=True, hide_index=True)

with t4:
    stk = execute_query("SELECT * FROM vw_WarehouseStock WHERE available_stock > 0 ORDER BY warehouse_name")
    if not stk.empty:
        wh = st.multiselect("仓库", sorted(stk["warehouse_name"].unique()), key="swh")
        st.dataframe(stk[stk["warehouse_name"].isin(wh)] if wh else stk, use_container_width=True, hide_index=True)

import streamlit as st
from sidebar import render
render()

from db import execute_query, execute_query_nocache, execute_non_query
from components.charts import plot_bed_occupancy

st.set_page_config(page_title="医院与应急", page_icon="🏥", layout="wide")

hcap = execute_query("SELECT * FROM vw_HospitalCapacity ORDER BY hospital_level, hospital_name")
hospitals = execute_query("SELECT * FROM hospitals ORDER BY hospital_name")
bl = execute_query("SELECT bl.*, h.hospital_name FROM bed_logs bl JOIN hospitals h ON bl.hospital_id=h.hospital_id ORDER BY bl.changed_at DESC")
ops = execute_query("""
    SELECT eo.*, ds.site_name, h.hospital_name FROM emergency_operations eo
    LEFT JOIN disaster_sites ds ON eo.from_site_id=ds.site_id OR eo.to_site_id=ds.site_id
    LEFT JOIN hospitals h ON eo.from_hospital_id=h.hospital_id OR eo.to_hospital_id=h.hospital_id
    ORDER BY eo.scheduled_at DESC
""")
sites_df = execute_query("SELECT site_id, site_name FROM disaster_sites")

t1,t2,t3,t4 = st.tabs(["🏥 医院容量","🛏 床位日志","🚑 应急行动","📝 创建行动"])

with t1:
    if not hcap.empty:
        st.plotly_chart(plot_bed_occupancy(hcap), use_container_width=True)
        d = hcap.copy()
        d.columns = ["ID","医院","等级","总床位","空余","占用","空置率%","急救能力","状态"]
        st.dataframe(d, use_container_width=True, hide_index=True)

with t2:
    if not bl.empty:
        hid = st.multiselect("医院", hospitals["hospital_id"].tolist(),
            format_func=lambda x: hospitals[hospitals["hospital_id"]==x]["hospital_name"].iloc[0], key="bh")
        fl = bl[bl["hospital_id"].isin(hid)] if hid else bl
        st.dataframe(fl[["log_id","hospital_name","change_type","change_amount","available_beds_after","changed_at"]],
                     use_container_width=True, hide_index=True)

with t3:
    if not ops.empty:
        tf = st.multiselect("类型", ["患者转运","医疗派遣"], default=["患者转运","医疗派遣"], key="ot")
        fo = ops[ops["operation_type"].isin(tf)] if tf else ops
        for _, r in fo.iterrows():
            nm = r.get('site_name', r.get('hospital_name', '-'))
            with st.expander(f"#{r['operation_id']} {r['operation_type']} | {nm} | {r['status']} | {r['scheduled_at']}"):
                c1,c2 = st.columns(2)
                c1.write(f"出发: {r['from_location_type']}  目的: {r['to_location_type']}")
                c1.write(f"车辆: {r.get('vehicle_info','-')}  负责人: {r.get('commander','-')}")
                c2.write(f"计划: {r['scheduled_at']}  实际出发: {r.get('departed_at','-')}")
                c2.write(f"到达: {r.get('arrived_at','-')}  完成: {r.get('completed_at','-')}")
                try:
                    sub = execute_query_nocache(f"SELECT * FROM {'patient_transfers' if r['operation_type']=='患者转运' else 'medical_deployments'} WHERE operation_id={r['operation_id']}")
                    if not sub.empty: st.dataframe(sub, use_container_width=True, hide_index=True)
                except: pass

with t4:
    ot = st.radio("类型", ["患者转运","医疗派遣"], horizontal=True)
    with st.form("of", clear_on_submit=True):
        c1,c2,c3 = st.columns(3)
        sd=c1.date_input("日期"); stm=c2.time_input("时间"); veh=c3.text_input("车辆")
        cmdr=c1.text_input("负责人"); cb=c2.text_input("创建人","管理员"); rmk=c3.text_input("备注")
        st.divider()
        if ot == "患者转运":
            c1,c2=st.columns(2)
            fs=c1.selectbox("出发受灾点", sites_df["site_id"].tolist(), format_func=lambda x: sites_df[sites_df["site_id"]==x]["site_name"].iloc[0])
            th=c2.selectbox("目的医院", hospitals["hospital_id"].tolist(), format_func=lambda x: hospitals[hospitals["hospital_id"]==x]["hospital_name"].iloc[0])
            pc=st.number_input("患者总数",1,100,1)
            m,s,c=st.columns(3); m.number_input("轻伤",0,100,0); s.number_input("重伤",0,100,0); c.number_input("危重",0,100,0)
            st.selectbox("检伤分级",["一级","二级","三级"])
            a,b=st.columns(2); a.number_input("随行医生",0,20,0); b.number_input("随行护士",0,20,0)
        else:
            c1,c2=st.columns(2)
            fh=c1.selectbox("出发医院", hospitals["hospital_id"].tolist(), format_func=lambda x: hospitals[hospitals["hospital_id"]==x]["hospital_name"].iloc[0])
            ts=c2.selectbox("目的受灾点", sites_df["site_id"].tolist(), format_func=lambda x: sites_df[sites_df["site_id"]==x]["site_name"].iloc[0])
            tn=st.text_input("医疗队名称")
            sp=st.selectbox("专科",["外科","内科","急救","妇产","儿科","防疫","心理"])
            dc=st.number_input("医生数",0,50,1); nc=st.number_input("护士数",0,50,0); tp=st.number_input("总人数",1,100,1)
        if st.form_submit_button("✅ 创建", type="primary", use_container_width=True):
            import datetime
            sat = datetime.datetime.combine(sd,stm).isoformat()
            if ot == "患者转运":
                execute_non_query("INSERT INTO emergency_operations(operation_type,from_location_type,from_site_id,to_location_type,to_hospital_id,vehicle_info,status,created_by,commander,scheduled_at,remark) VALUES(?,?,?,?,?,?,'待出发',?,?,?,?)",
                    ("患者转运","受灾点",fs,"医院",th,veh,cb,cmdr,sat,rmk))
            else:
                execute_non_query("INSERT INTO emergency_operations(operation_type,from_location_type,from_hospital_id,to_location_type,to_site_id,vehicle_info,status,created_by,commander,scheduled_at,remark) VALUES(?,?,?,?,?,?,'待出发',?,?,?,?)",
                    ("医疗派遣","医院",fh,"受灾点",ts,veh,cb,cmdr,sat,rmk))
            st.success("创建成功"); st.cache_data.clear(); st.rerun()

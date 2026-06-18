import streamlit as st
from sidebar import render
render()

from db import execute_query_nocache

st.set_page_config(page_title="视图查询", page_icon="📋", layout="wide")

views = {"vw_DisasterOverview":"灾情总览","vw_WarehouseStock":"仓库库存","vw_HospitalCapacity":"医院接诊"}

cols = st.columns(len(views))
for i,(v,label) in enumerate(views.items()):
    if cols[i].button(f"📊 {label}", use_container_width=True, key=f"v_{v}"): st.session_state.av = v

if av := st.session_state.get("av"):
    st.divider()
    st.subheader(f"📊 {av}")
    try:
        df = execute_query_nocache(f"SELECT * FROM {av}")
        if df.empty: st.info("无数据")
        else:
            st.success(f"{len(df)} 条记录")
            st.dataframe(df, use_container_width=True, height=500)
            st.download_button("📥 导出 CSV", df.to_csv(index=False).encode("utf-8-sig"), f"{av}.csv", "text/csv")
    except Exception as e:
        st.error(str(e))
else:
    st.info("点击上方按钮选择视图")

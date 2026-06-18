import streamlit as st
from sidebar import render
render()

from db import get_tables, get_table_schema, execute_query_nocache

st.set_page_config(page_title="数据管理", page_icon="📊", layout="wide")

tables = get_tables()
if not tables: st.warning("无表数据"); st.stop()

with st.sidebar:
    st.divider()
    st.subheader("📊 数据表")
    q = st.text_input("搜索", placeholder="筛选表名...")
    ft = [t for t in tables if q.lower() in t.lower()] if q else tables
    for t in ft:
        if st.button(t, use_container_width=True, key=f"t_{t}"): st.session_state.sel = t

sel = st.session_state.get("sel")
if sel:
    tab1,tab2 = st.tabs(["📋 数据浏览","🔍 表结构"])
    with tab1:
        df = execute_query_nocache(f"SELECT * FROM {sel}")
        if df.empty: st.info("无数据")
        else: st.dataframe(df, use_container_width=True, height=520)
    with tab2:
        sd = get_table_schema(sel)
        st.dataframe(sd, use_container_width=True, hide_index=True)
        n_null = len(sd[sd["允许NULL"]=="NULL"])
        pk = sd[sd["主键"]=="PK"]["列名"].tolist()
        st.caption(f"{len(sd)} 列 | 可空: {n_null} | 主键: {', '.join(pk) if pk else '无'}")
else:
    st.info("← 选择数据表")

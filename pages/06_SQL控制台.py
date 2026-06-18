import streamlit as st
from sidebar import render
render()

from db import execute_query_nocache, is_safe_sql, get_sample_sql, get_procedures

st.set_page_config(page_title="SQL控制台", page_icon="💻", layout="wide")

samples = get_sample_sql()
cols = st.columns(4)
for i,(label,sql) in enumerate(samples):
    if cols[i%4].button(label, key=f"p_{i}", use_container_width=True): st.session_state.sql = sql

with st.sidebar:
    st.divider()
    st.subheader("存储过程")
    try:
        for p in get_procedures(): st.code(p, language=None)
    except: pass
    st.divider()
    st.caption("禁止: INSERT UPDATE DELETE DROP ALTER CREATE TRUNCATE")

st.divider()
sql = st.text_area("SQL 语句", value=st.session_state.get("sql","-- SELECT 或 EXEC\n"), height=150, key="sa")

c1,c2,_ = st.columns([1,1,3])
if c1.button("▶ 执行", type="primary", use_container_width=True):
    for i,s in enumerate([x.strip() for x in sql.split(";") if x.strip()]):
        if not is_safe_sql(s): st.error(f"拦截: `{s[:80]}...`"); continue
        try:
            df = execute_query_nocache(s)
            if df.empty: st.info("无返回数据")
            else: st.success(f"{len(df)} 行 × {len(df.columns)} 列"); st.dataframe(df, use_container_width=True, height=400)
        except Exception as e: st.error(str(e))
if c2.button("🗑 清空", use_container_width=True): st.session_state.sql = ""; st.rerun()

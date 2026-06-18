import streamlit as st
from sidebar import render
render()

from db import execute_query
from components.charts import plot_severity_pie, plot_disaster_type_bar, plot_demand_bar

st.set_page_config(page_title="灾情总览", page_icon="📈", layout="wide")

try:
    ov = execute_query("SELECT * FROM vw_DisasterOverview ORDER BY severity_level DESC")
    sites = execute_query("SELECT * FROM disaster_sites")
    demands = execute_query("SELECT * FROM material_demands")
    hos = execute_query("SELECT * FROM hospitals")
except Exception as e:
    st.error(str(e)); st.stop()

n_sites = len(sites)
active = len(sites[sites["status"]=="救援中"]) if not sites.empty else 0
sat = ov["satisfaction_rate"].astype(float).mean() if not ov.empty else 0
urgent = len(demands[demands["status"].isin(["待满足","部分满足"])]) if not demands.empty else 0
beds = int(hos["available_beds"].sum()) if not hos.empty else 0

c1,c2,c3,c4 = st.columns(4)
with c1: st.markdown(f"<div style='background:#fff;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04);'><span style='color:#888;font-size:13px;'>受灾点总数</span><br><span style='font-size:32px;font-weight:700;'>{n_sites}</span><br><span style='color:#ef4444;font-size:12px;'>{active} 个救援中</span></div>", unsafe_allow_html=True)
with c2: st.markdown(f"<div style='background:#fff;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04);'><span style='color:#888;font-size:13px;'>平均需求满足率</span><br><span style='font-size:32px;font-weight:700;'>{sat:.1f}%</span></div>", unsafe_allow_html=True)
with c3: st.markdown(f"<div style='background:#fff;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04);'><span style='color:#888;font-size:13px;'>待满足需求</span><br><span style='font-size:32px;font-weight:700;color:#ef4444;'>{urgent}</span></div>", unsafe_allow_html=True)
with c4: st.markdown(f"<div style='background:#fff;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.04);'><span style='color:#888;font-size:13px;'>可用床位</span><br><span style='font-size:32px;font-weight:700;'>{beds}</span></div>", unsafe_allow_html=True)

st.markdown("<br>", unsafe_allow_html=True)

c1,c2 = st.columns(2)
with c1:
    if not sites.empty: st.plotly_chart(plot_severity_pie(sites), use_container_width=True)
with c2:
    if not sites.empty: st.plotly_chart(plot_disaster_type_bar(sites), use_container_width=True)

if not ov.empty:
    st.plotly_chart(plot_demand_bar(ov), use_container_width=True)
    d = ov[["site_name","disaster_type","severity_level","total_demands","satisfied_demands","satisfaction_rate","status"]].copy()
    d.columns = ["受灾点","灾害","严重","需求数","已满足","满足率%","状态"]
    st.dataframe(d, use_container_width=True, hide_index=True)

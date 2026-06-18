import streamlit as st
from sidebar import render
render()

from db import execute_query, execute_proc
from components.maps import create_disaster_map, render_map

st.set_page_config(page_title="物资地图", page_icon="🗺", layout="wide")

@st.cache_data(ttl=60, show_spinner=False)
def load():
    return {
        "sites": execute_query("SELECT * FROM disaster_sites"),
        "wh": execute_query("SELECT * FROM warehouses WHERE status != '维护中'"),
        "hos": execute_query("SELECT * FROM hospitals"),
    }

data = load()
s, w, h = data["sites"], data["wh"], data["hos"]

with st.sidebar:
    st.divider()
    st.subheader("🗺 图层")
    ss = st.checkbox("受灾点", True)
    sw = st.checkbox("仓库", True)
    sh_ = st.checkbox("医院", True)
    st.divider()
    st.subheader("📍 周边资源")
    if not s.empty:
        sid = st.selectbox("受灾点", s["site_id"].tolist(),
            format_func=lambda x: s[s["site_id"]==x]["site_name"].iloc[0])
        r = st.slider("半径(km)", 10, 500, 50, 10)
        if st.button("查询", use_container_width=True):
            try:
                x = execute_proc("sp_GetNearbyResources", {"p_site_id": sid, "p_radius_km": r})
                st.success(f"{len(x)} 个") if not x.empty else st.info("无")
                if not x.empty: st.dataframe(x, use_container_width=True, hide_index=True)
            except Exception as e: st.warning(str(e))
    st.divider()
    zoom = st.slider("缩放", 3, 18, 5)
    clat = float(s["latitude"].mean()) if not s.empty else 31.0
    clon = float(s["longitude"].mean()) if not s.empty else 104.0

m = create_disaster_map(
    sites_df=s if ss else None, warehouses_df=w if sw else None, hospitals_df=h if sh_ else None,
    center_lat=clat, center_lon=clon, zoom=zoom,
)
ck = render_map(m, height=600)

if ck and isinstance(ck, dict) and ck.get("last_object_clicked"):
    obj = ck["last_object_clicked"]
    if obj and obj.get("lat") and not s.empty:
        lat, lon = obj["lat"], obj["lng"]
        s["_d"] = (s["latitude"].astype(float)-lat)**2 + (s["longitude"].astype(float)-lon)**2
        n = s.loc[s["_d"].idxmin()]
        st.divider()
        st.markdown(f"📍 **{n['site_name']}**  {n['disaster_type']}  {n['severity_level']}级  受灾{int(n['affected_population'])}人  {n['status']}")

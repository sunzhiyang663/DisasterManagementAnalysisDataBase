import streamlit as st

st.set_page_config(page_title="灾害资源调度", page_icon="🌍", layout="wide", initial_sidebar_state="expanded")

# ---- 全局样式 ----
st.markdown("""
<style>
[data-testid='stSidebar'] {min-width:210px!important;max-width:260px!important}
[data-testid='stSidebarNav'] {display:none}
.stApp {background:#f5f7fa}
</style>
""", unsafe_allow_html=True)

# ---- 登录 ----
if "role" not in st.session_state:
    st.markdown("<style>[data-testid='stSidebar']{display:none!important}</style>", unsafe_allow_html=True)
    for _ in range(3):
        st.markdown("")
    _, c, _ = st.columns([1.2, 1, 1.2])
    with c:
        st.markdown("""
        <div style="background:#fff;border-radius:20px;padding:48px 40px 40px;text-align:center;box-shadow:0 4px 24px rgba(0,0,0,0.06);">
            <div style="font-size:52px;margin-bottom:12px;">🌍</div>
            <h2 style="margin:0 0 4px;color:#1a1a2e;">自然灾害资源调度</h2>
            <p style="color:#888;margin:0 0 28px;font-size:14px;">协同管理平台</p>
        """, unsafe_allow_html=True)
        a, b = st.columns(2)
        if a.button("📊 普通用户", type="primary", use_container_width=True):
            st.session_state.role = "普通用户"
            st.switch_page("pages/01_灾情总览.py")
        if b.button("⚙️ 管理员", type="primary", use_container_width=True):
            st.session_state.role = "管理员"
            st.switch_page("pages/05_数据管理.py")
        st.markdown("</div>", unsafe_allow_html=True)
    st.stop()

# ---- 已登录但仍在 app.py，重定向到首页 ----
if st.session_state.role == "管理员":
    st.switch_page("pages/05_数据管理.py")
else:
    st.switch_page("pages/01_灾情总览.py")

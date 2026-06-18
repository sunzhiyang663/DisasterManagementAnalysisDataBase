"""共享侧边栏 — 每个页面调用 render()"""

import streamlit as st


def render():
    if "role" not in st.session_state:
        st.switch_page("app.py")
        st.stop()

    is_admin = st.session_state.role == "管理员"

    st.markdown("""
    <style>
    [data-testid='stSidebar'] {min-width:210px!important;max-width:260px!important}
    [data-testid='stSidebarNav'] {display:none}
    </style>
    """, unsafe_allow_html=True)

    with st.sidebar:
        st.markdown("### 🌍 灾害资源调度")
        st.caption(f"当前：**{st.session_state.role}**")

        if is_admin and st.button("📊 切换普通用户", use_container_width=True):
            st.session_state.role = "普通用户"
            st.switch_page("pages/01_灾情总览.py")
        if not is_admin and st.button("⚙️ 切换管理员", use_container_width=True):
            st.session_state.role = "管理员"
            st.switch_page("pages/05_数据管理.py")

        st.divider()

        if is_admin:
            st.page_link("pages/05_数据管理.py", label="📊 数据管理", icon="📊")
            st.page_link("pages/06_SQL控制台.py", label="💻 SQL 控制台", icon="💻")
            st.page_link("pages/07_视图查询.py", label="📋 视图查询", icon="📋")
        else:
            st.page_link("pages/01_灾情总览.py", label="📈 灾情总览", icon="📈")
            st.page_link("pages/02_物资地图.py", label="🗺 物资地图", icon="🗺")
            st.page_link("pages/03_物资需求与调拨.py", label="📦 需求与调拨", icon="📦")
            st.page_link("pages/04_医院与应急行动.py", label="🏥 医院与应急", icon="🏥")

        st.divider()

        from db import get_connection_with_error

        conn, err = get_connection_with_error()
        if conn is None:
            st.error(f"⚠ 未连接")
            if err:
                with st.expander("查看详情"):
                    st.code(err)
        else:
            st.success("✅ 数据库已连接")

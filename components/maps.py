"""Folium + OpenStreetMap 地图组件"""

import folium
from streamlit_folium import st_folium
import pandas as pd
import streamlit as st


def create_disaster_map(
    sites_df: pd.DataFrame | None = None,
    warehouses_df: pd.DataFrame | None = None,
    hospitals_df: pd.DataFrame | None = None,
    center_lat: float = 31.0,
    center_lon: float = 104.0,
    zoom: int = 5,
) -> folium.Map:
    """创建物资地图，标注受灾点(红)、仓库(蓝)、医院(绿)"""

    m = folium.Map(
        location=[center_lat, center_lon],
        zoom_start=zoom,
        tiles="https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}",
        attr="高德地图",
        control_scale=True,
    )

    site_fg = folium.FeatureGroup(name="受灾点", show=True)
    warehouse_fg = folium.FeatureGroup(name="仓库", show=True)
    hospital_fg = folium.FeatureGroup(name="医院", show=True)

    if sites_df is not None and not sites_df.empty:
        for _, r in sites_df.iterrows():
            html = (
                f"<b>{r['site_name']}</b><br>"
                f"类型:{r['disaster_type']} | 严重:{r['severity_level']}级<br>"
                f"受灾人数:{r['affected_population']} | 状态:{r['status']}"
            )
            folium.Marker(
                location=[r["latitude"], r["longitude"]],
                popup=folium.Popup(html, max_width=280),
                icon=folium.Icon(color="red", icon="info-sign"),
            ).add_to(site_fg)

    if warehouses_df is not None and not warehouses_df.empty:
        for _, r in warehouses_df.iterrows():
            html = (
                f"<b>{r['warehouse_name']}</b><br>"
                f"级别:{r['warehouse_level']} | 状态:{r['status']}<br>"
                f"{r['address']}"
            )
            folium.Marker(
                location=[r["latitude"], r["longitude"]],
                popup=folium.Popup(html, max_width=280),
                icon=folium.Icon(color="blue", icon="warehouse"),
            ).add_to(warehouse_fg)

    if hospitals_df is not None and not hospitals_df.empty:
        for _, r in hospitals_df.iterrows():
            html = (
                f"<b>{r['hospital_name']}</b><br>"
                f"级别:{r['hospital_level']} | 总床位:{r['total_beds']} | 空余:{r['available_beds']}<br>"
                f"急救能力:{r['emergency_capacity']}人/日 | 状态:{r['status']}"
            )
            folium.Marker(
                location=[r["latitude"], r["longitude"]],
                popup=folium.Popup(html, max_width=280),
                icon=folium.Icon(color="green", icon="plus"),
            ).add_to(hospital_fg)

    site_fg.add_to(m)
    warehouse_fg.add_to(m)
    hospital_fg.add_to(m)
    folium.LayerControl().add_to(m)

    return m


def render_map(m: folium.Map, height: int = 550, key: str = "main_map") -> dict | None:
    """渲染 Folium 地图"""
    return st_folium(m, height=height, width="100%", key=key, returned_objects=["last_object_clicked"])

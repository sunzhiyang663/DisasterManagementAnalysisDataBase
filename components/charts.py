"""Plotly 图表组件"""

import plotly.express as px
import plotly.graph_objects as go
import pandas as pd
import streamlit as st


def render_kpi_metric(value, label, delta=None, delta_color="normal"):
    """渲染 KPI 指标卡（使用 st.metric）"""
    st.metric(label=label, value=value, delta=delta, delta_color=delta_color)


def plot_severity_pie(df: pd.DataFrame) -> go.Figure:
    """灾害严重程度饼图"""
    if df.empty:
        return go.Figure()
    severity_counts = df["severity_level"].value_counts().reset_index()
    severity_counts.columns = ["严重程度", "数量"]
    severity_counts["严重程度"] = severity_counts["严重程度"].apply(lambda x: f"{x}级")

    fig = px.pie(
        severity_counts,
        values="数量",
        names="严重程度",
        title="灾害严重程度分布",
        color_discrete_sequence=px.colors.sequential.Reds_r,
    )
    fig.update_traces(textposition="inside", textinfo="percent+label")
    fig.update_layout(height=350)
    return fig


def plot_disaster_type_bar(df: pd.DataFrame) -> go.Figure:
    """灾害类型柱状图"""
    if df.empty:
        return go.Figure()
    type_counts = df["disaster_type"].value_counts().reset_index()
    type_counts.columns = ["灾害类型", "数量"]

    fig = px.bar(
        type_counts,
        x="灾害类型",
        y="数量",
        title="灾害类型分布",
        color="数量",
        color_continuous_scale="Reds",
    )
    fig.update_layout(height=350)
    return fig


def plot_demand_bar(df: pd.DataFrame) -> go.Figure:
    """各受灾点需求满足率柱状图"""
    if df.empty:
        return go.Figure()
    data = df.copy()
    data["满足率"] = data["satisfaction_rate"].astype(float)

    fig = px.bar(
        data.sort_values("满足率", ascending=True),
        x="满足率",
        y="site_name",
        title="各受灾点需求满足率",
        orientation="h",
        color="满足率",
        color_continuous_scale="RdYlGn",
        range_color=[0, 100],
        text=data["满足率"].apply(lambda x: f"{x:.1f}%"),
    )
    fig.update_traces(textposition="outside")
    fig.update_layout(height=400)
    return fig


def plot_bed_occupancy(df: pd.DataFrame) -> go.Figure:
    """医院床位占用率图"""
    if df.empty:
        return go.Figure()
    data = df.copy()
    data["vacancy_rate"] = data["vacancy_rate"].astype(float)
    data["占用率"] = 100 - data["vacancy_rate"]

    fig = px.bar(
        data.sort_values("占用率", ascending=False),
        x="hospital_name",
        y=["占用率", "vacancy_rate"],
        title="医院床位占用与空闲比例",
        barmode="stack",
        color_discrete_map={"占用率": "#EF5350", "vacancy_rate": "#66BB6A"},
        labels={"value": "百分比", "variable": "类型", "hospital_name": "医院"},
    )
    fig.update_layout(height=400)
    return fig


def plot_urgency_gauge(urgent_count: int, total_count: int) -> go.Figure:
    """紧急需求指标仪表盘"""
    fig = go.Figure(
        go.Indicator(
            mode="gauge+number",
            value=urgent_count,
            title={"text": "待满足紧急需求"},
            gauge={
                "axis": {"range": [0, max(total_count, 1)]},
                "bar": {"color": "#EF5350"},
                "steps": [
                    {"range": [0, total_count * 0.3], "color": "#C8E6C9"},
                    {"range": [total_count * 0.3, total_count * 0.7], "color": "#FFF9C4"},
                    {"range": [total_count * 0.7, total_count], "color": "#FFCDD2"},
                ],
            },
        )
    )
    fig.update_layout(height=250)
    return fig

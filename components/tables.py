"""通用表格展示组件"""

import streamlit as st
import pandas as pd


def render_data_table(df: pd.DataFrame, key: str = "table", height: int = 400) -> None:
    """通用分页表格渲染"""
    if df.empty:
        st.info("无数据")
        return

    page_size = st.selectbox(
        "每页显示",
        options=[20, 50, 100],
        index=0,
        key=f"{key}_page_size",
    )

    total_pages = max(1, (len(df) - 1) // page_size + 1)
    page = st.number_input(
        "页码",
        min_value=1,
        max_value=total_pages,
        value=1,
        key=f"{key}_page_num",
    )

    start = (page - 1) * page_size
    end = start + page_size

    st.caption(f"共 {len(df)} 条记录 | 第 {page}/{total_pages} 页")
    st.dataframe(df.iloc[start:end], use_container_width=True, height=height)


def render_filterable_table(
    df: pd.DataFrame,
    filter_cols: list[str] | None = None,
    key: str = "filter_table",
) -> pd.DataFrame:
    """可筛选表格 — 对指定列提供下拉筛选器，返回筛选后的 DataFrame"""
    if df.empty:
        st.info("无数据")
        return df

    result = df.copy()

    if filter_cols:
        cols = st.columns(min(len(filter_cols), 4))
        for i, col_name in enumerate(filter_cols):
            if col_name in result.columns:
                with cols[i % 4]:
                    values = sorted(result[col_name].dropna().unique())
                    selected = st.multiselect(
                        f"筛选 {col_name}",
                        options=values,
                        default=[],
                        key=f"{key}_filter_{col_name}",
                    )
                    if selected:
                        result = result[result[col_name].isin(selected)]

    st.dataframe(result, use_container_width=True, height=400)
    return result

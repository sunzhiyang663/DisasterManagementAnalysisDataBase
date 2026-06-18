# 组件模块 — 懒加载避免依赖缺失时阻塞
try:
    from .charts import plot_severity_pie, plot_demand_bar, plot_bed_occupancy, render_kpi_metric
    from .maps import create_disaster_map
    from .tables import render_data_table, render_filterable_table
except ImportError:
    pass

"""数据库连接层 - Azure SQL Database (pymssql)"""

import pandas as pd
import pymssql
import streamlit as st
import re
import os
import threading


def _get_db_params() -> dict | None:
    """读取数据库连接参数"""
    try:
        return {
            "server": st.secrets["azure_sql"]["server"],
            "database": st.secrets["azure_sql"]["database"],
            "user": st.secrets["azure_sql"]["username"],
            "password": st.secrets["azure_sql"]["password"],
        }
    except KeyError:
        pass

    server = os.getenv("AZURE_SQL_SERVER")
    database = os.getenv("AZURE_SQL_DATABASE", "disaster_db")
    username = os.getenv("AZURE_SQL_USERNAME")
    password = os.getenv("AZURE_SQL_PASSWORD")
    if all([server, username, password]):
        return {"server": server, "database": database, "user": username, "password": password}
    return None


_sessions: dict = {}
_sessions_lock = threading.Lock()


def _get_session_id() -> str:
    """获取当前 Streamlit 会话 ID，用于跨页面保持同一连接"""
    try:
        from streamlit.runtime.scriptrunner import get_script_run_ctx
        ctx = get_script_run_ctx()
        if ctx and ctx.session_id:
            return ctx.session_id
    except Exception:
        pass
    return f"thread_{threading.get_ident()}"


def _raw_connect() -> pymssql.Connection | None:
    """底层连接创建"""
    params = _get_db_params()
    if not params:
        return None
    try:
        return pymssql.connect(**params, autocommit=True, login_timeout=10, timeout=10)
    except Exception:
        return None


_last_error: str = ""


def get_connection() -> pymssql.Connection | None:
    """按 Streamlit 会话保持数据库连接，同一用户跨页面复用"""
    sid = _get_session_id()
    with _sessions_lock:
        if sid in _sessions:
            conn = _sessions[sid]
            try:
                conn.cursor().execute("SELECT 1")
                return conn
            except Exception:
                try:
                    conn.close()
                except Exception:
                    pass
                del _sessions[sid]
        conn = _raw_connect()
        if conn:
            _sessions[sid] = conn
        return conn


def get_connection_with_error() -> tuple[pymssql.Connection | None, str]:
    """返回 (连接, 错误信息)，用于侧边栏状态检测"""
    global _last_error
    params = _get_db_params()
    if not params:
        _last_error = "未配置数据库连接信息，请在 Streamlit Cloud Secrets 中设置 [azure_sql]"
        return None, _last_error
    try:
        conn = get_connection()
        if conn is None:
            _last_error = "连接失败（Azure 可能休眠中，请稍后刷新）"
        else:
            _last_error = ""
        return conn, _last_error
    except Exception as e:
        _last_error = str(e)
        return None, _last_error


@st.cache_data(ttl=30, show_spinner=False)
def execute_query(sql: str, params: tuple | None = None) -> pd.DataFrame:
    """执行 SELECT 查询，返回 DataFrame。带 30 秒缓存。"""
    conn = get_connection()
    if conn is None:
        return pd.DataFrame()
    try:
        return pd.read_sql(sql, conn, params=params)
    except Exception as e:
        raise RuntimeError(f"查询执行失败: {e}")


def execute_query_nocache(sql: str, params: tuple | None = None) -> pd.DataFrame:
    """执行 SELECT 查询，不缓存（用于写操作后的实时查询）"""
    conn = get_connection()
    if conn is None:
        return pd.DataFrame()
    try:
        return pd.read_sql(sql, conn, params=params)
    except Exception as e:
        raise RuntimeError(f"查询执行失败: {e}")


def execute_proc(proc_name: str, params: dict | None = None) -> pd.DataFrame:
    """执行存储过程，返回 DataFrame"""
    conn = get_connection()
    if conn is None:
        return pd.DataFrame()
    try:
        cursor = conn.cursor()
        if params:
            placeholders = ", ".join(["%s" for _ in params])
            sql = f"EXEC {proc_name} {placeholders}"
            cursor.execute(sql, tuple(params.values()))
        else:
            cursor.execute(f"EXEC {proc_name}")
        columns = [col[0] for col in cursor.description] if cursor.description else []
        rows = cursor.fetchall()
        return pd.DataFrame.from_records(rows, columns=columns)
    except Exception as e:
        raise RuntimeError(f"存储过程执行失败: {e}")


def execute_non_query(sql: str, params: tuple | None = None) -> bool:
    """执行非查询语句 (INSERT/UPDATE/DELETE)，返回是否成功"""
    conn = get_connection()
    if conn is None:
        return False
    try:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        st.cache_data.clear()
        return True
    except Exception as e:
        st.error(f"操作失败: {e}")
        return False


def execute_proc_non_query(proc_name: str, params: dict | None = None) -> bool:
    """执行写操作的存储过程，返回是否成功。成功后刷新缓存。"""
    conn = get_connection()
    if conn is None:
        return False
    try:
        cursor = conn.cursor()
        if params:
            placeholders = ", ".join(["%s" for _ in params])
            sql = f"EXEC {proc_name} {placeholders}"
            cursor.execute(sql, tuple(params.values()))
        else:
            cursor.execute(f"EXEC {proc_name}")
        st.cache_data.clear()
        return True
    except Exception as e:
        st.error(f"存储过程执行失败: {e}")
        return False


@st.cache_data(ttl=300, show_spinner=False)
def get_tables() -> list[str]:
    """获取所有用户表名"""
    sql = """
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_SCHEMA = 'dbo'
    ORDER BY TABLE_NAME
    """
    df = execute_query_nocache(sql)
    return df["TABLE_NAME"].tolist() if not df.empty else []


@st.cache_data(ttl=300, show_spinner=False)
def get_table_schema(table_name: str) -> pd.DataFrame:
    """获取表结构信息"""
    sql = """
    SELECT
        c.COLUMN_NAME AS 列名,
        c.DATA_TYPE AS 数据类型,
        CASE WHEN c.IS_NULLABLE = 'NO' THEN 'NOT NULL' ELSE 'NULL' END AS 允许NULL,
        CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 'PK' ELSE '' END AS 主键
    FROM INFORMATION_SCHEMA.COLUMNS c
    LEFT JOIN (
        SELECT ku.TABLE_NAME, ku.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
            ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
        WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) pk ON c.TABLE_NAME = pk.TABLE_NAME AND c.COLUMN_NAME = pk.COLUMN_NAME
    WHERE c.TABLE_NAME = %s
      AND c.TABLE_SCHEMA = 'dbo'
    ORDER BY c.ORDINAL_POSITION
    """
    return execute_query_nocache(sql, (table_name,))


@st.cache_data(ttl=300, show_spinner=False)
def get_views() -> list[str]:
    """获取所有视图名"""
    sql = """
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'dbo'
    ORDER BY TABLE_NAME
    """
    df = execute_query_nocache(sql)
    return df["TABLE_NAME"].tolist() if not df.empty else []


@st.cache_data(ttl=300, show_spinner=False)
def get_procedures() -> list[str]:
    """获取所有存储过程名"""
    sql = """
    SELECT ROUTINE_NAME
    FROM INFORMATION_SCHEMA.ROUTINES
    WHERE ROUTINE_TYPE = 'PROCEDURE'
      AND ROUTINE_SCHEMA = 'dbo'
    ORDER BY ROUTINE_NAME
    """
    df = execute_query_nocache(sql)
    return df["ROUTINE_NAME"].tolist() if not df.empty else []


def is_safe_sql(sql: str) -> bool:
    """检查 SQL 是否只读安全（仅允许 SELECT 和 EXEC）"""
    stripped = sql.strip().upper()
    stripped = re.sub(r'--.*$', '', stripped, flags=re.MULTILINE)
    stripped = re.sub(r'/\*.*?\*/', '', stripped, flags=re.DOTALL)
    stripped = stripped.strip()

    if not stripped:
        return False

    if stripped.startswith("SELECT") or stripped.startswith("EXEC"):
        return True
    return False


def get_sample_sql() -> list[tuple[str, str]]:
    """预置示例 SQL 列表"""
    return [
        ("查看所有受灾点", "SELECT * FROM disaster_sites ORDER BY reported_at DESC;"),
        ("灾情总览视图", "SELECT * FROM vw_DisasterOverview ORDER BY severity_level DESC;"),
        ("仓库库存总览", "SELECT * FROM vw_WarehouseStock WHERE available_stock > 0;"),
        ("医院接诊能力", "SELECT * FROM vw_HospitalCapacity ORDER BY vacancy_rate ASC;"),
        ("物资需求-待满足", "SELECT * FROM material_demands WHERE status IN ('待满足','部分满足') ORDER BY urgency_level DESC;"),
        ("调拨记录", "SELECT dr.*, ds.site_name, w.warehouse_name FROM dispatch_records dr JOIN disaster_sites ds ON dr.to_site_id = ds.site_id JOIN warehouses w ON dr.from_warehouse_id = w.warehouse_id ORDER BY dr.dispatched_at DESC;"),
        ("物资分类树", "EXEC sp_GetCategoryTree;"),
        ("智能调拨示例", "EXEC sp_GetDispatchPlan @p_site_id = 1, @p_spec_id = 1, @p_quantity = 100;"),
        ("周边资源查询", "EXEC sp_GetNearbyResources @p_site_id = 1, @p_radius_km = 50;"),
    ]

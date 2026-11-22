import pandas as pd
import plotly.express as px
import streamlit as st

st.set_page_config(page_title="Nassau Candy Route Dashboard", layout="wide")
st.title("Nassau Candy: Shipping Route Efficiency")

STATE_CODES = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR", "California": "CA",
    "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE", "District of Columbia": "DC",
    "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID", "Illinois": "IL",
    "Indiana": "IN", "Iowa": "IA", "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA",
    "Maine": "ME", "Maryland": "MD", "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN",
    "Mississippi": "MS", "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
    "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
    "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK", "Oregon": "OR",
    "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
    "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT", "Virginia": "VA",
    "Washington": "WA", "West Virginia": "WV", "Wisconsin": "WI", "Wyoming": "WY",
}


@st.cache_data
def load_orders():
    df = pd.read_csv("orders_routes.csv")
    df["Order_Dt"] = pd.to_datetime(df["Order_Dt"])
    df["Ship_Dt"] = pd.to_datetime(df["Ship_Dt"])
    df["State_Code"] = df["State_Province"].map(STATE_CODES)
    return df


def build_routes(data, min_ship):
    routes = (
        data.groupby(["Factory", "State_Province", "Route"])
        .agg(
            shipments=("Lead_Time_Adj", "size"),
            avg_lead_time=("Lead_Time_Adj", "mean"),
            lead_time_std=("Lead_Time_Adj", "std"),
            delay_pct=("Delayed", "mean"),
        )
        .reset_index()
    )
    routes["delay_pct"] = routes["delay_pct"] * 100
    routes = routes[routes["shipments"] >= min_ship].copy()
    if routes.empty:
        return routes
    lo, hi = routes["avg_lead_time"].min(), routes["avg_lead_time"].max()
    if hi > lo:
        routes["efficiency_score"] = (hi - routes["avg_lead_time"]) / (hi - lo) * 100
    else:
        routes["efficiency_score"] = 100.0
    return routes.round(2)


orders = load_orders()

# ---------- Sidebar filters ----------
st.sidebar.header("Filters")

min_date = orders["Order_Dt"].min().date()
max_date = orders["Order_Dt"].max().date()
date_range = st.sidebar.date_input(
    "Order date range", (min_date, max_date), min_value=min_date, max_value=max_date
)
if len(date_range) != 2:
    st.info("Please select both a start date and an end date.")
    st.stop()
start, end = date_range

all_modes = sorted(orders["Ship_Mode"].unique())
ship_modes = st.sidebar.multiselect("Ship mode", all_modes, default=all_modes)

all_regions = sorted(orders["Region"].unique())
regions = st.sidebar.multiselect("Region", all_regions, default=all_regions)

states = st.sidebar.multiselect("State (leave empty for all)", sorted(orders["State_Province"].unique()))
factory = st.sidebar.selectbox("Factory", ["All"] + sorted(orders["Factory"].unique()))

threshold = st.sidebar.slider("Delay threshold (days)", 1, 8, 6)
min_ship = st.sidebar.slider("Minimum shipments per route", 1, 100, 10)

# ---------- Apply filters ----------
mask = (orders["Order_Dt"].dt.date >= start) & (orders["Order_Dt"].dt.date <= end)
mask &= orders["Ship_Mode"].isin(ship_modes)
mask &= orders["Region"].isin(regions)
if states:
    mask &= orders["State_Province"].isin(states)
if factory != "All":
    mask &= orders["Factory"] == factory

data = orders[mask].assign(Delayed=lambda d: d["Lead_Time_Adj"] > threshold)
if data.empty:
    st.warning("No orders match these filters.")
    st.stop()

# ---------- KPI cards ----------
c1, c2, c3, c4 = st.columns(4)
c1.metric("Shipments", f"{len(data):,}")
c2.metric("Avg lead time (days)", f"{data['Lead_Time_Adj'].mean():.2f}")
c3.metric("Delay frequency", f"{100 * data['Delayed'].mean():.1f}%")
c4.metric("Routes", data["Route"].nunique())

tab1, tab2, tab3, tab4 = st.tabs(
    ["Route efficiency", "Geographic map", "Ship mode comparison", "Route drill-down"]
)

# ===================== Module 1: Route efficiency =====================
with tab1:
    st.subheader("Route performance leaderboard")
    routes = build_routes(data, min_ship)
    if routes.empty:
        st.warning("No routes have enough shipments. Lower the minimum shipments slider.")
    else:
        view = st.radio("Show", ["Fastest 10", "Slowest 10"], horizontal=True)
        ranked = routes.sort_values("avg_lead_time", ascending=(view == "Fastest 10")).head(10)
        fig = px.bar(ranked, x="avg_lead_time", y="Route", orientation="h", title=view + " routes")
        fig.update_layout(yaxis=dict(autorange="reversed"))
        st.plotly_chart(fig)
        st.dataframe(routes.sort_values("avg_lead_time"), hide_index=True)

# ===================== Module 2: Geographic map =====================
with tab2:
    st.subheader("Geographic shipping map")

    state_tbl = (
        data.groupby(["State_Province", "State_Code", "Region"])
        .agg(
            orders=("Lead_Time_Adj", "size"),
            avg_lead_time=("Lead_Time_Adj", "mean"),
            delay_pct=("Delayed", "mean"),
        )
        .reset_index()
    )
    state_tbl["delay_pct"] = state_tbl["delay_pct"] * 100
    state_tbl = state_tbl.round(2)

    metric_name = st.radio(
        "Colour the map by", ["Average lead time (days)", "Delay frequency (%)"], horizontal=True
    )
    map_col = "avg_lead_time" if metric_name.startswith("Average") else "delay_pct"
    min_orders = st.slider("Minimum orders per state", 1, 200, 30)

    shown = state_tbl[state_tbl["orders"] >= min_orders]
    if shown.empty:
        st.warning("No state has enough orders. Lower the minimum orders slider.")
    else:
        fig_map = px.choropleth(
            shown,
            locations="State_Code",
            locationmode="USA-states",
            color=map_col,
            scope="usa",
            color_continuous_scale="Reds",
            hover_name="State_Province",
            hover_data=["orders", "avg_lead_time", "delay_pct"],
            title=metric_name + " by state (states with enough orders)",
        )
        st.plotly_chart(fig_map)

    st.markdown("**Regional bottleneck view**")
    us_avg = data["Lead_Time_Adj"].mean()
    state_tbl["Status"] = "Low volume"
    state_tbl.loc[state_tbl["orders"] >= 100, "Status"] = "Normal"
    state_tbl.loc[
        (state_tbl["orders"] >= 100) & (state_tbl["avg_lead_time"] > us_avg), "Status"
    ] = "Bottleneck"

    fig_b = px.scatter(
        state_tbl,
        x="orders",
        y="avg_lead_time",
        size="orders",
        color="Status",
        hover_name="State_Province",
        title="State volume vs average lead time",
    )
    st.plotly_chart(fig_b)

    st.write("Bottleneck states (100+ orders and lead time above the average):")
    bottlenecks = state_tbl[state_tbl["Status"] == "Bottleneck"].sort_values(
        "avg_lead_time", ascending=False
    )
    st.dataframe(
        bottlenecks[["State_Province", "Region", "orders", "avg_lead_time", "delay_pct"]],
        hide_index=True,
    )

    st.write("Region summary:")
    region_tbl = (
        data.groupby("Region")
        .agg(
            orders=("Lead_Time_Adj", "size"),
            avg_lead_time=("Lead_Time_Adj", "mean"),
            delay_pct=("Delayed", "mean"),
        )
        .reset_index()
    )
    region_tbl["delay_pct"] = region_tbl["delay_pct"] * 100
    st.dataframe(region_tbl.round(2).sort_values("avg_lead_time", ascending=False), hide_index=True)

# ===================== Module 3: Ship mode comparison =====================
with tab3:
    st.subheader("Ship mode comparison")

    modes = (
        data.groupby("Ship_Mode")
        .agg(
            orders=("Lead_Time_Adj", "size"),
            avg_lead_time=("Lead_Time_Adj", "mean"),
            lead_time_std=("Lead_Time_Adj", "std"),
            delay_pct=("Delayed", "mean"),
            sales=("Sales", "sum"),
            gross_profit=("Gross_Profit", "sum"),
        )
        .reset_index()
    )
    modes["delay_pct"] = modes["delay_pct"] * 100
    modes["profit_margin_pct"] = modes["gross_profit"] / modes["sales"] * 100
    modes = modes.drop(columns=["sales", "gross_profit"]).round(2).sort_values("avg_lead_time")

    fig_m = px.bar(
        modes, x="Ship_Mode", y="avg_lead_time", text_auto=True,
        title="Average lead time by ship mode (days)",
    )
    st.plotly_chart(fig_m)

    group_avg = (
        data.assign(Group=data["Ship_Mode"].map(lambda m: "Standard" if m == "Standard Class" else "Expedited"))
        .groupby("Group")["Lead_Time_Adj"]
        .mean()
        .round(2)
    )
    m1, m2 = st.columns(2)
    m1.metric("Standard Class avg (days)", group_avg.get("Standard", "n/a"))
    m2.metric("Expedited avg (days)", group_avg.get("Expedited", "n/a"))

    st.dataframe(modes, hide_index=True)

    fig_h = px.histogram(
        data, x="Lead_Time_Adj", color="Ship_Mode", barmode="group",
        title="Lead time distribution by ship mode",
    )
    st.plotly_chart(fig_h)
    st.caption(
        "The dataset has no shipping cost, so the cost-time tradeoff is described only through "
        "profit margin (gross profit / sales) by ship mode."
    )

# ===================== Module 4: Route drill-down =====================
with tab4:
    st.subheader("Route drill-down")

    route = st.selectbox("Choose a route", sorted(data["Route"].unique()))
    rd = data[data["Route"] == route]
    state = rd["State_Province"].iloc[0]
    sdata = data[data["State_Province"] == state]

    d1, d2, d3, d4 = st.columns(4)
    d1.metric("Shipments", len(rd))
    d2.metric("Avg lead time (days)", f"{rd['Lead_Time_Adj'].mean():.2f}")
    d3.metric("Delay frequency", f"{100 * rd['Delayed'].mean():.1f}%")
    d4.metric("Standard Class share", f"{100 * (rd['Ship_Mode'] == 'Standard Class').mean():.1f}%")

    st.markdown("**State-level insight: " + state + "**")
    compare = pd.DataFrame(
        {
            "Level": ["This route", "All routes into " + state, "All shipments"],
            "Shipments": [len(rd), len(sdata), len(data)],
            "Avg lead time": [
                rd["Lead_Time_Adj"].mean(), sdata["Lead_Time_Adj"].mean(), data["Lead_Time_Adj"].mean()
            ],
            "Delay %": [
                100 * rd["Delayed"].mean(), 100 * sdata["Delayed"].mean(), 100 * data["Delayed"].mean()
            ],
        }
    ).round(2)
    st.dataframe(compare, hide_index=True)

    fig_t = px.scatter(
        rd, x="Order_Dt", y="Lead_Time_Adj", color="Ship_Mode",
        hover_data=["Order_ID", "Ship_Dt"],
        title="Order-level shipment timeline for " + route,
    )
    st.plotly_chart(fig_t)

    st.dataframe(
        rd[["Order_ID", "Order_Dt", "Ship_Dt", "Ship_Mode", "Lead_Time_Adj", "Delayed"]]
        .sort_values("Order_Dt"),
        hide_index=True,
    )
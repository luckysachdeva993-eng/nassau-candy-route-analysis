# Factory-to-Customer Shipping Route Efficiency Analysis (Nassau Candy Distributor)

Internship project for Unified Mentor by Lucky Sachdeva.

Nassau Candy ships products from five factories to customers across the United States. This project measures which factory-to-state routes are fast or slow, where delays happen, and how ship mode affects delivery speed, using SQL Server for the analysis and a Streamlit dashboard for live exploration.

## Deliverables

| Deliverable | Link |
| Live dashboard (Streamlit) | https://4ysu8fhnmqbubysm4eaxn7.streamlit.app/ |
| Research paper | [add link] |
| Executive summary | [add link] |
| Project explanation video | [add link] |
| Internship experience and feedback video | [add link] |

Note: the free Streamlit app may be asleep after a few days without visitors. If you see "This app has gone to sleep", click "Yes, get this app back up!" and wait about a minute.

## Dashboard screenshots

![Route efficiency](screenshots/tab1_route_efficiency.png)
![Geographic map](screenshots/tab2_map.png)
![Ship mode comparison](screenshots/tab3_ship_mode.png)
![Route drill-down](screenshots/tab4_drilldown.png)

## Dashboard modules and filters

1. **Route efficiency:** average lead time by route, fastest and slowest 10 routes, efficiency score.
2. **Geographic map:** US state map (average lead time or delay frequency), state volume vs lead time, bottleneck states, region summary.
3. **Ship mode comparison:** lead time, delay and profit margin by ship mode, Standard vs Expedited.
4. **Route drill-down:** one route compared with its state and with all shipments, order-level timeline.

Filters: order date range, ship mode, region, state, factory, delay threshold (days) and minimum shipments per route.

## Method

1. **Import and cleaning (SQL Server Express):** 10,194 order rows loaded into SQL Server, dates converted from text (dd-mm-yyyy), 313 duplicate rows removed, 194 Canadian orders excluded from the US analysis (9,687 US orders remain).
2. **Factory mapping:** each product was matched to its factory using the product-to-factory table from the project brief. A **route** is defined as *Factory -> Customer State* (177 routes).
3. **Lead time:** Shipping Lead Time = Ship Date - Order Date.
4. **Lead time adjustment (assumption):** raw lead times in the dataset were 904 to 1,642 days, which cannot be real shipping times. The dates carry whole-year offsets. The adjusted lead time removes the offsets: `Lead_Time_Adj = ((Lead_Time - 904) % 365)`, minus 1 day for the group that carries a leap-year (2028) effect, with a minimum of 0. After this, adjusted lead times range from 0 to 8 days and ship modes average about 0, 2, 3 and 5 days. This is an assumption and is not confirmed by the data provider.
5. **KPIs:** Shipping Lead Time, Average Lead Time, Route Volume, Delay Frequency (share of shipments above a threshold, default 6 days) and Route Efficiency Score (min-max scaled average lead time, 100 = fastest, routes with at least 10 shipments).
6. **Bottleneck states:** states with at least 100 orders and an average lead time above the US average.

## Key findings (US, adjusted lead time)

| Measure | Result |
|---|---|
| Shipments / routes | 9,687 / 177 |
| Average lead time | 3.96 days |
| Delayed shipments (over 6 days) | 613 (6.3%), all Standard Class (10.6% of Standard Class) |
| Average lead time by ship mode | Same Day 0.04, First Class 2.17, Second Class 3.24, Standard Class 5.00 days |
| Share of orders from the two chocolate factories | about 96% (Lot's O' Nuts 5,411 and Wicked Choccy's 3,930) |
| Fastest route (10+ shipments) | Wicked Choccy's -> Louisiana, 2.87 days |
| Slowest route (10+ shipments) | Lot's O' Nuts -> New Mexico, 4.83 days |
| Regions | Atlantic 3.92, Pacific 3.93, Gulf 3.97, Interior 4.04 days |
| Profit margin | about 66% for every ship mode |

- **Ship mode is the biggest driver of lead time.** Route, state and region differences are small (about 1 day) once ship mode is considered.
- Within Standard Class only, route averages range from 4.36 (Lot's O' Nuts -> Nebraska) to 5.60 days (Lot's O' Nuts -> Nevada).
- New Jersey, Oregon, Washington, Indiana and Arizona look consistently slower even within Standard Class, but the differences are small and several samples are modest.
- States with few orders do not look slower than others, so low volume more likely reflects market size than routing problems.

## Limitations

- The date offsets and the leap-year effect are assumptions. Orders from January and February 2024 look about one day slower and January and February 2025 slightly faster (about 7% of orders, changing route averages by only about 0.03 days); no further correction was applied.
- Lead time covers order date to ship date only; delivery dates are not in the dataset.
- Shipping cost is not available, so cost-time tradeoffs are only described through profit margin.
- Only two factories carry most of the volume; routes from the other three have few orders and less reliable averages.
- Fizzy Lifting Drinks is labelled Sugar in the dataset's Division column but Other in the project brief (the brief's reference table was used).
- No orders from Alaska and Hawaii.

## Repository contents

| File | Purpose |
|---|---|
| `app_step_c.py` | Streamlit dashboard (4 tabs) |
| `orders_routes.csv` | US orders with factory, route and adjusted lead time (dashboard data) |
| `route_kpis.csv` | Route-level KPIs from SQL |
| `state_summary.csv` | State-level summary from SQL |
| `nassau_queries_v2.sql` | Complete SQL script (cleaning, factory mapping, routes, KPIs, checks) |
| `requirements.txt` | Python packages for the dashboard |
# Factory-to-Customer Shipping Route Efficiency Analysis (Nassau Candy Distributor)

Internship project for **Unified Mentor** by **Lucky Sachdeva**.

Nassau Candy ships products from five factories to customers across the United States. This project measures which factory-to-state routes are fast or slow, where delays happen, and how ship mode affects delivery speed, using SQL Server for the analysis and a Streamlit dashboard for live exploration.

## Deliverables

| Deliverable | Link |
|---|---|
| Live dashboard (Streamlit) | https://4ysu8fhnmqbubysm4eaxn7.streamlit.app/ |
| Research paper | [add link] |
| Executive summary | [add link] |
| Project explanation video | [add link] |
| Internship experience and feedback video | [add link] |

Note: the free Streamlit app may be asleep after a few days without visitors. If you see "This app has gone to sleep", click "Yes, get this app back up!" and wait about a minute.

## Dashboard screenshots

![Route efficiency](screenshot link )
![Geographic map](screenshots/tab2_map.png)
![Ship mode comparison](screenshots/tab3_ship_mode.png)
![Route drill-down](screenshots/tab4_drilldown.png)

## Dashboard modules and filters

1. **Route efficiency:** average lead time by route, fastest and slowest 10 routes, efficiency score.
2. **Geographic map:** US state map (average lead time or delay frequency), state volume vs lead time, bottleneck states, region summary.
3. **Ship mode comparison:** lead time, delay and profit margin by ship mode, Standard vs Expedited.
4. **Route drill-down:** one route compared with its state and with all shipments, order-level timeline.

Filters: order date range, ship mode, region, state, factory, delay threshold (days) and minimum shipments per route.

## Method

1. **Import and cleaning (SQL Server Express):** 10,194 order rows loaded into SQL Server, dates converted from text (dd-mm-yyyy), 313 duplicate rows removed, 194 Canadian orders excluded from the US analysis (9,687 US orders remain).
2. **Factory mapping:** each product was matched to its factory using the product-to-factory table from the project brief. A **route** is defined as *Factory -> Customer State* (177 routes).
3. **Lead time:** Shipping Lead Time = Ship Date - Order Date.
4. **Lead time adjustment (assumption):** raw lead times in the dataset were 904 to 1,642 days, which cannot be real shipping times. The dates carry whole-year offsets. The adjusted lead time removes the offsets: `Lead_Time_Adj = ((Lead_Time - 904) % 365)`, minus 1 day for the group that carries a leap-year (2028) effect, with a minimum of 0. After this, adjusted lead times range from 0 to 8 days and ship modes average about 0, 2, 3 and 5 days. This is an assumption and is not confirmed by the data provider.
5. **KPIs:** Shipping Lead Time, Average Lead Time, Route Volume, Delay Frequency (share of shipments above a threshold, default 6 days) and Route Efficiency Score (min-max scaled average lead time, 100 = fastest, routes with at least 10 shipments).
6. **Bottleneck states:** states with at least 100 orders and an average lead time above the US average.

## Key findings (US, adjusted lead time)

| Measure | Result |
|---|---|
| Shipments / routes | 9,687 / 177 |
| Average lead time | 3.96 days |
| Delayed shipments (over 6 days) | 613 (6.3%), all Standard Class (10.6% of Standard Class) |
| Average lead time by ship mode | Same Day 0.04, First Class 2.17, Second Class 3.24, Standard Class 5.00 days |
| Share of orders from the two chocolate factories | about 96% (Lot's O' Nuts 5,411 and Wicked Choccy's 3,930) |
| Fastest route (10+ shipments) | Wicked Choccy's -> Louisiana, 2.87 days |
| Slowest route (10+ shipments) | Lot's O' Nuts -> New Mexico, 4.83 days |
| Regions | Atlantic 3.92, Pacific 3.93, Gulf 3.97, Interior 4.04 days |
| Profit margin | about 66% for every ship mode |

- **Ship mode is the biggest driver of lead time.** Route, state and region differences are small (about 1 day) once ship mode is considered.
- Within Standard Class only, route averages range from 4.36 (Lot's O' Nuts -> Nebraska) to 5.60 days (Lot's O' Nuts -> Nevada).
- New Jersey, Oregon, Washington, Indiana and Arizona look consistently slower even within Standard Class, but the differences are small and several samples are modest.
- States with few orders do not look slower than others, so low volume more likely reflects market size than routing problems.

## Limitations

- The date offsets and the leap-year effect are assumptions. Orders from January and February 2024 look about one day slower and January and February 2025 slightly faster (about 7% of orders, changing route averages by only about 0.03 days); no further correction was applied.
- Lead time covers order date to ship date only; delivery dates are not in the dataset.
- Shipping cost is not available, so cost-time tradeoffs are only described through profit margin.
- Only two factories carry most of the volume; routes from the other three have few orders and less reliable averages.
- Fizzy Lifting Drinks is labelled Sugar in the dataset's Division column but Other in the project brief (the brief's reference table was used).
- No orders from Alaska and Hawaii.

## Repository contents

| File | Purpose |
|---|---|
| `app_step_c.py` | Streamlit dashboard (4 tabs) |
| `orders_routes.csv` | US orders with factory, route and adjusted lead time (dashboard data) |
| `route_kpis.csv` | Route-level KPIs from SQL |
| `state_summary.csv` | State-level summary from SQL |
| `nassau_queries_v2.sql` | Complete SQL script (cleaning, factory mapping, routes, KPIs, checks) |
| `requirements.txt` | Python packages for the dashboard |

The original dataset provided by Unified Mentor is not included in this repository.

## Run locally

```bash
pip install -r requirements.txt
streamlit run app_step_c.py
```

## Tools

SQL Server Express, SSMS, Python, pandas, Plotly, Streamlit, GitHub.
## Run locally

```bash
pip install -r requirements.txt
streamlit run app_step_c.py
```

## Tools

SQL Server Express, SSMS, Python, pandas, Plotly, Streamlit, GitHub.

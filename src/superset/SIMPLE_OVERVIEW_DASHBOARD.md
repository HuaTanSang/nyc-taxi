# Hướng dẫn tạo NYC Taxi dashboard trong Superset

Bạn tạo dashboard **một lần** bằng giao diện Superset. Sau khi export, dùng công cụ
trong repo để chuẩn bị file ZIP an toàn cho Git. Các máy clone repo sẽ import sẵn
dashboard khi chạy `make bootstrap`; việc nạp thêm tháng chỉ cập nhật dữ liệu,
không cần tạo hoặc export lại biểu đồ.

Tên dashboard và chart dưới đây dùng tiếng Anh để dễ chia sẻ dự án trên LinkedIn.
Các số liệu insight chỉ nên viết sau khi đã nạp và kiểm tra dữ liệu thật.

## 0. Chuẩn bị

1. Chạy `make configure` rồi `make bootstrap`. Mở Superset tại
   `http://localhost:8088` bằng tài khoản trong file `.env` của bạn.
2. Chạy pipeline Airflow cho ít nhất một tháng để dbt tạo các mart. Nếu chưa có
   mart, Superset chưa thể đăng ký dataset từ ClickHouse.
3. Trong **SQL Lab**, chọn database **NYC Taxi ClickHouse** và thử:

   ```sql
   SELECT count() FROM marts.mart_trip_daily;
   ```

   Số dòng có thể ít lúc đầu; dashboard sẽ tự mở rộng khi các tháng 2025 và 2026
   được nạp thêm. DAG hiện được kích hoạt thủ công.

## 1. Đăng ký bốn dataset

Vào **Data → Datasets → + Dataset**, chọn database **NYC Taxi ClickHouse**,
schema `marts`, rồi thêm từng bảng sau:

| Dataset | Cột thời gian (Temporal) | Vai trò |
| --- | --- | --- |
| `mart_trip_daily` | `pickup_date` | KPI và xu hướng chuyến đi |
| `mart_trip_hourly` | `pickup_date` | Mẫu giờ và thứ trong tuần |
| `mart_pickup_zone_daily` | `pickup_date` | Zone và bản đồ |
| `mart_data_quality_monthly` | `source_period` | Chất lượng theo tháng file nguồn |

Trong **Edit Dataset → Columns**, đánh dấu cột thời gian tương ứng là
**Temporal**. Các cột `service_type`, `pickup_year`, `pickup_month`,
`pickup_hour`, `pickup_day_of_week` và `pickup_location_id` cần dùng được để
group/filter. Không đăng ký `agg_*_by_source` làm dataset cho dashboard: grain
của chúng còn chứa tháng file nguồn.

Trong **Edit Dataset → Metrics**, tạo các metric SQL sau. Format là định dạng
số trong Superset, không phải phép tính thứ hai.

| Dataset | Tên metric | SQL expression | Format |
| --- | --- | --- | --- |
| daily | `Total Trips` | `SUM(trip_count)` | `,.0f` |
| daily | `Trips per Active Day` | `SUM(trip_count) / NULLIF(COUNT(DISTINCT pickup_date), 0)` | `,.0f` |
| daily | `Average Duration (min)` | `SUM(duration_sum_seconds) / NULLIF(SUM(duration_valid_count), 0) / 60.0` | `,.1f` |
| daily | `Average Reported Distance (mi)` | `SUM(distance_sum_miles) / NULLIF(SUM(distance_valid_count), 0)` | `,.2f` |
| hourly | `Total Trips` | `SUM(trip_count)` | `,.0f` |
| hourly | `Trips per Active Day at Hour` | `SUM(trip_count) / NULLIF(COUNT(DISTINCT pickup_date), 0)` | `,.0f` |
| zone | `Total Trips` | `SUM(trip_count)` | `,.0f` |
| quality | `Record-weighted Rate (%)` | `100.0 * SUM(reported_count) / NULLIF(SUM(eligible_count), 0)` | `,.1f` |

`daily`, `hourly`, `zone`, `quality` lần lượt là bốn dataset theo thứ tự bảng
trên. Đặt `Trips per Active Day` đúng tên: mẫu số chỉ gồm ngày có record trong
mart. Các average dùng **tổng chia số record hợp lệ**; không lấy `AVG` của
average từng ngày. Metric quality đã nhân 100, vì vậy chỉ định dạng số `,.1f`,
không dùng format tự nhân thêm 100 lần nữa.

Trong dataset `mart_trip_hourly`, tạo calculated column `weekday_label` để
heatmap luôn sắp thứ tự Thứ Hai → Chủ Nhật:

```sql
concat(toString(pickup_day_of_week), ' ', pickup_day_name)
```

## 2. Tạo chart

Với mỗi chart: **Charts → + Chart → chọn dataset và loại chart → Create New
Chart**. Nhập các trường trong bảng, bấm **Run**, kiểm tra kết quả rồi **Save**
vào dashboard mới tên **NYC Taxi | Mobility Insights**. Trong phần Time Range
của từng chart, chọn **No filter/All time** để không khóa cứng năm 2025; native
filter trên dashboard sẽ điều khiển khoảng ngày.

| Chart title | Dataset / loại chart | Thiết lập chính |
| --- | --- | --- |
| `Total Trips` | daily / Big Number | Metric `Total Trips` |
| `Trips per Active Day` | daily / Big Number | Metric cùng tên; subtitle `Days with reported pickups` |
| `Average Trip Duration` | daily / Big Number | Metric `Average Duration (min)`; subtitle `Valid pickup-to-drop-off duration` |
| `Average Reported Distance` | daily / Big Number | Metric `Average Reported Distance (mi)`; subtitle `Services with valid reported distance; standard FHV excluded` |
| `Monthly Trips by Service` | daily / Time-series Line | Time `pickup_date`, grain **Month**, metric `Total Trips`, series/group by `service_type`; không giới hạn năm |
| `Trips by Calendar Month and Year` | daily / Bar Chart | X `pickup_month` tăng dần, series/group by `pickup_year`, metric `Total Trips`; bộ lọc Service Type vẫn áp dụng |
| `Pickup Demand by Weekday and Hour` | hourly / Heatmap | X `pickup_hour` tăng dần, Y `weekday_label`, metric `Trips per Active Day at Hour` |
| `Top 10 Pickup Zones` | zone / Bar Chart | Group by `pickup_borough` và `pickup_zone`; metric `Total Trips`; sắp giảm dần, row limit 10 |
| `Pickup Zone Demand Map` | zone / deck.gl Scatterplot | Tọa độ `pickup_longitude`/`pickup_latitude`; group by `pickup_location_id`, `pickup_zone`, `pickup_borough` và tọa độ; size/color theo `Total Trips`. Không group theo ngày để một zone chỉ có một điểm trong khoảng được chọn. |
| `Source Data Coverage` | quality / Pivot Table v2 | Rows `service_type`; columns `metric_name`; metric `Record-weighted Rate (%)`; lọc `metric_name` thuộc `pickup_datetime`, `pickup_zone`, `dropoff_zone`, `duration`, `distance`, `passenger_count` |
| `Outside Source Month Rate` | quality / Bar Chart | X `service_type`; metric `Record-weighted Rate (%)`; lọc `metric_name = event_outside_source_month`; tỷ lệ thấp hơn là tốt hơn |

Nếu bản đồ không có ô Group by trong phiên bản giao diện đang dùng, dùng
**Top 10 Pickup Zones** làm chart địa lý chính và giữ bản đồ lại để cấu hình sau;
không chuyển thẳng toàn bộ dòng ngày × zone thành điểm bản đồ vì chúng sẽ chồng
lên nhau. Zone trên bản đồ là **điểm đại diện** của TLC zone, không phải tọa độ
pickup chính xác. Standard FHV không có trong zone mart vì coverage zone thấp;
khi lọc chỉ FHV, chart zone/bản đồ rỗng là đúng.

Coverage là tỷ lệ có trọng số trên **toàn bộ tháng nguồn đã nạp**. Ô trống có
nghĩa `not_applicable` khi nguồn không cung cấp chỉ số đó; không đổi ô trống
thành 0%. Không dùng `MAX(coverage_percent)` vì nó chỉ chọn tháng tốt nhất,
không phản ánh toàn kỳ.

## 3. Bố cục, bộ lọc và cách đọc insight

Trong **Edit Dashboard**, đặt bốn KPI ở hàng đầu; hai chart xu hướng ở hàng
hai; heatmap và Top 10 zone ở hàng ba; bản đồ chiếm cả hàng bốn; coverage và
anomaly rate ở cuối. Giữ màu dịch vụ nhất quán: Yellow `#F2C80F`, Green
`#2CA02C`, FHV `#7F7F7F`, FHVHV `#1F77B4`.

Mở **Filter Bar → Add/Edit Filters**:

1. Thêm **Pickup Date Range**, loại **Time Range**, dùng `pickup_date` và scope
   đến mọi KPI/chart thuộc daily, hourly, zone. Mặc định **No filter/All time**;
   người xem có thể chọn một tháng, cả năm hoặc ngày bắt đầu/kết thúc bất kỳ.
2. Thêm **Service Type**, loại **Select**, cột `service_type`, cho phép chọn
   nhiều giá trị. Scope đến cả chart mobility và quality. Kiểm tra filter tác
   động được lên từng dataset tương ứng.
3. Không scope Pickup Date Range đến hai quality chart: `source_period` là
   **tháng của file nguồn**, còn `pickup_date` là **ngày xảy ra chuyến đi**.
   Đặt subtitle của hai chart quality là `All ingested source months`.

Để bài LinkedIn có insight rõ, chọn một khoảng ngày trong bộ lọc rồi đọc ba
câu hỏi từ chart: dịch vụ nào tăng/giảm theo tháng, giờ nào đông nhất theo thứ,
và zone nào đứng đầu. Chỉ so sánh cùng tháng 2025–2026 sau khi cả hai tháng
đã được nạp đủ. Ghi số liệu thật và khoảng ngày đã chọn trên ảnh/bài đăng;
không suy diễn số liệu từ chart chưa hoàn chỉnh.

## 4. Export một lần để máy khác có sẵn dashboard

Sau khi kiểm tra chart và filter, mở dashboard, chọn **Export** từ menu hành
động của dashboard (hoặc trang danh sách Dashboards) và tải **dashboard ZIP**.
Chọn export dashboard thông thường, không chọn **Export as example**, vì loại
example có thể kèm bản sao dữ liệu. ZIP dashboard của Superset bao gồm chart,
dataset và định nghĩa database liên quan.

Chạy lệnh dưới đây từ root repo; thay đường dẫn bằng file bạn vừa tải:

```bash
python3 src/superset/bootstrap/prepare_dashboard_export.py /path/to/dashboard_export.zip
```

Công cụ kiểm tra định dạng export, UUID kết nối ClickHouse, đúng bốn dataset
`marts`, chart references, đường dẫn ZIP và dấu hiệu credential. Nó **thay toàn
bộ cấu hình database** trong ZIP bằng template không chứa mật khẩu của repo,
rồi tạo `src/superset/bootstrap/dashboard/nyc_taxi_overview.zip`. Nếu bạn đã
chuẩn bị một export trước đó và muốn cập nhật, thêm `--replace`.

Chỉ commit file ZIP **đã chuẩn bị**, không commit ZIP tải trực tiếp từ Superset:

```bash
git add src/superset/bootstrap/dashboard/nyc_taxi_overview.zip
```

Sau khi thay bundle, chạy `make bootstrap` để build lại image và import bản
mới. Trên máy clone repo, `make configure && make bootstrap` sẽ import kết nối,
dataset, chart và dashboard. Chạy bootstrap nhiều lần dùng UUID để cập nhật
asset hiện có, không tạo bản sao. Nếu chưa commit ZIP thì bootstrap chỉ tạo
kết nối ClickHouse và in lời nhắc; việc tạo dashboard thủ công vẫn làm được.
Khi bạn chỉnh chart trong UI về sau, export lại và chạy công cụ `--replace` để
đưa phiên bản mới lên Git.

Dashboard đọc trực tiếp các mart hiện có. Sau mỗi lần pipeline nạp tháng mới,
làm mới trang sẽ thấy dữ liệu mới; không cần export lại. Nếu để trang mở lâu,
có thể bật auto-refresh trong menu dashboard, nhưng thiết lập này chỉ áp dụng
cho phiên đang mở.

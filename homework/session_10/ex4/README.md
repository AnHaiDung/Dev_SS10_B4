# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu
- **Custom Bridge Network (`app-net`)**: Cho phép các Container giao tiếp nội bộ qua tên service thông qua cơ chế DNS resolution tự động của Docker.
- **Named Volume (`db-data`)**: Đảm bảo dữ liệu cơ sở dữ liệu PostgreSQL được lưu trữ bền vững (Data Persistence) độc lập với vòng đời của Container.

---

## 2. Cấu trúc thư mục
```text
homework/session_10/ex4/
├── commands.sh   # Script thực thi tự động toàn bộ quy trình
└── README.md     # Báo cáo và kết quả thực nghiệm chi tiết
```

---

## 3. Các bước thực hiện & Lệnh Docker CLI

### Bước 1: Tạo Custom Bridge Network & Named Volume
```bash
# Tạo mạng bridge tùy chỉnh
docker network create app-net

# Tạo named volume cho DB
docker volume create db-data
```

### Bước 2: Khởi chạy Database Container (`db-server`)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine
```

### Bước 3: Khởi chạy Backend Container (`app-container`)
```bash
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine:latest sleep infinity
```

---

## 4. Kết quả kiểm tra (Verification & Test Results)

### 4.1. Kiểm tra DNS Resolution qua Custom Network
Thực thi lệnh ping `db-server` từ container `app-container`:
```bash
docker exec -it app-container ping -c 2 db-server
```
**Kết quả thực tế:**
```text
PING db-server (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.063 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.149 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.063/0.106/0.149 ms
```
> **Đánh giá**: `app-container` đã phân giải thành công hostname `db-server` thành IP nội bộ `172.20.0.2` thông qua Docker Embedded DNS.

---

### 4.2. Kiểm tra Data Persistence (Lưu trữ bền vững)

1. **Thêm dữ liệu mẫu vào `db-server`:**
```bash
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));"
docker exec -i db-server psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
*Kết quả:*
```text
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```

2. **Xóa cứng Container `db-server`:**
```bash
docker rm -f db-server
```

3. **Khởi chạy lại container mới gắn cùng Volume `db-data`:**
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine
```

4. **Kiểm tra dữ liệu sau khi tái tạo:**
```bash
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"
```
*Kết quả:*
```text
 id | name  
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```
> **Đánh giá**: Toàn bộ dữ liệu bảng `users` được giữ nguyên vẹn 100% nhờ Named Volume `db-data`.

---

### 4.3. Kiểm tra Network & Volume bằng lệnh Docker CLI

- **Kiểm tra mạng:**
```bash
docker network ls | grep app-net
```
*Output:*
```text
19a9be610924   app-net           bridge    local
```

- **Kiểm tra volume:**
```bash
docker volume ls | grep db-data
```
*Output:*
```text
local     db-data
```

- **Kiểm tra chi tiết kết nối mạng:**
```bash
docker network inspect app-net
```
*Output:* Cả hai container `app-container` (`172.20.0.3`) và `db-server` (`172.20.0.2`) đều đang kết nối chung mạng `app-net`.

---

## 5. Hướng dẫn chạy Script tự động
```bash
chmod +x commands.sh
./commands.sh
```

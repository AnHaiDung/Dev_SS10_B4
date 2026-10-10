#!/bin/bash
set -e

echo "=========================================================="
echo "1. Tạo Custom Bridge Network: app-net"
echo "=========================================================="
docker network create app-net

echo "=========================================================="
echo "2. Tạo Named Volume: db-data"
echo "=========================================================="
docker volume create db-data

echo "=========================================================="
echo "3. Khởi chạy Database Container (db-server)"
echo "=========================================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine

echo "Chờ PostgreSQL sẵn sàng..."
docker exec db-server sh -c 'until pg_isready -U postgres; do sleep 1; done'

echo "=========================================================="
echo "4. Khởi chạy Backend Container (app-container)"
echo "=========================================================="
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=testdb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  alpine:latest sleep infinity

echo "=========================================================="
echo "5. Kiểm tra DNS nội bộ: Ping db-server từ app-container"
echo "=========================================================="
docker exec app-container ping -c 2 db-server

echo "=========================================================="
echo "6. Test Data Persistence"
echo "=========================================================="
echo "--> Tạo bảng và thêm dữ liệu vào db-server:"
docker exec -i db-server psql -U postgres -d testdb -c "CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));"
docker exec -i db-server psql -U postgres -d testdb -c "INSERT INTO users (name) VALUES ('Alice'), ('Bob');"

echo "--> Dữ liệu ban đầu trong database:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "--> Xóa cứng container db-server (docker rm -f db-server):"
docker rm -f db-server

echo "--> Khởi chạy container db-server mới gắn cùng volume db-data:"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:15-alpine

echo "Chờ PostgreSQL mới sẵn sàng..."
docker exec db-server sh -c 'until pg_isready -U postgres; do sleep 1; done'

echo "--> Xác minh dữ liệu sau khi xóa và tạo mới container:"
docker exec -i db-server psql -U postgres -d testdb -c "SELECT * FROM users;"

echo "=========================================================="
echo "7. Các lệnh kiểm tra cấu hình (Verification Commands)"
echo "=========================================================="
echo "--> docker network ls | grep app-net"
docker network ls | grep app-net || true

echo "--> docker volume ls | grep db-data"
docker volume ls | grep db-data || true

echo "--> docker network inspect app-net"
docker network inspect app-net

echo "=========================================================="
echo "HOÀN TẤT THỬ NGHIỆM THÀNH CÔNG!"
echo "=========================================================="

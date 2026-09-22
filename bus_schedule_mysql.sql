SET NAMES utf8mb4;

CREATE TABLE cities (
    city_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    UNIQUE KEY uq_cities_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stations (
    station_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    name        VARCHAR(150) NOT NULL,
    address     VARCHAR(255),
    CONSTRAINT fk_stations_city FOREIGN KEY (city_id) REFERENCES cities(city_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE buses (
    bus_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reg_number  VARCHAR(20) NOT NULL,
    model       VARCHAR(100),
    capacity    SMALLINT UNSIGNED NOT NULL,
    status      ENUM('active','maintenance','retired') NOT NULL DEFAULT 'active',
    UNIQUE KEY uq_buses_reg_number (reg_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- статический шаблон маршрута
CREATE TABLE routes (
    route_id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code                    VARCHAR(20) NOT NULL,
    name                    VARCHAR(150) NOT NULL,
    origin_station_id       INT UNSIGNED NOT NULL,
    destination_station_id  INT UNSIGNED NOT NULL,
    UNIQUE KEY uq_routes_code (code),
    CONSTRAINT fk_routes_origin FOREIGN KEY (origin_station_id) REFERENCES stations(station_id),
    CONSTRAINT fk_routes_destination FOREIGN KEY (destination_station_id) REFERENCES stations(station_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- индекс на destination_station_id для join'а "куда идёт рейс"
CREATE INDEX idx_routes_destination ON routes (destination_station_id);

-- последовательность остановок маршрута
CREATE TABLE route_stops (
    route_id             INT UNSIGNED NOT NULL,
    stop_order           SMALLINT UNSIGNED NOT NULL,
    station_id           INT UNSIGNED NOT NULL,
    arrival_offset_min   INT NOT NULL,
    departure_offset_min INT NOT NULL,
    PRIMARY KEY (route_id, stop_order),
    CONSTRAINT fk_route_stops_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
    CONSTRAINT fk_route_stops_station FOREIGN KEY (station_id) REFERENCES stations(station_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- конкретный рейс: маршрут + автобус + дата
CREATE TABLE trips (
    trip_id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    route_id           INT UNSIGNED NOT NULL,
    bus_id             INT UNSIGNED NOT NULL,
    departure_date     DATE NOT NULL,
    planned_departure  DATETIME NOT NULL,
    status             ENUM('scheduled','boarding','departed','delayed','cancelled','arrived')
                        NOT NULL DEFAULT 'scheduled',
    CONSTRAINT fk_trips_route FOREIGN KEY (route_id) REFERENCES routes(route_id),
    CONSTRAINT fk_trips_bus FOREIGN KEY (bus_id) REFERENCES buses(bus_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_trips_route_id ON trips (route_id);
CREATE INDEX idx_trips_bus_id   ON trips (bus_id);

-- факт/план по каждой остановке рейса — то, что читает табло
CREATE TABLE trip_stops (
    trip_id              BIGINT UNSIGNED NOT NULL,
    stop_order           SMALLINT UNSIGNED NOT NULL,
    station_id           INT UNSIGNED NOT NULL,
    scheduled_arrival    DATETIME,
    scheduled_departure  DATETIME,
    actual_arrival       DATETIME,
    actual_departure     DATETIME,
    platform             VARCHAR(10),
    status               ENUM('scheduled','boarding','departed','delayed','cancelled')
                          NOT NULL DEFAULT 'scheduled',
    PRIMARY KEY (trip_id, stop_order),
    CONSTRAINT fk_trip_stops_trip FOREIGN KEY (trip_id) REFERENCES trips(trip_id),
    CONSTRAINT fk_trip_stops_station FOREIGN KEY (station_id) REFERENCES stations(station_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- Индексы для запроса табло
-- ============================================================

-- основной индекс: закрывает и WHERE station_id=..., и ORDER BY scheduled_departure
CREATE INDEX idx_trip_stops_station_departure
    ON trip_stops (station_id, scheduled_departure);

-- покрывающий индекс (covering index) под конкретный SELECT табло:
-- MySQL не поддерживает INCLUDE как в PostgreSQL, поэтому нужные колонки
-- добавляются в хвост составного индекса
CREATE INDEX idx_trip_stops_board
    ON trip_stops (station_id, scheduled_departure, trip_id, platform, status, actual_departure);

-- ============================================================
-- Пример данных
-- ============================================================

INSERT INTO cities (name) VALUES
('Москва'), ('Тверь'), ('Ярославль'), ('Владимир'), ('Рязань');

INSERT INTO stations (city_id, name) VALUES
(1, 'Автовокзал Москва (Щёлковский)'),
(2, 'Автовокзал Тверь'),
(3, 'Автовокзал Ярославль'),
(4, 'Автовокзал Владимир'),
(5, 'Автовокзал Рязань');

-- 20 автобусов
INSERT INTO buses (reg_number, model, capacity)
SELECT CONCAT('A', LPAD(seq, 3, '0'), 'MX77'), 'ПАЗ-320', 45
FROM (
    SELECT ROW_NUMBER() OVER () AS seq
    FROM information_schema.columns
    LIMIT 20
) t;

-- маршруты (часть графа: Москва — хаб)
INSERT INTO routes (code, name, origin_station_id, destination_station_id) VALUES
('R-101', 'Москва — Тверь',              1, 2),
('R-102', 'Тверь — Москва',              2, 1),
('R-103', 'Москва — Ярославль',          1, 3),
('R-104', 'Ярославль — Москва',          3, 1),
('R-105', 'Москва — Владимир',           1, 4),
('R-106', 'Владимир — Москва',           4, 1),
('R-107', 'Москва — Рязань',             1, 5),
('R-108', 'Рязань — Москва',             5, 1),
('R-109', 'Москва — Владимир — Рязань',  1, 5); -- транзитный маршрут

INSERT INTO route_stops (route_id, stop_order, station_id, arrival_offset_min, departure_offset_min) VALUES
(9, 1, 1, 0,   10),   -- Москва, старт
(9, 2, 4, 120, 135),  -- Владимир, транзит
(9, 3, 5, 240, 240);  -- Рязань, финиш

-- рейсы на сегодня: каждый маршрут отправляется несколько раз в день
INSERT INTO trips (route_id, bus_id, departure_date, planned_departure)
SELECT r.route_id,
       1 + ((r.route_id + h) % 20),
       CURDATE(),
       TIMESTAMP(CURDATE()) + INTERVAL h HOUR
FROM routes r
JOIN (
    SELECT 6 AS h UNION SELECT 8 UNION SELECT 10 UNION SELECT 12
    UNION SELECT 14 UNION SELECT 16 UNION SELECT 18 UNION SELECT 20 UNION SELECT 22
) hours ON TRUE;

-- trip_stops (упрощённо, для точечных маршрутов — одна запись отправления)
INSERT INTO trip_stops (trip_id, stop_order, station_id, scheduled_departure, status)
SELECT t.trip_id, 1, r.origin_station_id, t.planned_departure, 'scheduled'
FROM trips t
JOIN routes r ON r.route_id = t.route_id;

-- ============================================================
-- Запрос для табло: ближайшие 15 отправлений с заданной остановки
-- ============================================================

SELECT
    r.code                    AS route_code,
    r.name                    AS route_name,
    dst.name                  AS destination,
    ts.scheduled_departure,
    ts.actual_departure,
    ts.platform,
    ts.status,
    b.reg_number              AS bus_number
FROM trip_stops ts
JOIN trips    t   ON t.trip_id = ts.trip_id
JOIN routes   r   ON r.route_id = t.route_id
JOIN stations dst ON dst.station_id = r.destination_station_id
JOIN buses    b   ON b.bus_id = t.bus_id
WHERE ts.station_id = 1
  AND ts.scheduled_departure >= NOW()
  AND ts.status <> 'cancelled'
ORDER BY ts.scheduled_departure
LIMIT 15;

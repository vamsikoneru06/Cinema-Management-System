-- ============================================================
--  CINEMA MANAGEMENT SYSTEM – Complete SQL Script
--  Course : 21CSC205P Database Management Systems
--  Authors : K Mohan Vamsi [RA2411030010013]
--             A Teja Rayal  [RA2411030010022]
--  Guide   : Dr. Saranya G
-- ============================================================

-- ─────────────────────────────────────────────────
--  DATABASE CREATION
-- ─────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS CinemaManagement;
USE CinemaManagement;

-- ─────────────────────────────────────────────────
--  PART 1 : TABLE SCHEMA (DDL)
-- ─────────────────────────────────────────────────

-- 1. Genre
CREATE TABLE Genre (
    genre_id    INT          PRIMARY KEY AUTO_INCREMENT,
    genre_name  VARCHAR(50)  NOT NULL UNIQUE,
    description TEXT
);

-- 2. Movie
CREATE TABLE Movie (
    movie_id     INT             PRIMARY KEY AUTO_INCREMENT,
    title        VARCHAR(100)    NOT NULL,
    release_date DATE,
    director     VARCHAR(100),
    producer     VARCHAR(100),
    budget       DECIMAL(15,2)   CHECK (budget >= 0),
    duration     INT             NOT NULL CHECK (duration > 0),
    rating       DECIMAL(3,1)    CHECK (rating BETWEEN 0 AND 10),
    genre_id     INT,
    FOREIGN KEY (genre_id) REFERENCES Genre(genre_id)
);

-- 3. Actor
CREATE TABLE Actor (
    actor_id INT          PRIMARY KEY AUTO_INCREMENT,
    name     VARCHAR(100) NOT NULL,
    dob      DATE
);

-- 4. Movie_Actor  (M-M junction)
CREATE TABLE Movie_Actor (
    movie_id INT,
    actor_id INT,
    role     VARCHAR(100),
    PRIMARY KEY (movie_id, actor_id),
    FOREIGN KEY (movie_id) REFERENCES Movie(movie_id)  ON DELETE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES Actor(actor_id)  ON DELETE CASCADE
);

-- 5. Seat_Layout
CREATE TABLE Seat_Layout (
    layout_id    INT         PRIMARY KEY AUTO_INCREMENT,
    name         VARCHAR(50) NOT NULL,
    description  TEXT,
    total_rows   INT         NOT NULL CHECK (total_rows > 0),
    seats_per_row INT        NOT NULL CHECK (seats_per_row > 0),
    created_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- 6. Theatre
CREATE TABLE Theatre (
    theatre_id INT          PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    location   VARCHAR(255) NOT NULL
);

-- 7. Auditorium
CREATE TABLE Auditorium (
    auditorium_id INT PRIMARY KEY AUTO_INCREMENT,
    theatre_id    INT NOT NULL,
    hall_number   INT NOT NULL,
    capacity      INT NOT NULL CHECK (capacity > 0),
    layout_id     INT,
    FOREIGN KEY (theatre_id) REFERENCES Theatre(theatre_id)       ON DELETE CASCADE,
    FOREIGN KEY (layout_id)  REFERENCES Seat_Layout(layout_id)
);

-- 8. Seat
CREATE TABLE Seat (
    seat_id       INT PRIMARY KEY AUTO_INCREMENT,
    auditorium_id INT NOT NULL,
    row_num       INT NOT NULL CHECK (row_num > 0),
    seat_number   INT NOT NULL CHECK (seat_number > 0),
    layout_id     INT,
    FOREIGN KEY (auditorium_id) REFERENCES Auditorium(auditorium_id) ON DELETE CASCADE,
    FOREIGN KEY (layout_id)     REFERENCES Seat_Layout(layout_id)
);

-- 9. Customer
CREATE TABLE Customer (
    customer_id INT          PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    phone       VARCHAR(15),
    password    VARCHAR(255) NOT NULL,
    CONSTRAINT chk_password_length CHECK (CHAR_LENGTH(password) >= 6)
);

-- 10. Admin
CREATE TABLE Admin (
    admin_id INT         PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

-- 11. Staff
CREATE TABLE Staff (
    staff_id     INT         PRIMARY KEY AUTO_INCREMENT,
    name         VARCHAR(100) NOT NULL,
    role         VARCHAR(50),
    shift_timing VARCHAR(50)
);

-- 12. Show_Time
CREATE TABLE Show_Time (
    show_id       INT     PRIMARY KEY AUTO_INCREMENT,
    movie_id      INT     NOT NULL,
    auditorium_id INT     NOT NULL,
    show_date     DATE    NOT NULL,
    start_time    TIME    NOT NULL,
    end_time      TIME    NOT NULL,
    language      VARCHAR(50),
    FOREIGN KEY (movie_id)      REFERENCES Movie(movie_id),
    FOREIGN KEY (auditorium_id) REFERENCES Auditorium(auditorium_id)
);

-- 13. Ticket
CREATE TABLE Ticket (
    ticket_id      INT           PRIMARY KEY AUTO_INCREMENT,
    show_id        INT           NOT NULL,
    seat_id        INT           NOT NULL,
    price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    booking_status ENUM('available','booked','reserved') DEFAULT 'available',
    admin_id       INT,
    FOREIGN KEY (show_id)   REFERENCES Show_Time(show_id),
    FOREIGN KEY (seat_id)   REFERENCES Seat(seat_id),
    FOREIGN KEY (admin_id)  REFERENCES Admin(admin_id)
);

-- 14. Booking
CREATE TABLE Booking (
    booking_id     INT           PRIMARY KEY AUTO_INCREMENT,
    customer_id    INT           NOT NULL,
    booking_date   DATETIME      DEFAULT CURRENT_TIMESTAMP,
    total_amount   DECIMAL(10,2) CHECK (total_amount >= 0),
    payment_status ENUM('pending','paid','cancelled') DEFAULT 'pending',
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

-- 15. Booking_Detail
CREATE TABLE Booking_Detail (
    booking_detail_id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id        INT NOT NULL,
    ticket_id         INT NOT NULL UNIQUE,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id),
    FOREIGN KEY (ticket_id)  REFERENCES Ticket(ticket_id)
);

-- 16. Promotion
CREATE TABLE Promotion (
    promotion_id      INT           PRIMARY KEY AUTO_INCREMENT,
    name              VARCHAR(100),
    description       TEXT,
    discount_type     ENUM('percentage','fixed') NOT NULL,
    discount_value    DECIMAL(10,2) CHECK (discount_value >= 0),
    start_date        DATE,
    end_date          DATE,
    applicable_movies JSON
);

-- 17. Booking_Log  (audit trail)
CREATE TABLE Booking_Log (
    log_id     INT        PRIMARY KEY AUTO_INCREMENT,
    booking_id INT        NOT NULL,
    action     ENUM('Created','Updated','Cancelled') NOT NULL,
    log_time   TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    details    TEXT,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

-- 18. Payment
CREATE TABLE Payment (
    payment_id       INT         PRIMARY KEY AUTO_INCREMENT,
    booking_id       INT         NOT NULL,
    payment_method   VARCHAR(50),
    transaction_date TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

-- 19. Review
CREATE TABLE Review (
    review_id   INT          PRIMARY KEY AUTO_INCREMENT,
    customer_id INT          NOT NULL,
    movie_id    INT          NOT NULL,
    rating      DECIMAL(2,1) CHECK (rating BETWEEN 0 AND 5),
    comment     TEXT,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    FOREIGN KEY (movie_id)    REFERENCES Movie(movie_id)
);

-- 20. Screen
CREATE TABLE Screen (
    screen_id   INT         PRIMARY KEY AUTO_INCREMENT,
    screen_type VARCHAR(50),
    dimensions  VARCHAR(50)
);

-- ─────────────────────────────────────────────────
--  PART 2 : SAMPLE DATA (Indian Context – DML)
-- ─────────────────────────────────────────────────

-- Genre (5 rows)
INSERT INTO Genre (genre_name, description) VALUES
('Action',    'High-octane, adrenaline-packed movies'),
('Drama',     'Emotional and narrative-driven stories'),
('Masala',    'Blend of action, comedy, and drama'),
('Thriller',  'Suspense-filled storylines'),
('Comedy',    'Light-hearted and humorous content');

-- Movie (10 rows)
INSERT INTO Movie (title, release_date, director, producer, budget, duration, rating, genre_id) VALUES
('RRR',                '2022-03-25', 'S.S. Rajamouli',  'DVV Danayya',          5500000000.00, 182, 9.1, 1),
('KGF: Chapter 2',     '2022-04-14', 'Prashanth Neel',  'Vijay Kiragandur',     1000000000.00, 168, 8.9, 1),
('Dangal',             '2016-12-23', 'Nitesh Tiwari',   'Aamir Khan',            700000000.00, 161, 8.4, 2),
('Pushpa: The Rise',   '2021-12-17', 'Sukumar',         'Naveen Yerneni',        250000000.00, 179, 7.6, 3),
('Uri: The Surgical Strike','2019-01-11','Aditya Dhar', 'Ronnie Screwvala',      250000000.00, 138, 8.4, 4),
('Drishyam 2',         '2022-11-18', 'Abhishek Pathak', 'Bhushan Kumar',         600000000.00, 147, 8.0, 4),
('3 Idiots',           '2009-12-25', 'Rajkumar Hirani', 'Vidhu Vinod Chopra',    550000000.00, 170, 8.4, 5),
('Baahubali 2',        '2017-04-28', 'S.S. Rajamouli',  'Shobu Yarlagadda',     2500000000.00, 167, 8.2, 1),
('Andhadhun',          '2018-10-05', 'Sriram Raghavan', 'Matchbox Pictures',     180000000.00, 139, 8.3, 4),
('Chhichhore',         '2019-09-06', 'Nitesh Tiwari',   'Sajid Nadiadwala',      370000000.00, 143, 8.1, 5);

-- Actor (10 rows)
INSERT INTO Actor (name, dob) VALUES
('N.T. Rama Rao Jr.',  '1983-05-20'),
('Ram Charan',         '1985-03-27'),
('Yash',               '1986-01-08'),
('Aamir Khan',         '1965-03-14'),
('Allu Arjun',         '1982-04-08'),
('Vicky Kaushal',      '1988-05-16'),
('Ajay Devgn',         '1969-04-02'),
('Prabhas',            '1979-10-23'),
('Ayushmann Khurrana', '1984-09-14'),
('Sushant Singh Rajput','1986-01-21');

-- Movie_Actor (M-M)
INSERT INTO Movie_Actor (movie_id, actor_id, role) VALUES
(1,  1,  'Komaram Bheem'),
(1,  2,  'Alluri Sitarama Raju'),
(2,  3,  'Rocky Bhai'),
(3,  4,  'Mahavir Singh Phogat'),
(4,  5,  'Pushpa Raj'),
(5,  6,  'Major Vihaan Singh Shergill'),
(6,  7,  'Vijay Salgaonkar'),
(7,  4,  'Rancho'),
(8,  8,  'Amarendra Baahubali'),
(9,  9,  'Akash');

-- Seat_Layout (5 rows)
INSERT INTO Seat_Layout (name, description, total_rows, seats_per_row) VALUES
('Gold Class',   'Recliner seats with ample legroom',       5,  10),
('Standard',     'Regular comfortable seating',            15,  20),
('IMAX Premium', 'Extra-wide seats for IMAX screens',       8,  18),
('Platinum',     'VIP lounge seating with service',         3,   8),
('Balcony',      'Elevated rear-section seating',           4,  15);

-- Theatre (7 rows)
INSERT INTO Theatre (name, location) VALUES
('PVR Cinemas',        'Phoenix Marketcity, Mumbai'),
('Sathyam Cinemas',    'Royapettah, Chennai'),
('Prasads IMAX',       'Necklace Road, Hyderabad'),
('INOX Leisure',       'Forum Mall, Bengaluru'),
('Cinepolis India',    'Pacific Mall, Delhi'),
('AGS Cinemas',        'Velachery, Chennai'),
('Miraj Cinemas',      'Seawoods Grand Central, Navi Mumbai');

-- Auditorium (8 rows)
INSERT INTO Auditorium (theatre_id, hall_number, capacity, layout_id) VALUES
(1, 1, 50,  1),
(1, 2, 300, 2),
(2, 1, 250, 2),
(2, 2, 40,  4),
(3, 1, 300, 3),
(4, 1, 200, 2),
(5, 1, 180, 2),
(6, 1, 150, 5);

-- Seat (10 rows)
INSERT INTO Seat (auditorium_id, row_num, seat_number, layout_id) VALUES
(1, 1,  1, 1),
(1, 1,  2, 1),
(1, 2,  1, 1),
(2, 5, 10, 2),
(2, 5, 11, 2),
(3, 3,  5, 2),
(3, 3,  6, 2),
(4, 1,  1, 4),
(5, 4, 12, 3),
(6, 2,  8, 2);

-- Customer (10 rows)
INSERT INTO Customer (name, email, phone, password) VALUES
('Rajesh Kumar',    'rajesh.k@example.com',     '+919876543210', 'password123'),
('Priya Sharma',    'priya.s@example.com',       '+919988776655', 'securepass456'),
('Amit Patel',      'amit.patel@example.com',    '+919123456789', 'mypassword'),
('Divya Nair',      'divya.nair@example.com',    '+918765432109', 'divya@2025'),
('Suresh Menon',    'suresh.m@example.com',      '+917654321098', 'suresh#secure'),
('Ananya Iyer',     'ananya.iyer@example.com',   '+916543210987', 'ananya123'),
('Karthik Rajan',   'karthik.r@example.com',     '+915432109876', 'karthik@pass'),
('Meera Pillai',    'meera.p@example.com',        '+914321098765', 'meera@2025'),
('Vikram Singh',    'vikram.s@example.com',       '+913210987654', 'vikram#pass'),
('Sneha Reddy',     'sneha.reddy@example.com',   '+912109876543', 'sneha@secure');

-- Admin (5 rows)
INSERT INTO Admin (username, password) VALUES
('admin_main',     'Admin@123!'),
('manager_mum',    'Mumbai@2025'),
('manager_che',    'Chennai@2025'),
('manager_hyd',    'Hyderabad@2025'),
('superadmin',     'Super@Admin1');

-- Staff (10 rows)
INSERT INTO Staff (name, role, shift_timing) VALUES
('Suresh Reddy',     'Manager',              'Morning (6AM-2PM)'),
('Anjali Menon',     'Ticketing Executive',  'Evening (2PM-10PM)'),
('Ramesh Babu',      'Security',             'Night (10PM-6AM)'),
('Kavitha Devi',     'Usher',                'Morning (6AM-2PM)'),
('Prasad Kumar',     'Projectionist',        'Evening (2PM-10PM)'),
('Lalitha Rao',      'Cleaner',              'Morning (6AM-2PM)'),
('Dinesh Chandra',   'Concessions Staff',    'Evening (2PM-10PM)'),
('Pooja Tiwari',     'Ticketing Executive',  'Night (10PM-6AM)'),
('Arjun Nambiar',    'Manager',              'Evening (2PM-10PM)'),
('Sita Kumari',      'Usher',                'Night (10PM-6AM)');

-- Show_Time (10 rows)
INSERT INTO Show_Time (movie_id, auditorium_id, show_date, start_time, end_time, language) VALUES
(1, 1, '2025-10-25', '10:00:00', '13:05:00', 'Telugu'),
(1, 2, '2025-10-25', '18:00:00', '21:05:00', 'Telugu'),
(2, 3, '2025-10-25', '20:00:00', '22:48:00', 'Kannada'),
(3, 6, '2025-10-26', '09:00:00', '11:41:00', 'Hindi'),
(4, 5, '2025-10-26', '14:00:00', '16:59:00', 'Telugu'),
(5, 7, '2025-10-27', '11:00:00', '13:18:00', 'Hindi'),
(6, 4, '2025-10-27', '16:00:00', '18:27:00', 'Hindi'),
(7, 6, '2025-10-28', '10:00:00', '12:50:00', 'Hindi'),
(8, 5, '2025-10-28', '19:00:00', '21:47:00', 'Telugu'),
(9, 2, '2025-10-29', '15:00:00', '17:19:00', 'Hindi');

-- Ticket (10 rows)
INSERT INTO Ticket (show_id, seat_id, price, booking_status, admin_id) VALUES
(1,  1,  500.00, 'booked',     1),
(1,  2,  500.00, 'booked',     1),
(2,  4,  350.00, 'booked',     2),
(2,  5,  350.00, 'available',  NULL),
(3,  6,  250.00, 'booked',     3),
(4,  7,  200.00, 'reserved',   4),
(5,  8,  750.00, 'booked',     1),
(6,  3,  400.00, 'available',  NULL),
(7,  9,  600.00, 'booked',     2),
(8, 10,  300.00, 'reserved',   5);

-- Booking (10 rows)
INSERT INTO Booking (customer_id, booking_date, total_amount, payment_status) VALUES
(1,  '2025-10-20 10:30:00', 1000.00, 'paid'),
(2,  '2025-10-20 11:00:00',  350.00, 'paid'),
(3,  '2025-10-21 09:15:00',  250.00, 'paid'),
(4,  '2025-10-21 14:00:00',  750.00, 'paid'),
(5,  '2025-10-22 16:30:00',  600.00, 'paid'),
(6,  '2025-10-22 18:45:00',  400.00, 'pending'),
(7,  '2025-10-23 10:00:00',  300.00, 'pending'),
(8,  '2025-10-23 12:20:00',  500.00, 'cancelled'),
(9,  '2025-10-24 08:00:00',  200.00, 'paid'),
(10, '2025-10-24 20:00:00',  350.00, 'pending');

-- Booking_Detail (10 rows)
INSERT INTO Booking_Detail (booking_id, ticket_id) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 5),
(4, 7),
(5, 9),
(9, 4),
(10, 6);

-- Promotion (7 rows)
INSERT INTO Promotion (name, description, discount_type, discount_value, start_date, end_date, applicable_movies) VALUES
('Diwali Bonanza',      'Flat ₹100 off on all bookings',       'fixed',      100.00, '2025-10-20', '2025-10-30', '[1,2,3]'),
('Student Discount',    '15% off with valid student ID',       'percentage',  15.00, '2025-01-01', '2025-12-31', NULL),
('Weekend Special',     '10% off on Saturday & Sunday shows',  'percentage',  10.00, '2025-01-01', '2025-12-31', NULL),
('First Show Offer',    'Flat ₹50 off on morning first show',  'fixed',        50.00, '2025-10-01', '2025-12-31', '[4,5,6]'),
('Senior Citizen',      '20% discount for age 60+',            'percentage',  20.00, '2025-01-01', '2025-12-31', NULL),
('Opening Day Blast',   'Flat ₹200 off on release day',        'fixed',       200.00, '2025-10-25', '2025-10-25', '[1,2]'),
('Loyalty Reward',      '5% cashback for repeat customers',    'percentage',   5.00, '2025-01-01', '2025-12-31', NULL);

-- Booking_Log (initial rows – more will be added by triggers)
INSERT INTO Booking_Log (booking_id, action, log_time, details) VALUES
(1, 'Created',   '2025-10-20 10:30:05', 'Booking confirmed for 2 tickets'),
(2, 'Created',   '2025-10-20 11:00:10', 'Booking confirmed for 1 ticket'),
(3, 'Created',   '2025-10-21 09:15:15', 'Booking confirmed for 1 ticket'),
(4, 'Created',   '2025-10-21 14:00:20', 'Booking confirmed for 1 ticket'),
(5, 'Created',   '2025-10-22 16:30:25', 'Booking confirmed for 1 ticket'),
(8, 'Cancelled', '2025-10-23 13:00:00', 'Customer requested cancellation');

-- Payment (8 rows)
INSERT INTO Payment (booking_id, payment_method, transaction_date) VALUES
(1,  'UPI (GooglePay)',  '2025-10-20 10:31:00'),
(2,  'Credit Card',     '2025-10-20 11:01:00'),
(3,  'UPI (PhonePe)',   '2025-10-21 09:16:00'),
(4,  'Debit Card',      '2025-10-21 14:01:00'),
(5,  'Net Banking',     '2025-10-22 16:31:00'),
(9,  'UPI (Paytm)',     '2025-10-24 08:01:00');

-- Review (8 rows)
INSERT INTO Review (customer_id, movie_id, rating, comment) VALUES
(1, 1, 5.0, 'Mind-blowing visuals and action – RRR is a masterpiece!'),
(2, 3, 4.5, 'Very inspiring and emotional story. Aamir Khan was brilliant.'),
(3, 2, 4.0, 'KGF Chapter 2 is a visual extravaganza. Yash was superb.'),
(4, 4, 4.5, 'Allu Arjun owned every frame. Pushpa is iconic!'),
(5, 5, 5.0, 'Uri is the best war film India has produced. How''s the josh!'),
(6, 6, 4.0, 'Drishyam 2 kept me on the edge of my seat. Brilliant writing.'),
(7, 7, 5.0, '3 Idiots is timeless. Never gets old!'),
(8, 8, 4.5, 'Baahubali 2 is a cinematic spectacle. S.S. Rajamouli is a genius.');

-- Screen (5 rows)
INSERT INTO Screen (screen_type, dimensions) VALUES
('IMAX 70mm',  '72ft x 53ft'),
('4DX',        '50ft x 30ft'),
('Standard',   '40ft x 20ft'),
('Dolby Atmos','55ft x 35ft'),
('MX4D',       '48ft x 28ft');

-- ─────────────────────────────────────────────────
--  PART 3 : VIEWS
-- ─────────────────────────────────────────────────

-- View 1 : Upcoming active showtimes
CREATE OR REPLACE VIEW Active_Showtimes AS
SELECT
    m.title        AS Movie,
    th.name        AS Theatre,
    th.location    AS Location,
    s.show_date,
    s.start_time,
    s.end_time,
    s.language
FROM Show_Time s
JOIN Movie      m  ON s.movie_id      = m.movie_id
JOIN Auditorium a  ON s.auditorium_id = a.auditorium_id
JOIN Theatre    th ON a.theatre_id    = th.theatre_id
WHERE s.show_date >= CURDATE()
ORDER BY s.show_date, s.start_time;

-- View 2 : Per-customer spend summary
CREATE OR REPLACE VIEW Customer_Spend_Summary AS
SELECT
    c.customer_id,
    c.name,
    c.email,
    COUNT(b.booking_id)  AS Total_Bookings,
    COALESCE(SUM(b.total_amount), 0) AS Total_Spent_INR
FROM Customer c
LEFT JOIN Booking b ON c.customer_id = b.customer_id
                    AND b.payment_status = 'paid'
GROUP BY c.customer_id, c.name, c.email;

-- View 3 : Auditorium capacity summary per theatre
CREATE OR REPLACE VIEW Auditorium_Capacities AS
SELECT
    t.name       AS Theatre,
    t.location,
    a.hall_number,
    a.capacity,
    sl.name      AS Layout_Type
FROM Auditorium a
JOIN Theatre     t  ON a.theatre_id = t.theatre_id
JOIN Seat_Layout sl ON a.layout_id  = sl.layout_id;

-- View 4 : Movie rating and cast overview
CREATE OR REPLACE VIEW Movie_Cast_Overview AS
SELECT
    m.title,
    g.genre_name,
    m.director,
    m.rating,
    m.duration,
    GROUP_CONCAT(a.name ORDER BY a.name SEPARATOR ', ') AS Cast_Members
FROM Movie       m
JOIN Genre       g  ON m.genre_id  = g.genre_id
LEFT JOIN Movie_Actor ma ON m.movie_id = ma.movie_id
LEFT JOIN Actor  a  ON ma.actor_id = a.actor_id
GROUP BY m.movie_id, m.title, g.genre_name, m.director, m.rating, m.duration;

-- View 5 : Available tickets for all upcoming shows
CREATE OR REPLACE VIEW Available_Tickets AS
SELECT
    t.ticket_id,
    m.title         AS Movie,
    th.name         AS Theatre,
    s.show_date,
    s.start_time,
    s.language,
    seat.row_num,
    seat.seat_number,
    t.price
FROM Ticket     t
JOIN Show_Time  s    ON t.show_id       = s.show_id
JOIN Movie      m    ON s.movie_id      = m.movie_id
JOIN Seat       seat ON t.seat_id       = seat.seat_id
JOIN Auditorium a    ON s.auditorium_id = a.auditorium_id
JOIN Theatre    th   ON a.theatre_id    = th.theatre_id
WHERE t.booking_status = 'available'
  AND s.show_date      >= CURDATE();

-- ─────────────────────────────────────────────────
--  PART 4 : TRIGGERS
-- ─────────────────────────────────────────────────

DELIMITER //

-- Trigger 1 : Auto-log every new booking in Booking_Log
CREATE TRIGGER trg_after_booking_insert
AFTER INSERT ON Booking
FOR EACH ROW
BEGIN
    INSERT INTO Booking_Log (booking_id, action, details)
    VALUES (
        NEW.booking_id,
        'Created',
        CONCAT('Booking initialised. Amount: ₹', NEW.total_amount,
               ' | Status: ', NEW.payment_status)
    );
END //

-- Trigger 2 : Prevent negative ticket price; auto-correct to 0
CREATE TRIGGER trg_before_ticket_insert
BEFORE INSERT ON Ticket
FOR EACH ROW
BEGIN
    IF NEW.price < 0 THEN
        SET NEW.price = 0.00;
    END IF;
END //

-- Trigger 3 : Log every booking cancellation in Booking_Log
CREATE TRIGGER trg_after_booking_cancel
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    IF NEW.payment_status = 'cancelled' AND OLD.payment_status != 'cancelled' THEN
        INSERT INTO Booking_Log (booking_id, action, details)
        VALUES (
            NEW.booking_id,
            'Cancelled',
            CONCAT('Booking cancelled. Original amount: ₹', OLD.total_amount)
        );
    END IF;
END //

-- Trigger 4 : Auto-update ticket status when booking is cancelled
CREATE TRIGGER trg_release_tickets_on_cancel
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    IF NEW.payment_status = 'cancelled' AND OLD.payment_status != 'cancelled' THEN
        UPDATE Ticket t
        JOIN Booking_Detail bd ON t.ticket_id = bd.ticket_id
        SET t.booking_status = 'available'
        WHERE bd.booking_id = NEW.booking_id;
    END IF;
END //

-- Trigger 5 : Log price updates on Ticket table
CREATE TRIGGER trg_after_ticket_price_update
AFTER UPDATE ON Ticket
FOR EACH ROW
BEGIN
    IF NEW.price <> OLD.price THEN
        INSERT INTO Booking_Log (booking_id, action, details)
        SELECT bd.booking_id,
               'Updated',
               CONCAT('Ticket #', NEW.ticket_id, ' price changed from ₹',
                      OLD.price, ' to ₹', NEW.price)
        FROM Booking_Detail bd
        WHERE bd.ticket_id = NEW.ticket_id
        LIMIT 1;
    END IF;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────
--  PART 5 : STORED PROCEDURES WITH CURSORS
-- ─────────────────────────────────────────────────

DELIMITER //

-- Procedure 1 : Apply 10% loyalty discount to pending bookings > ₹500
CREATE PROCEDURE ApplyLoyaltyDiscount()
BEGIN
    DECLARE done      INT DEFAULT FALSE;
    DECLARE b_id      INT;
    DECLARE cur1 CURSOR FOR
        SELECT booking_id FROM Booking
        WHERE total_amount > 500 AND payment_status = 'pending';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur1;
    read_loop: LOOP
        FETCH cur1 INTO b_id;
        IF done THEN LEAVE read_loop; END IF;
        UPDATE Booking SET total_amount = total_amount * 0.90
        WHERE booking_id = b_id;
    END LOOP;
    CLOSE cur1;
END //

-- Procedure 2 : Calculate total revenue from paid bookings
CREATE PROCEDURE CalculateTotalRevenue()
BEGIN
    DECLARE done           INT DEFAULT FALSE;
    DECLARE current_amount DECIMAL(10,2);
    DECLARE running_total  DECIMAL(10,2) DEFAULT 0.00;
    DECLARE cur2 CURSOR FOR
        SELECT total_amount FROM Booking WHERE payment_status = 'paid';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur2;
    revenue_loop: LOOP
        FETCH cur2 INTO current_amount;
        IF done THEN LEAVE revenue_loop; END IF;
        SET running_total = running_total + current_amount;
    END LOOP;
    CLOSE cur2;
    SET @total_revenue = running_total;
    SELECT @total_revenue AS Total_Revenue_INR;
END //

-- Procedure 3 : Release expired reserved tickets for a given show
CREATE PROCEDURE ReleaseReservedTickets(IN target_show_id INT)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE t_id INT;
    DECLARE cur3 CURSOR FOR
        SELECT ticket_id FROM Ticket
        WHERE show_id = target_show_id AND booking_status = 'reserved';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur3;
    release_loop: LOOP
        FETCH cur3 INTO t_id;
        IF done THEN LEAVE release_loop; END IF;
        UPDATE Ticket SET booking_status = 'available'
        WHERE ticket_id = t_id;
    END LOOP;
    CLOSE cur3;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────
--  PART 6 : COMPLEX QUERIES
-- ─────────────────────────────────────────────────

-- ── Constraint Tests ────────────────────────────

-- Q1: Budget & duration constraint test
ALTER TABLE Movie
ADD CONSTRAINT chk_movie_validity CHECK (budget >= 0 AND duration > 0);

-- Q2: Duplicate email test
ALTER TABLE Customer ADD CONSTRAINT unique_email UNIQUE (email);

-- Q3: Default payment_status test
ALTER TABLE Booking ALTER COLUMN payment_status SET DEFAULT 'pending';

-- ── Aggregate Functions ──────────────────────────

-- A1: Total revenue from paid bookings
SELECT SUM(total_amount) AS Total_Revenue_INR
FROM Booking WHERE payment_status = 'paid';

-- A2: Average ticket price
SELECT ROUND(AVG(price), 2) AS Average_Ticket_Price_INR
FROM Ticket;

-- A3: Ticket count by booking status
SELECT booking_status, COUNT(ticket_id) AS Total_Tickets
FROM Ticket GROUP BY booking_status;

-- A4: Top 3 movies by rating
SELECT title, director, rating
FROM Movie ORDER BY rating DESC LIMIT 3;

-- A5: Revenue per payment method
SELECT payment_method, COUNT(*) AS Transactions,
       SUM(b.total_amount) AS Revenue_INR
FROM Payment p
JOIN Booking b ON p.booking_id = b.booking_id
WHERE b.payment_status = 'paid'
GROUP BY payment_method ORDER BY Revenue_INR DESC;

-- ── Set Operations ───────────────────────────────

-- S1 (UNION): All persons associated with cinema (customers + staff)
SELECT name, 'Customer' AS Type FROM Customer
UNION
SELECT name, 'Staff'    AS Type FROM Staff;

-- S2 (UNION ALL): Raw ID list for actors and staff
SELECT actor_id AS Internal_ID, 'Actor' AS Type FROM Actor
UNION ALL
SELECT staff_id AS Internal_ID, 'Staff' AS Type FROM Staff;

-- S3 (NOT IN): Customers who have never booked
SELECT name, email FROM Customer
WHERE customer_id NOT IN (SELECT customer_id FROM Booking);

-- ── Subqueries ───────────────────────────────────

-- SQ1: Customers who spent more than the average booking amount
SELECT name, email FROM Customer
WHERE customer_id IN (
    SELECT customer_id FROM Booking
    WHERE total_amount > (SELECT AVG(total_amount) FROM Booking)
);

-- SQ2: Movie with highest IMDB rating
SELECT title, director, rating FROM Movie
WHERE rating = (SELECT MAX(rating) FROM Movie);

-- SQ3: Theatres with large auditoriums (capacity > 200)
SELECT name, location FROM Theatre
WHERE theatre_id IN (
    SELECT theatre_id FROM Auditorium WHERE capacity > 200
);

-- SQ4: Movies never scheduled for any show
SELECT title FROM Movie
WHERE movie_id NOT IN (SELECT movie_id FROM Show_Time);

-- ── JOIN Queries ─────────────────────────────────

-- J1 (INNER JOIN): Comprehensive booking report
SELECT
    b.booking_id,
    MAX(c.name)   AS Customer_Name,
    MAX(m.title)  AS Movie_Title,
    MAX(th.name)  AS Theatre,
    b.total_amount,
    b.payment_status
FROM Booking        b
JOIN Customer       c  ON b.customer_id    = c.customer_id
JOIN Booking_Detail bd ON b.booking_id     = bd.booking_id
JOIN Ticket         t  ON bd.ticket_id     = t.ticket_id
JOIN Show_Time      st ON t.show_id        = st.show_id
JOIN Movie          m  ON st.movie_id      = m.movie_id
JOIN Auditorium     a  ON st.auditorium_id = a.auditorium_id
JOIN Theatre        th ON a.theatre_id     = th.theatre_id
WHERE b.payment_status = 'paid'
GROUP BY b.booking_id, b.total_amount, b.payment_status;

-- J2 (LEFT JOIN): All movies with their show schedules (including unscheduled)
SELECT m.title, s.show_date, s.start_time, s.language
FROM Movie m
LEFT JOIN Show_Time s ON m.movie_id = s.movie_id;

-- J3 (THREE-TABLE): Actor, role, and movie title
SELECT a.name AS Actor, ma.role AS Character, m.title AS Movie
FROM Actor a
JOIN Movie_Actor ma ON a.actor_id  = ma.actor_id
JOIN Movie       m  ON ma.movie_id = m.movie_id
ORDER BY m.title;

-- J4: Full seat detail with auditorium and theatre
SELECT
    t.name       AS Theatre,
    a.hall_number,
    sl.name      AS Layout,
    s.row_num,
    s.seat_number
FROM Seat        s
JOIN Auditorium  a  ON s.auditorium_id = a.auditorium_id
JOIN Theatre     t  ON a.theatre_id    = t.theatre_id
JOIN Seat_Layout sl ON s.layout_id     = sl.layout_id
ORDER BY t.name, a.hall_number, s.row_num, s.seat_number;

-- J5: Customer booking + payment method
SELECT
    c.name          AS Customer,
    b.booking_id,
    b.total_amount,
    b.payment_status,
    p.payment_method,
    p.transaction_date
FROM Customer c
JOIN Booking  b ON c.customer_id = b.customer_id
LEFT JOIN Payment p ON b.booking_id = p.booking_id
ORDER BY b.booking_date DESC;

-- ── Views Usage ──────────────────────────────────

SELECT * FROM Active_Showtimes;
SELECT * FROM Customer_Spend_Summary ORDER BY Total_Spent_INR DESC;
SELECT * FROM Auditorium_Capacities;
SELECT * FROM Movie_Cast_Overview;
SELECT * FROM Available_Tickets;

-- ── Procedure Calls ──────────────────────────────

CALL ApplyLoyaltyDiscount();
CALL CalculateTotalRevenue();
CALL ReleaseReservedTickets(1);

-- ─────────────────────────────────────────────────
--  END OF SCRIPT
-- ─────────────────────────────────────────────────

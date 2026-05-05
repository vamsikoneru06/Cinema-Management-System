-- ============================================================
--  CINEMA MANAGEMENT SYSTEM – Complete SQL Script (Enhanced)
--  Course : 21CSC205P Database Management Systems
--  Authors : K Mohan Vamsi [RA2411030010013]
--             A Teja Rayal  [RA2411030010022]
--  Guide   : Dr. Saranya G
--  Enhancements : Transactions, Concurrency Control,
--                 Normalisation (3NF), Real-time Revenue Log
-- ============================================================

DROP DATABASE IF EXISTS CinemaManagement;
CREATE DATABASE CinemaManagement
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE CinemaManagement;

SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────
--  PART 1 : TABLE SCHEMA (DDL)
-- ─────────────────────────────────────────────────

-- ── 3NF Normalisation : City (extracts city from Theatre.location) ──
-- Before normalisation Theatre.location stored "Area, City" as one string.
-- Separating it removes partial dependencies and eliminates update anomalies.
CREATE TABLE City (
    city_id    INT          PRIMARY KEY AUTO_INCREMENT,
    city_name  VARCHAR(100) NOT NULL UNIQUE,
    state      VARCHAR(100) NOT NULL
);

-- ── 3NF Normalisation : Seat_Category (extracts pricing from Ticket) ──
-- Before normalisation each Ticket row stored an ad-hoc price.
-- Storing base_price per category removes price duplication
-- and lets a single UPDATE propagate across all tickets.
CREATE TABLE Seat_Category (
    category_id  INT           PRIMARY KEY AUTO_INCREMENT,
    name         VARCHAR(50)   NOT NULL UNIQUE,   -- Silver / Gold / Platinum / IMAX
    base_price   DECIMAL(10,2) NOT NULL CHECK (base_price >= 0),
    description  TEXT
);

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
    FOREIGN KEY (genre_id) REFERENCES Genre(genre_id),
    CONSTRAINT chk_movie_validity CHECK (budget >= 0 AND duration > 0)
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
    layout_id     INT         PRIMARY KEY AUTO_INCREMENT,
    name          VARCHAR(50) NOT NULL,
    description   TEXT,
    total_rows    INT         NOT NULL CHECK (total_rows > 0),
    seats_per_row INT         NOT NULL CHECK (seats_per_row > 0),
    created_at    TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- 6. Theatre  (now references City instead of embedding city in location)
CREATE TABLE Theatre (
    theatre_id INT          PRIMARY KEY AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    location   VARCHAR(200) NOT NULL,   -- landmark / area (city is now via FK)
    city_id    INT          NOT NULL,
    FOREIGN KEY (city_id) REFERENCES City(city_id)
);

-- 7. Auditorium
CREATE TABLE Auditorium (
    auditorium_id INT PRIMARY KEY AUTO_INCREMENT,
    theatre_id    INT NOT NULL,
    hall_number   INT NOT NULL,
    capacity      INT NOT NULL CHECK (capacity > 0),
    layout_id     INT,
    FOREIGN KEY (theatre_id) REFERENCES Theatre(theatre_id) ON DELETE CASCADE,
    FOREIGN KEY (layout_id)  REFERENCES Seat_Layout(layout_id)
);

-- 8. Seat  (now carries category_id for pricing normalisation)
CREATE TABLE Seat (
    seat_id       INT PRIMARY KEY AUTO_INCREMENT,
    auditorium_id INT NOT NULL,
    row_num       INT NOT NULL CHECK (row_num > 0),
    seat_number   INT NOT NULL CHECK (seat_number > 0),
    layout_id     INT,
    category_id   INT,
    FOREIGN KEY (auditorium_id) REFERENCES Auditorium(auditorium_id) ON DELETE CASCADE,
    FOREIGN KEY (layout_id)     REFERENCES Seat_Layout(layout_id),
    FOREIGN KEY (category_id)   REFERENCES Seat_Category(category_id)
);

-- 9. Customer  (added created_at for audit trail)
CREATE TABLE Customer (
    customer_id INT          PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE,
    phone       VARCHAR(15),
    password    VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_password_length CHECK (CHAR_LENGTH(password) >= 6),
    CONSTRAINT unique_email UNIQUE (email)
);

-- 10. Admin
CREATE TABLE Admin (
    admin_id INT         PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

-- 11. Staff
CREATE TABLE Staff (
    staff_id     INT          PRIMARY KEY AUTO_INCREMENT,
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
--   version column supports optimistic concurrency control:
--   UPDATE Ticket SET booking_status='booked', version=version+1
--   WHERE ticket_id=? AND version=? AND booking_status='available'
--   Rows affected = 0 means another session already grabbed the seat.
CREATE TABLE Ticket (
    ticket_id      INT           PRIMARY KEY AUTO_INCREMENT,
    show_id        INT           NOT NULL,
    seat_id        INT           NOT NULL,
    price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    booking_status ENUM('available','booked','reserved') DEFAULT 'available',
    admin_id       INT,
    version        INT           NOT NULL DEFAULT 0,
    FOREIGN KEY (show_id)  REFERENCES Show_Time(show_id),
    FOREIGN KEY (seat_id)  REFERENCES Seat(seat_id),
    FOREIGN KEY (admin_id) REFERENCES Admin(admin_id)
);

-- 14. Booking
--   version column enables optimistic locking for concurrent updates.
CREATE TABLE Booking (
    booking_id     INT           PRIMARY KEY AUTO_INCREMENT,
    customer_id    INT           NOT NULL,
    booking_date   DATETIME      DEFAULT CURRENT_TIMESTAMP,
    total_amount   DECIMAL(10,2) CHECK (total_amount >= 0),
    payment_status ENUM('pending','paid','cancelled') DEFAULT 'pending',
    version        INT           NOT NULL DEFAULT 0,
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
    promotion_id   INT           PRIMARY KEY AUTO_INCREMENT,
    name           VARCHAR(100),
    description    TEXT,
    discount_type  ENUM('percentage','fixed') NOT NULL,
    discount_value DECIMAL(10,2) CHECK (discount_value >= 0),
    start_date     DATE,
    end_date       DATE,
    applicable_movies JSON
);

-- 17. Booking_Log  (audit trail)
CREATE TABLE Booking_Log (
    log_id     INT       PRIMARY KEY AUTO_INCREMENT,
    booking_id INT       NOT NULL,
    action     ENUM('Created','Updated','Cancelled') NOT NULL,
    log_time   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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

-- 19. Review  (added created_at)
CREATE TABLE Review (
    review_id   INT          PRIMARY KEY AUTO_INCREMENT,
    customer_id INT          NOT NULL,
    movie_id    INT          NOT NULL,
    rating      DECIMAL(2,1) CHECK (rating BETWEEN 0 AND 5),
    comment     TEXT,
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    FOREIGN KEY (movie_id)    REFERENCES Movie(movie_id)
);

-- 20. Screen
CREATE TABLE Screen (
    screen_id   INT         PRIMARY KEY AUTO_INCREMENT,
    screen_type VARCHAR(50),
    dimensions  VARCHAR(50)
);

-- ── Revenue_Log : Real-time revenue tracking ──────────────────
-- Every paid booking or cancellation is logged here.
-- The API reads MAX(log_id) to stream live revenue changes to the dashboard.
CREATE TABLE Revenue_Log (
    log_id        INT            PRIMARY KEY AUTO_INCREMENT,
    booking_id    INT            NOT NULL,
    amount        DECIMAL(10,2)  NOT NULL,
    action        ENUM('credit','debit') NOT NULL,
    running_total DECIMAL(15,2)  NOT NULL DEFAULT 0,
    logged_at     TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id)
);

SET FOREIGN_KEY_CHECKS = 1;

-- ─────────────────────────────────────────────────
--  PART 2 : SAMPLE DATA (Indian Context – DML)
-- ─────────────────────────────────────────────────

-- City (10 rows)
INSERT INTO City (city_name, state) VALUES
('Mumbai',      'Maharashtra'),
('Chennai',     'Tamil Nadu'),
('Hyderabad',   'Telangana'),
('Bengaluru',   'Karnataka'),
('Delhi',       'Delhi'),
('Kolkata',     'West Bengal'),
('Pune',        'Maharashtra'),
('Ahmedabad',   'Gujarat'),
('Jaipur',      'Rajasthan'),
('Kochi',       'Kerala');

-- Seat_Category (4 categories with base prices)
INSERT INTO Seat_Category (name, base_price, description) VALUES
('Silver',   180.00, 'Standard seating with good screen view'),
('Gold',     320.00, 'Premium seating with extra legroom'),
('Platinum', 550.00, 'Recliner seats with F&B service'),
('IMAX',     480.00, 'Extra-wide IMAX auditorium seats');

-- Genre (11 rows)
INSERT INTO Genre (genre_name, description) VALUES
('Action',    'High-octane, adrenaline-packed movies'),
('Drama',     'Emotional and narrative-driven stories'),
('Masala',    'Blend of action, comedy, and drama'),
('Thriller',  'Suspense-filled storylines'),
('Comedy',    'Light-hearted and humorous content'),
('Biography', 'True stories of extraordinary lives'),
('Romance',   'Love stories and relationships'),
('Horror',    'Fear-inducing supernatural and psychological tales'),
('Sports',    'Inspiring stories from the world of sports'),
('Crime',     'Gripping crime investigation narratives'),
('Historical','Epic tales rooted in Indian history');

-- Movie (25 rows)
INSERT INTO Movie (title, release_date, director, producer, budget, duration, rating, genre_id) VALUES
('RRR',                        '2022-03-25', 'S.S. Rajamouli',    'DVV Danayya',           5500000000.00, 182, 9.1,  1),
('KGF: Chapter 2',             '2022-04-14', 'Prashanth Neel',    'Vijay Kiragandur',      1000000000.00, 168, 8.9,  1),
('Dangal',                     '2016-12-23', 'Nitesh Tiwari',     'Aamir Khan',             700000000.00, 161, 8.4,  6),
('Pushpa: The Rise',           '2021-12-17', 'Sukumar',           'Naveen Yerneni',         250000000.00, 179, 7.6,  3),
('Uri: The Surgical Strike',   '2019-01-11', 'Aditya Dhar',       'Ronnie Screwvala',       250000000.00, 138, 8.4,  1),
('Drishyam 2',                 '2022-11-18', 'Abhishek Pathak',   'Bhushan Kumar',          600000000.00, 147, 8.0,  4),
('3 Idiots',                   '2009-12-25', 'Rajkumar Hirani',   'Vidhu Vinod Chopra',     550000000.00, 170, 8.4,  5),
('Baahubali 2',                '2017-04-28', 'S.S. Rajamouli',    'Shobu Yarlagadda',      2500000000.00, 167, 8.2,  11),
('Andhadhun',                  '2018-10-05', 'Sriram Raghavan',   'Matchbox Pictures',      180000000.00, 139, 8.3,  4),
('Chhichhore',                 '2019-09-06', 'Nitesh Tiwari',     'Sajid Nadiadwala',       370000000.00, 143, 8.1,  5),
('Tumbbad',                    '2018-10-12', 'Rahi Anil Barve',   'Aanand L. Rai',          150000000.00, 104, 8.0,  8),
('Gangs of Wasseypur',         '2012-06-22', 'Anurag Kashyap',    'Guneet Monga',           300000000.00, 161, 8.2, 10),
('Lagaan',                     '2001-06-15', 'Ashutosh Gowariker','Aamir Khan',             250000000.00, 224, 8.1,  9),
('Pink',                       '2016-09-16', 'Aniruddha Roy Chowdhury','Rashmi Sharma',     200000000.00, 136, 8.0,  2),
('Taare Zameen Par',           '2007-12-21', 'Aamir Khan',        'Aamir Khan',             180000000.00, 165, 8.5,  2),
('Queen',                      '2014-03-07', 'Vikas Bahl',        'Viacom 18 Motion Pics',  100000000.00, 146, 8.1,  2),
('Bajrangi Bhaijaan',          '2015-07-17', 'Kabir Khan',        'Aditya Chopra',          900000000.00, 163, 8.0,  3),
('PK',                         '2014-12-19', 'Rajkumar Hirani',   'Vidhu Vinod Chopra',     850000000.00, 153, 8.2,  5),
('Gully Boy',                  '2019-02-14', 'Zoya Akhtar',       'Ritesh Sidhwani',        500000000.00, 154, 7.9,  2),
('Dil Dhadakne Do',            '2015-06-05', 'Zoya Akhtar',       'Ritesh Sidhwani',        600000000.00, 170, 7.7,  7),
('Kahaani',                    '2012-03-09', 'Sujoy Ghosh',       'Sujoy Ghosh',            120000000.00, 122, 8.1,  4),
('Ek Tha Tiger',               '2012-08-15', 'Kabir Khan',        'Aditya Chopra',          400000000.00, 132, 7.0,  1),
('Raazi',                      '2018-05-11', 'Meghna Gulzar',     'Karan Johar',            350000000.00, 138, 7.8,  4),
('Super 30',                   '2019-07-12', 'Vikas Bahl',        'Sajid Nadiadwala',       400000000.00, 155, 7.4,  6),
('Jab We Met',                 '2007-10-26', 'Imtiaz Ali',        'Dhilin Mehta',           180000000.00, 138, 7.9,  7);

-- Actor (20 rows)
INSERT INTO Actor (name, dob) VALUES
('N.T. Rama Rao Jr.',      '1983-05-20'),
('Ram Charan',              '1985-03-27'),
('Yash',                    '1986-01-08'),
('Aamir Khan',              '1965-03-14'),
('Allu Arjun',              '1982-04-08'),
('Vicky Kaushal',           '1988-05-16'),
('Ajay Devgn',              '1969-04-02'),
('Prabhas',                 '1979-10-23'),
('Ayushmann Khurrana',      '1984-09-14'),
('Sushant Singh Rajput',    '1986-01-21'),
('Ranveer Singh',           '1985-07-06'),
('Alia Bhatt',              '1993-03-15'),
('Deepika Padukone',        '1986-01-05'),
('Taapsee Pannu',           '1987-08-01'),
('Vidya Balan',             '1978-01-01'),
('Kangana Ranaut',          '1987-03-23'),
('Nawazuddin Siddiqui',     '1974-05-19'),
('Irrfan Khan',             '1967-01-07'),
('Shraddha Kapoor',         '1989-03-03'),
('Kareena Kapoor',          '1980-09-21');

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
(9,  9,  'Akash'),
(12, 17, 'Shahid Khan'),
(13, 4,  'Bhuvan'),
(15, 4,  'Ram Shankar Nikumbh'),
(17, 11, 'Bajrangi'),
(18, 4,  'PK'),
(19, 11, 'Murad'),
(19, 12, 'Safeena'),
(21, 15, 'Vidya Bagchi'),
(22, 12, 'Zoya/Sejal'),
(23, 12, 'Sehmat Khan'),
(25, 20, 'Geet');

-- Seat_Layout (5 rows)
INSERT INTO Seat_Layout (name, description, total_rows, seats_per_row) VALUES
('Gold Class',   'Recliner seats with ample legroom',       5,  10),
('Standard',     'Regular comfortable seating',            15,  20),
('IMAX Premium', 'Extra-wide seats for IMAX screens',       8,  18),
('Platinum VIP', 'VIP lounge seating with table service',   3,   8),
('Balcony',      'Elevated rear-section seating',           4,  15);

-- Theatre (12 rows, now with city_id FK)
INSERT INTO Theatre (name, location, city_id) VALUES
('PVR Cinemas',         'Phoenix Marketcity, Kurla',       1),
('Cinepolis',           'Viviana Mall, Thane',             1),
('Sathyam Cinemas',     'Royapettah High Road',            2),
('AGS Cinemas',         'Velachery Main Road',             2),
('Prasads IMAX',        'Necklace Road, Khairtabad',       3),
('Asian Cinemas',       'Kukatpally Housing Board',        3),
('INOX Leisure',        'Forum Mall, Koramangala',         4),
('PVR VR Chennai',      'VR Mall, Porur',                  2),
('Cinepolis Delhi',     'Pacific Mall, Tagore Garden',     5),
('Miraj Cinemas',       'Seawoods Grand Central, Nerul',   1),
('PVR Kolkata',         'South City Mall, Prince Anwar Shah',6),
('INOX Pune',           'Bund Garden Road',                7);

-- Auditorium (12 rows)
INSERT INTO Auditorium (theatre_id, hall_number, capacity, layout_id) VALUES
(1,  1,  50,  1),
(1,  2, 300,  2),
(2,  1, 200,  2),
(3,  1, 250,  2),
(3,  2,  40,  4),
(4,  1, 150,  5),
(5,  1, 300,  3),
(6,  1, 180,  2),
(7,  1, 200,  2),
(8,  1, 160,  2),
(9,  1, 220,  2),
(10, 1, 130,  5);

-- Seat (30 rows, with category_id for 3NF pricing)
INSERT INTO Seat (auditorium_id, row_num, seat_number, layout_id, category_id) VALUES
(1,  1,  1,  1, 3),
(1,  1,  2,  1, 3),
(1,  2,  1,  1, 2),
(2,  5, 10,  2, 1),
(2,  5, 11,  2, 1),
(2,  8, 15,  2, 2),
(3,  3,  5,  2, 1),
(3,  3,  6,  2, 1),
(4,  1,  1,  4, 3),
(5,  4, 12,  3, 4),
(6,  2,  8,  2, 1),
(7,  2,  3,  3, 4),
(7,  3,  7,  3, 4),
(8,  1,  5,  2, 1),
(8,  2,  9,  2, 2),
(9,  6,  4,  2, 1),
(9,  7,  2,  2, 2),
(10, 3, 11,  2, 1),
(10, 4,  6,  2, 1),
(11, 5,  8,  2, 2),
(11, 6,  3,  2, 2),
(12, 1,  2,  5, 1),
(2,  9,  1,  2, 2),
(2, 10,  2,  2, 2),
(3,  5, 14,  2, 2),
(4,  2,  3,  4, 3),
(5,  1,  1,  3, 4),
(6,  4, 10,  2, 2),
(8,  3, 12,  2, 1),
(9,  8,  5,  2, 1);

-- Customer (30 rows)
INSERT INTO Customer (name, email, phone, password) VALUES
('Rajesh Kumar',         'rajesh.k@example.com',         '+919876543210', 'password123'),
('Priya Sharma',         'priya.s@example.com',           '+919988776655', 'securepass456'),
('Amit Patel',           'amit.patel@example.com',        '+919123456789', 'mypassword'),
('Divya Nair',           'divya.nair@example.com',        '+918765432109', 'divya@2025'),
('Suresh Menon',         'suresh.m@example.com',          '+917654321098', 'suresh#secure'),
('Ananya Iyer',          'ananya.iyer@example.com',       '+916543210987', 'ananya123'),
('Karthik Rajan',        'karthik.r@example.com',         '+915432109876', 'karthik@pass'),
('Meera Pillai',         'meera.p@example.com',           '+914321098765', 'meera@2025'),
('Vikram Singh',         'vikram.s@example.com',          '+913210987654', 'vikram#pass'),
('Sneha Reddy',          'sneha.reddy@example.com',       '+912109876543', 'sneha@secure'),
('Arjun Malhotra',       'arjun.m@example.com',           '+919012345678', 'arjun@2025'),
('Kavitha Subramaniam',  'kavitha.sub@example.com',       '+918901234567', 'kavitha123'),
('Rohit Gupta',          'rohit.g@example.com',           '+917890123456', 'rohit@pass'),
('Pooja Verma',          'pooja.v@example.com',           '+916789012345', 'pooja#sec'),
('Harish Krishnan',      'harish.k@example.com',          '+915678901234', 'harish@cin'),
('Lakshmi Devi',         'lakshmi.d@example.com',         '+914567890123', 'lakshmi456'),
('Mohan Babu',           'mohan.b@example.com',           '+913456789012', 'mohan@pass'),
('Rashida Begum',        'rashida.b@example.com',         '+912345678901', 'rashida123'),
('Deepak Joshi',         'deepak.j@example.com',          '+911234567890', 'deepak@sec'),
('Shalini Rao',          'shalini.r@example.com',         '+919876501234', 'shalini#2025'),
('Vinod Pandey',         'vinod.p@example.com',           '+918765012345', 'vinod@pass'),
('Geetha Krishnamurthy', 'geetha.km@example.com',         '+917654023456', 'geetha123'),
('Sanjay Bhatt',         'sanjay.b@example.com',          '+916543034567', 'sanjay@cin'),
('Nidhi Agarwal',        'nidhi.a@example.com',           '+915432045678', 'nidhi#pass'),
('Prasanna Kumar',       'prasanna.k@example.com',        '+914321056789', 'prasanna@2025'),
('Tejaswini Patil',      'tejasw.p@example.com',          '+913210067890', 'tejasw@sec'),
('Balaji Venkatesh',     'balaji.v@example.com',          '+912109078901', 'balaji#pass'),
('Renu Chawla',          'renu.c@example.com',            '+911098089012', 'renu@2025'),
('Siddharth Naidu',      'sid.naidu@example.com',         '+919087090123', 'sid@secure'),
('Keerthi Reddy',        'keerthi.r@example.com',         '+918076101234', 'keerthi#cin');

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

-- Show_Time (20 rows)
INSERT INTO Show_Time (movie_id, auditorium_id, show_date, start_time, end_time, language) VALUES
(1,  1,  '2025-10-25', '10:00:00', '13:05:00', 'Telugu'),
(1,  2,  '2025-10-25', '18:00:00', '21:05:00', 'Telugu'),
(2,  3,  '2025-10-25', '20:00:00', '22:48:00', 'Kannada'),
(3,  9,  '2025-10-26', '09:00:00', '11:41:00', 'Hindi'),
(4,  8,  '2025-10-26', '14:00:00', '16:59:00', 'Telugu'),
(5, 10,  '2025-10-27', '11:00:00', '13:18:00', 'Hindi'),
(6,  5,  '2025-10-27', '16:00:00', '18:27:00', 'Hindi'),
(7,  9,  '2025-10-28', '10:00:00', '12:50:00', 'Hindi'),
(8,  8,  '2025-10-28', '19:00:00', '21:47:00', 'Telugu'),
(9,  2,  '2025-10-29', '15:00:00', '17:19:00', 'Hindi'),
(10, 3,  '2025-10-29', '11:00:00', '13:23:00', 'Hindi'),
(11, 4,  '2025-10-30', '20:00:00', '21:44:00', 'Hindi'),
(12, 6,  '2025-10-30', '14:00:00', '16:41:00', 'Hindi'),
(13, 7,  '2025-10-31', '09:00:00', '12:44:00', 'Hindi'),
(15, 9,  '2025-10-31', '15:00:00', '17:45:00', 'Hindi'),
(17, 11, '2025-11-01', '12:00:00', '14:43:00', 'Hindi'),
(18, 12, '2025-11-01', '18:00:00', '20:33:00', 'Hindi'),
(19, 2,  '2025-11-02', '16:00:00', '18:34:00', 'Hindi'),
(21, 4,  '2025-11-02', '19:00:00', '21:02:00', 'Hindi'),
(25, 10, '2025-11-03', '13:00:00', '15:18:00', 'Hindi');

-- Ticket (30 rows, prices derived from Seat_Category.base_price)
INSERT INTO Ticket (show_id, seat_id, price, booking_status, admin_id) VALUES
(1,   1,  550.00, 'booked',     1),
(1,   2,  550.00, 'booked',     1),
(1,   3,  320.00, 'available',  NULL),
(2,   4,  180.00, 'booked',     2),
(2,   5,  180.00, 'booked',     2),
(2,   6,  320.00, 'available',  NULL),
(3,   7,  180.00, 'booked',     3),
(3,   8,  180.00, 'available',  NULL),
(4,   9,  550.00, 'booked',     4),
(5,  10,  480.00, 'booked',     1),
(6,  11,  180.00, 'available',  NULL),
(7,  12,  480.00, 'booked',     2),
(7,  13,  480.00, 'booked',     2),
(8,  14,  180.00, 'available',  NULL),
(8,  15,  320.00, 'booked',     3),
(9,  16,  180.00, 'booked',     4),
(9,  17,  320.00, 'available',  NULL),
(10, 18,  180.00, 'booked',     1),
(10, 19,  180.00, 'booked',     1),
(11, 20,  320.00, 'available',  NULL),
(11, 21,  320.00, 'reserved',   2),
(12, 22,  180.00, 'booked',     3),
(13, 23,  320.00, 'booked',     4),
(13, 24,  320.00, 'booked',     4),
(14, 25,  320.00, 'booked',     1),
(15, 26,  550.00, 'available',  NULL),
(16, 27,  480.00, 'booked',     2),
(17, 28,  320.00, 'available',  NULL),
(18, 29,  180.00, 'booked',     3),
(19, 30,  180.00, 'booked',     4);

-- Booking (25 rows)
INSERT INTO Booking (customer_id, booking_date, total_amount, payment_status) VALUES
(1,  '2025-10-20 10:30:00', 1100.00, 'paid'),
(2,  '2025-10-20 11:00:00',  360.00, 'paid'),
(3,  '2025-10-21 09:15:00',  360.00, 'paid'),
(4,  '2025-10-21 14:00:00',  550.00, 'paid'),
(5,  '2025-10-22 10:00:00',  480.00, 'paid'),
(6,  '2025-10-22 16:30:00',  960.00, 'paid'),
(7,  '2025-10-22 18:45:00',  320.00, 'pending'),
(8,  '2025-10-23 10:00:00',  360.00, 'paid'),
(9,  '2025-10-23 12:20:00',  180.00, 'cancelled'),
(10, '2025-10-23 20:00:00',  360.00, 'paid'),
(11, '2025-10-24 08:00:00',  640.00, 'paid'),
(12, '2025-10-24 10:30:00',  550.00, 'paid'),
(13, '2025-10-24 14:00:00',  640.00, 'paid'),
(14, '2025-10-24 16:45:00',  320.00, 'paid'),
(15, '2025-10-25 09:00:00',  480.00, 'paid'),
(16, '2025-10-25 11:30:00',  180.00, 'paid'),
(17, '2025-10-25 15:00:00',  360.00, 'paid'),
(18, '2025-10-25 17:00:00',  180.00, 'cancelled'),
(19, '2025-10-26 08:30:00',  320.00, 'pending'),
(20, '2025-10-26 12:00:00',  960.00, 'paid'),
(21, '2025-10-26 14:30:00',  180.00, 'paid'),
(22, '2025-10-26 16:00:00',  320.00, 'paid'),
(23, '2025-10-27 09:00:00',  360.00, 'paid'),
(24, '2025-10-27 11:00:00',  180.00, 'paid'),
(25, '2025-10-27 14:00:00',  320.00, 'pending');

-- Booking_Detail
INSERT INTO Booking_Detail (booking_id, ticket_id) VALUES
(1,  1),
(1,  2),
(2,  4),
(3,  7),
(4,  9),
(5,  10),
(6,  12),
(6,  13),
(8,  16),
(10, 18),
(10, 19),
(11, 22),
(12, 23),
(12, 24),
(13, 25),
(14, 15),
(15, 27),
(16, 29),
(17, 30),
(20, 5),
(21, 3),
(22, 6),
(23, 8),
(24, 11);

-- Promotion (7 rows)
INSERT INTO Promotion (name, description, discount_type, discount_value, start_date, end_date, applicable_movies) VALUES
('Diwali Bonanza',      'Flat ₹100 off on all bookings',       'fixed',       100.00, '2025-10-20', '2025-10-30', '[1,2,3]'),
('Student Discount',    '15% off with valid student ID',       'percentage',   15.00, '2025-01-01', '2025-12-31', NULL),
('Weekend Special',     '10% off on Saturday & Sunday shows',  'percentage',   10.00, '2025-01-01', '2025-12-31', NULL),
('First Show Offer',    'Flat ₹50 off on morning first show',  'fixed',         50.00, '2025-10-01', '2025-12-31', '[4,5,6]'),
('Senior Citizen',      '20% discount for age 60+',            'percentage',   20.00, '2025-01-01', '2025-12-31', NULL),
('Opening Day Blast',   'Flat ₹200 off on release day',        'fixed',        200.00, '2025-10-25', '2025-10-25', '[1,2]'),
('Loyalty Reward',      '5% cashback for repeat customers',    'percentage',    5.00, '2025-01-01', '2025-12-31', NULL);

-- Booking_Log (seed rows; triggers will add more)
INSERT INTO Booking_Log (booking_id, action, log_time, details) VALUES
(1,  'Created',   '2025-10-20 10:30:05', 'Booking confirmed – 2 tickets'),
(2,  'Created',   '2025-10-20 11:00:10', 'Booking confirmed – 1 ticket'),
(3,  'Created',   '2025-10-21 09:15:15', 'Booking confirmed – 1 ticket'),
(4,  'Created',   '2025-10-21 14:00:20', 'Booking confirmed – 1 ticket'),
(5,  'Created',   '2025-10-22 10:00:25', 'Booking confirmed – 1 ticket'),
(6,  'Created',   '2025-10-22 16:30:30', 'Booking confirmed – 2 tickets'),
(9,  'Cancelled', '2025-10-23 13:00:00', 'Customer requested cancellation'),
(18, 'Cancelled', '2025-10-25 18:00:00', 'Customer requested cancellation');

-- Payment (20 rows)
INSERT INTO Payment (booking_id, payment_method, transaction_date) VALUES
(1,  'UPI (Google Pay)',  '2025-10-20 10:31:00'),
(2,  'Credit Card',      '2025-10-20 11:01:00'),
(3,  'UPI (PhonePe)',    '2025-10-21 09:16:00'),
(4,  'Debit Card',       '2025-10-21 14:01:00'),
(5,  'Net Banking',      '2025-10-22 10:01:00'),
(6,  'UPI (Google Pay)', '2025-10-22 16:31:00'),
(8,  'UPI (Paytm)',      '2025-10-23 10:01:00'),
(10, 'Credit Card',      '2025-10-23 20:01:00'),
(11, 'Debit Card',       '2025-10-24 08:01:00'),
(12, 'UPI (PhonePe)',    '2025-10-24 10:31:00'),
(13, 'Net Banking',      '2025-10-24 14:01:00'),
(14, 'UPI (Google Pay)', '2025-10-24 16:46:00'),
(15, 'Credit Card',      '2025-10-25 09:01:00'),
(16, 'UPI (Paytm)',      '2025-10-25 11:31:00'),
(17, 'Debit Card',       '2025-10-25 15:01:00'),
(20, 'UPI (Google Pay)', '2025-10-26 12:01:00'),
(21, 'Net Banking',      '2025-10-26 14:31:00'),
(22, 'Credit Card',      '2025-10-26 16:01:00'),
(23, 'UPI (PhonePe)',    '2025-10-27 09:01:00'),
(24, 'Debit Card',       '2025-10-27 11:01:00');

-- Revenue_Log (seed: paid bookings at launch)
INSERT INTO Revenue_Log (booking_id, amount, action, running_total, logged_at) VALUES
(1,  1100.00, 'credit',  1100.00, '2025-10-20 10:31:00'),
(2,   360.00, 'credit',  1460.00, '2025-10-20 11:01:00'),
(3,   360.00, 'credit',  1820.00, '2025-10-21 09:16:00'),
(4,   550.00, 'credit',  2370.00, '2025-10-21 14:01:00'),
(5,   480.00, 'credit',  2850.00, '2025-10-22 10:01:00'),
(6,   960.00, 'credit',  3810.00, '2025-10-22 16:31:00'),
(8,   360.00, 'credit',  4170.00, '2025-10-23 10:01:00'),
(10,  360.00, 'credit',  4530.00, '2025-10-23 20:01:00'),
(11,  640.00, 'credit',  5170.00, '2025-10-24 08:01:00'),
(12,  550.00, 'credit',  5720.00, '2025-10-24 10:31:00'),
(13,  640.00, 'credit',  6360.00, '2025-10-24 14:01:00'),
(14,  320.00, 'credit',  6680.00, '2025-10-24 16:46:00'),
(15,  480.00, 'credit',  7160.00, '2025-10-25 09:01:00'),
(16,  180.00, 'credit',  7340.00, '2025-10-25 11:31:00'),
(17,  360.00, 'credit',  7700.00, '2025-10-25 15:01:00'),
(20,  960.00, 'credit',  8660.00, '2025-10-26 12:01:00'),
(21,  180.00, 'credit',  8840.00, '2025-10-26 14:31:00'),
(22,  320.00, 'credit',  9160.00, '2025-10-26 16:01:00'),
(23,  360.00, 'credit',  9520.00, '2025-10-27 09:01:00'),
(24,  180.00, 'credit',  9700.00, '2025-10-27 11:01:00');

-- Review (20 rows)
INSERT INTO Review (customer_id, movie_id, rating, comment) VALUES
(1,  1,  5.0, 'Mind-blowing visuals – RRR is a once-in-a-generation masterpiece!'),
(2,  3,  4.5, 'Very inspiring and emotional. Aamir Khan at his absolute best.'),
(3,  2,  4.0, 'KGF Chapter 2 is a visual extravaganza. Yash was superb.'),
(4,  4,  4.5, 'Allu Arjun owned every frame. Pushpa is truly iconic!'),
(5,  5,  5.0, 'Uri is the finest war film India has produced. How''s the josh!'),
(6,  6,  4.0, 'Drishyam 2 kept me on the edge the whole time. Brilliant writing.'),
(7,  7,  5.0, '3 Idiots is timeless. Never gets old no matter how many times you watch.'),
(8,  8,  4.5, 'Baahubali 2 is a cinematic spectacle. Rajamouli is a genius.'),
(9,  9,  4.5, 'Andhadhun is a masterclass in suspense. Brilliant performances.'),
(10, 10, 4.0, 'Chhichhore perfectly captures the spirit of college friendship.'),
(11, 11, 4.5, 'Tumbbad is hauntingly beautiful – like nothing Bollywood ever made.'),
(12, 12, 4.0, 'Gangs of Wasseypur is a raw, unflinching saga. 10/10.'),
(13, 13, 4.5, 'Lagaan is a timeless classic. Pure gold from start to finish.'),
(14, 15, 4.5, 'Taare Zameen Par changed how I see children. Aamir is spectacular.'),
(15, 17, 4.0, 'Bajrangi Bhaijaan will move you to tears. Salman''s best role.'),
(16, 18, 4.5, 'PK makes you question everything while keeping you entertained.'),
(17, 19, 4.0, 'Gully Boy captures the soul of Mumbai''s underground hip-hop scene.'),
(18, 21, 4.5, 'Kahaani is a flawless thriller. Vidya Balan is phenomenal.'),
(19, 23, 4.5, 'Raazi is a quiet, gripping thriller. Alia is outstanding.'),
(20, 25, 4.0, 'Jab We Met is effortlessly charming. Kareena at her best.');

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
    ci.city_name   AS City,
    s.show_date,
    s.start_time,
    s.end_time,
    s.language
FROM Show_Time s
JOIN Movie      m  ON s.movie_id      = m.movie_id
JOIN Auditorium a  ON s.auditorium_id = a.auditorium_id
JOIN Theatre    th ON a.theatre_id    = th.theatre_id
JOIN City       ci ON th.city_id      = ci.city_id
WHERE s.show_date >= CURDATE()
ORDER BY s.show_date, s.start_time;

-- View 2 : Per-customer spend summary
CREATE OR REPLACE VIEW Customer_Spend_Summary AS
SELECT
    c.customer_id,
    c.name,
    c.email,
    COUNT(b.booking_id)              AS Total_Bookings,
    COALESCE(SUM(b.total_amount), 0) AS Total_Spent_INR
FROM Customer c
LEFT JOIN Booking b ON c.customer_id = b.customer_id
                    AND b.payment_status = 'paid'
GROUP BY c.customer_id, c.name, c.email;

-- View 3 : Auditorium capacity summary per theatre (now includes city)
CREATE OR REPLACE VIEW Auditorium_Capacities AS
SELECT
    t.name       AS Theatre,
    ci.city_name AS City,
    a.hall_number,
    a.capacity,
    sl.name      AS Layout_Type
FROM Auditorium  a
JOIN Theatre     t  ON a.theatre_id = t.theatre_id
JOIN City        ci ON t.city_id    = ci.city_id
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

-- View 5 : Available tickets for upcoming shows
CREATE OR REPLACE VIEW Available_Tickets AS
SELECT
    t.ticket_id,
    m.title          AS Movie,
    th.name          AS Theatre,
    ci.city_name     AS City,
    s.show_date,
    s.start_time,
    s.language,
    seat.row_num,
    seat.seat_number,
    sc.name          AS Category,
    t.price
FROM Ticket       t
JOIN Show_Time    s    ON t.show_id       = s.show_id
JOIN Movie        m    ON s.movie_id      = m.movie_id
JOIN Seat         seat ON t.seat_id       = seat.seat_id
JOIN Seat_Category sc  ON seat.category_id = sc.category_id
JOIN Auditorium   a    ON s.auditorium_id = a.auditorium_id
JOIN Theatre      th   ON a.theatre_id    = th.theatre_id
JOIN City         ci   ON th.city_id      = ci.city_id
WHERE t.booking_status = 'available'
  AND s.show_date      >= CURDATE();

-- View 6 : Real-time revenue summary (reads Revenue_Log)
CREATE OR REPLACE VIEW Live_Revenue_Summary AS
SELECT
    COUNT(DISTINCT booking_id)                     AS Paid_Bookings,
    SUM(CASE WHEN action='credit' THEN amount ELSE 0 END) AS Total_Revenue_INR,
    SUM(CASE WHEN action='debit'  THEN amount ELSE 0 END) AS Total_Refunds_INR,
    MAX(logged_at)                                 AS Last_Updated
FROM Revenue_Log;

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

-- Trigger 3 : Log booking cancellations
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

-- Trigger 4 : Release tickets automatically when a booking is cancelled
CREATE TRIGGER trg_release_tickets_on_cancel
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    IF NEW.payment_status = 'cancelled' AND OLD.payment_status != 'cancelled' THEN
        UPDATE Ticket t
        JOIN Booking_Detail bd ON t.ticket_id = bd.ticket_id
        SET t.booking_status = 'available',
            t.version        = t.version + 1
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
               CONCAT('Ticket #', NEW.ticket_id, ' price changed ₹',
                      OLD.price, ' → ₹', NEW.price)
        FROM Booking_Detail bd
        WHERE bd.ticket_id = NEW.ticket_id
        LIMIT 1;
    END IF;
END //

-- Trigger 6 : Append to Revenue_Log when a booking becomes 'paid'
--   Enables the real-time revenue SSE stream on the backend.
CREATE TRIGGER trg_revenue_on_payment
AFTER UPDATE ON Booking
FOR EACH ROW
BEGIN
    DECLARE v_running DECIMAL(15,2);
    IF NEW.payment_status = 'paid' AND OLD.payment_status != 'paid' THEN
        SELECT COALESCE(MAX(running_total), 0)
        INTO   v_running
        FROM   Revenue_Log;
        INSERT INTO Revenue_Log (booking_id, amount, action, running_total)
        VALUES (NEW.booking_id, NEW.total_amount, 'credit',
                v_running + NEW.total_amount);
    END IF;
    -- Refund: booking cancelled that was previously paid
    IF NEW.payment_status = 'cancelled' AND OLD.payment_status = 'paid' THEN
        SELECT COALESCE(MAX(running_total), 0)
        INTO   v_running
        FROM   Revenue_Log;
        INSERT INTO Revenue_Log (booking_id, amount, action, running_total)
        VALUES (NEW.booking_id, OLD.total_amount, 'debit',
                v_running - OLD.total_amount);
    END IF;
END //

-- Trigger 7 : Append to Revenue_Log on INSERT of paid booking
CREATE TRIGGER trg_revenue_on_insert
AFTER INSERT ON Booking
FOR EACH ROW
BEGIN
    DECLARE v_running DECIMAL(15,2);
    IF NEW.payment_status = 'paid' THEN
        SELECT COALESCE(MAX(running_total), 0)
        INTO   v_running
        FROM   Revenue_Log;
        INSERT INTO Revenue_Log (booking_id, amount, action, running_total)
        VALUES (NEW.booking_id, NEW.total_amount, 'credit',
                v_running + NEW.total_amount);
    END IF;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────
--  PART 5 : STORED PROCEDURES
-- ─────────────────────────────────────────────────

DELIMITER //

-- ── Procedure 1 : Apply 10% loyalty discount to large pending bookings ──
CREATE PROCEDURE ApplyLoyaltyDiscount()
BEGIN
    DECLARE done  INT DEFAULT FALSE;
    DECLARE b_id  INT;
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

-- ── Procedure 2 : Calculate total revenue (cursor-based) ──
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

-- ── Procedure 3 : Release expired reserved tickets for a show ──
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
        UPDATE Ticket SET booking_status = 'available', version = version + 1
        WHERE ticket_id = t_id;
    END LOOP;
    CLOSE cur3;
END //

-- ═══════════════════════════════════════════════════════════════
--  TRANSACTION + CONCURRENCY CONTROL PROCEDURES
-- ═══════════════════════════════════════════════════════════════

-- ── Procedure 4 : BookTicketsTxn ─────────────────────────────
--   Demonstrates:
--     1. Explicit transaction (START TRANSACTION / COMMIT / ROLLBACK)
--     2. Pessimistic concurrency control (SELECT … FOR UPDATE)
--        – row-level lock on the Ticket row prevents two sessions
--          from booking the same seat simultaneously.
--
--   Parameters:
--     p_customer_id    – customer making the booking
--     p_show_id        – show to attend
--     p_seat_id        – specific seat requested
--     p_payment_method – e.g. 'UPI (Google Pay)'
-- ──────────────────────────────────────────────────────────────
CREATE PROCEDURE BookTicketsTxn(
    IN  p_customer_id    INT,
    IN  p_show_id        INT,
    IN  p_seat_id        INT,
    IN  p_payment_method VARCHAR(50),
    OUT p_booking_id     INT,
    OUT p_message        VARCHAR(200)
)
BEGIN
    DECLARE v_ticket_id   INT   DEFAULT NULL;
    DECLARE v_price       DECIMAL(10,2);
    DECLARE v_running     DECIMAL(15,2);

    -- EXIT HANDLER: any SQL error rolls back the transaction atomically
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_booking_id = -1;
        SET p_message    = 'Transaction rolled back due to an unexpected error.';
    END;

    START TRANSACTION;

    -- ── Pessimistic lock ──────────────────────────────────────
    -- SELECT … FOR UPDATE acquires a row-level exclusive lock.
    -- A concurrent session attempting the same query will WAIT
    -- until this transaction commits or rolls back, guaranteeing
    -- no double-booking of the same seat.
    SELECT ticket_id, price
    INTO   v_ticket_id, v_price
    FROM   Ticket
    WHERE  show_id        = p_show_id
      AND  seat_id        = p_seat_id
      AND  booking_status = 'available'
    LIMIT  1
    FOR UPDATE;

    -- If no available ticket exists, abort cleanly
    IF v_ticket_id IS NULL THEN
        ROLLBACK;
        SET p_booking_id = 0;
        SET p_message    = 'Seat is no longer available. Please choose another seat.';
    ELSE
        -- Mark ticket as booked and bump version (optimistic lock counter)
        UPDATE Ticket
        SET    booking_status = 'booked',
               version        = version + 1
        WHERE  ticket_id      = v_ticket_id;

        -- Create the booking record
        INSERT INTO Booking (customer_id, total_amount, payment_status)
        VALUES (p_customer_id, v_price, 'paid');
        SET p_booking_id = LAST_INSERT_ID();

        -- Link ticket to booking
        INSERT INTO Booking_Detail (booking_id, ticket_id)
        VALUES (p_booking_id, v_ticket_id);

        -- Record payment
        INSERT INTO Payment (booking_id, payment_method)
        VALUES (p_booking_id, p_payment_method);

        -- Update Revenue_Log running total
        SELECT COALESCE(MAX(running_total), 0)
        INTO   v_running
        FROM   Revenue_Log;

        INSERT INTO Revenue_Log (booking_id, amount, action, running_total)
        VALUES (p_booking_id, v_price, 'credit', v_running + v_price);

        COMMIT;
        SET p_message = CONCAT('Booking #', p_booking_id,
                               ' confirmed. Amount: ₹', v_price);
    END IF;
END //

-- ── Procedure 5 : CancelBookingTxn ───────────────────────────
--   Cancels a booking atomically.
--   Demonstrates:
--     1. Explicit transaction
--     2. Consistent multi-table updates in a single unit of work
-- ──────────────────────────────────────────────────────────────
CREATE PROCEDURE CancelBookingTxn(
    IN  p_booking_id INT,
    OUT p_message    VARCHAR(200)
)
BEGIN
    DECLARE v_status       VARCHAR(20);
    DECLARE v_amount       DECIMAL(10,2);
    DECLARE v_running      DECIMAL(15,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_message = 'Cancellation rolled back due to an unexpected error.';
    END;

    START TRANSACTION;

    SELECT payment_status, total_amount
    INTO   v_status, v_amount
    FROM   Booking
    WHERE  booking_id = p_booking_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SET p_message = 'Booking not found.';
    ELSEIF v_status = 'cancelled' THEN
        ROLLBACK;
        SET p_message = 'Booking is already cancelled.';
    ELSE
        -- Cancel the booking (triggers handle ticket release & log)
        UPDATE Booking
        SET    payment_status = 'cancelled',
               version        = version + 1
        WHERE  booking_id     = p_booking_id;

        -- Log refund only if payment was collected
        IF v_status = 'paid' THEN
            SELECT COALESCE(MAX(running_total), 0)
            INTO   v_running
            FROM   Revenue_Log;

            INSERT INTO Revenue_Log (booking_id, amount, action, running_total)
            VALUES (p_booking_id, v_amount, 'debit', v_running - v_amount);
        END IF;

        COMMIT;
        SET p_message = CONCAT('Booking #', p_booking_id,
                               ' cancelled successfully.');
    END IF;
END //

-- ── Procedure 6 : Daily Revenue Report (uses cursor) ──────────
CREATE PROCEDURE DailyRevenueReport(IN p_date DATE)
BEGIN
    DECLARE done   INT DEFAULT FALSE;
    DECLARE b_id   INT;
    DECLARE b_amt  DECIMAL(10,2);
    DECLARE b_cust VARCHAR(100);
    DECLARE total  DECIMAL(10,2) DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT b.booking_id, b.total_amount, c.name
        FROM   Booking b
        JOIN   Customer c ON b.customer_id = c.customer_id
        WHERE  DATE(b.booking_date) = p_date
          AND  b.payment_status = 'paid';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    day_loop: LOOP
        FETCH cur INTO b_id, b_amt, b_cust;
        IF done THEN LEAVE day_loop; END IF;
        SET total = total + b_amt;
    END LOOP;
    CLOSE cur;

    SELECT p_date AS Report_Date, total AS Day_Revenue_INR;
END //

DELIMITER ;

-- ─────────────────────────────────────────────────
--  PART 6 : COMPLEX QUERIES
-- ─────────────────────────────────────────────────

-- ── Constraint Tests ────────────────────────────
ALTER TABLE Booking ALTER COLUMN payment_status SET DEFAULT 'pending';

-- ── Aggregate Functions ──────────────────────────
-- A1: Total revenue from paid bookings
SELECT SUM(total_amount) AS Total_Revenue_INR
FROM Booking WHERE payment_status = 'paid';

-- A2: Average ticket price by seat category
SELECT sc.name AS Category,
       ROUND(AVG(t.price), 2) AS Avg_Price_INR,
       COUNT(*) AS Ticket_Count
FROM Ticket t
JOIN Seat        s  ON t.seat_id     = s.seat_id
JOIN Seat_Category sc ON s.category_id = sc.category_id
GROUP BY sc.name ORDER BY Avg_Price_INR DESC;

-- A3: Ticket count by booking status
SELECT booking_status, COUNT(ticket_id) AS Total_Tickets
FROM Ticket GROUP BY booking_status;

-- A4: Top 5 movies by rating
SELECT title, director, rating
FROM Movie ORDER BY rating DESC LIMIT 5;

-- A5: Revenue per payment method
SELECT payment_method,
       COUNT(*) AS Transactions,
       SUM(b.total_amount) AS Revenue_INR
FROM Payment p
JOIN Booking b ON p.booking_id = b.booking_id
WHERE b.payment_status = 'paid'
GROUP BY payment_method ORDER BY Revenue_INR DESC;

-- ── Set Operations ───────────────────────────────
-- S1 (UNION): All persons in the cinema ecosystem
SELECT name, 'Customer' AS Type FROM Customer
UNION
SELECT name, 'Staff'    AS Type FROM Staff;

-- S2 (NOT IN): Customers who have never booked
SELECT name, email FROM Customer
WHERE customer_id NOT IN (SELECT customer_id FROM Booking);

-- ── Subqueries ───────────────────────────────────
-- SQ1: Customers who spent more than the average booking amount
SELECT name, email FROM Customer
WHERE customer_id IN (
    SELECT customer_id FROM Booking
    WHERE total_amount > (SELECT AVG(total_amount) FROM Booking)
);

-- SQ2: Most-booked movie
SELECT m.title, COUNT(bd.booking_detail_id) AS Times_Booked
FROM Movie m
JOIN Show_Time  st ON m.movie_id   = st.movie_id
JOIN Ticket     t  ON st.show_id   = t.show_id
JOIN Booking_Detail bd ON t.ticket_id = bd.ticket_id
GROUP BY m.movie_id ORDER BY Times_Booked DESC LIMIT 5;

-- SQ3: Theatres in cities with more than one theatre
SELECT t.name AS Theatre, ci.city_name
FROM Theatre t
JOIN City ci ON t.city_id = ci.city_id
WHERE ci.city_id IN (
    SELECT city_id FROM Theatre
    GROUP BY city_id HAVING COUNT(*) > 1
);

-- ── JOIN Queries ─────────────────────────────────
-- J1: Comprehensive booking report
SELECT
    b.booking_id,
    MAX(c.name)   AS Customer_Name,
    MAX(m.title)  AS Movie_Title,
    MAX(th.name)  AS Theatre,
    MAX(ci.city_name) AS City,
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
JOIN City           ci ON th.city_id       = ci.city_id
WHERE b.payment_status = 'paid'
GROUP BY b.booking_id, b.total_amount, b.payment_status;

-- J2: Revenue per city
SELECT ci.city_name,
       COUNT(DISTINCT b.booking_id) AS Bookings,
       SUM(b.total_amount)          AS Revenue_INR
FROM Booking b
JOIN Booking_Detail bd ON b.booking_id     = bd.booking_id
JOIN Ticket         t  ON bd.ticket_id     = t.ticket_id
JOIN Show_Time      st ON t.show_id        = st.show_id
JOIN Auditorium     a  ON st.auditorium_id = a.auditorium_id
JOIN Theatre        th ON a.theatre_id     = th.theatre_id
JOIN City           ci ON th.city_id       = ci.city_id
WHERE b.payment_status = 'paid'
GROUP BY ci.city_name ORDER BY Revenue_INR DESC;

-- J3: Actor → role → movie
SELECT a.name AS Actor, ma.role AS Character, m.title AS Movie
FROM Actor       a
JOIN Movie_Actor ma ON a.actor_id  = ma.actor_id
JOIN Movie       m  ON ma.movie_id = m.movie_id
ORDER BY m.title;

-- J4: Customer booking + payment method
SELECT c.name          AS Customer,
       b.booking_id,
       b.total_amount,
       b.payment_status,
       p.payment_method,
       p.transaction_date
FROM Customer c
JOIN Booking  b ON c.customer_id = b.customer_id
LEFT JOIN Payment p ON b.booking_id = p.booking_id
ORDER BY b.booking_date DESC;

-- J5: Seat pricing by category (normalisation benefit query)
SELECT th.name AS Theatre, ci.city_name, a.hall_number,
       sc.name AS Category, sc.base_price AS Standard_Price,
       COUNT(s.seat_id) AS Seat_Count
FROM Seat         s
JOIN Seat_Category sc ON s.category_id = sc.category_id
JOIN Auditorium   a   ON s.auditorium_id = a.auditorium_id
JOIN Theatre      th  ON a.theatre_id    = th.theatre_id
JOIN City         ci  ON th.city_id      = ci.city_id
GROUP BY th.name, ci.city_name, a.hall_number, sc.name, sc.base_price
ORDER BY th.name, sc.base_price DESC;

-- ── Views Usage ──────────────────────────────────
SELECT * FROM Active_Showtimes;
SELECT * FROM Customer_Spend_Summary ORDER BY Total_Spent_INR DESC;
SELECT * FROM Auditorium_Capacities;
SELECT * FROM Movie_Cast_Overview;
SELECT * FROM Available_Tickets;
SELECT * FROM Live_Revenue_Summary;

-- ── Procedure Calls ──────────────────────────────
CALL ReleaseReservedTickets(1);
CALL DailyRevenueReport('2025-10-25');
CALL CalculateTotalRevenue();
-- Demonstrate transaction-based booking
CALL BookTicketsTxn(30, 3, 8, 'UPI (Google Pay)', @bid, @msg);
SELECT @bid AS Booking_ID, @msg AS Message;

-- ─────────────────────────────────────────────────
--  END OF SCRIPT
-- ─────────────────────────────────────────────────

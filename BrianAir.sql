-- Author: Jaafar Kamalah

-- Drop all tables, vies, functions and procedures
SET FOREIGN_KEY_CHECKS=0; 
DROP TABLE IF EXISTS routes;
DROP TABLE IF EXISTS airports;
DROP TABLE IF EXISTS years;
DROP TABLE IF EXISTS weekdays;
DROP TABLE IF EXISTS weekly_flights;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS passengers;
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS passenger_reservations;
DROP TABLE IF EXISTS passenger_bookings;
DROP PROCEDURE IF EXISTS addYear;
DROP PROCEDURE IF EXISTS addDay;
DROP PROCEDURE IF EXISTS addDestination;
DROP PROCEDURE IF EXISTS addRoute;
DROP PROCEDURE IF EXISTS addFlight;
DROP FUNCTION IF EXISTS calculateFreeSeats;
DROP FUNCTION IF EXISTS calculatePrice;
DROP FUNCTION IF EXISTS issueTicket;
DROP FUNCTION IF EXISTS issueReservationNumber;
DROP PROCEDURE IF EXISTS addReservation;
DROP PROCEDURE IF EXISTS addPassenger;
DROP PROCEDURE IF EXISTS addContact;
DROP PROCEDURE IF EXISTS addPayment;
DROP VIEW IF EXISTS allFlights;

SET FOREIGN_KEY_CHECKS=1;

CREATE TABLE airports(
    code VARCHAR(3),
    country VARCHAR(30) NOT NULL,
    name VARCHAR(30) NOT NULL,

    CONSTRAINT pk_airports
    PRIMARY KEY(code)
);

CREATE TABLE years(
    year INTEGER,
    profit_factor DOUBLE NOT NULL,

    CONSTRAINT pk_years
    PRIMARY KEY(year)
);

CREATE TABLE routes(
    id INTEGER AUTO_INCREMENT,
    price DOUBLE NOT NULL,
    year INTEGER NOT NULL,
    airport_departure VARCHAR(3) NOT NULL,
    airport_arrival VARCHAR(3) NOT NULL,

    CONSTRAINT pk_routes
    PRIMARY KEY(id),

    CONSTRAINT fk_routes_airport_departure
    FOREIGN KEY(airport_departure) REFERENCES airports(code),

    CONSTRAINT fk_routes_airport_arrival
    FOREIGN KEY(airport_arrival) REFERENCES airports(code),

    CONSTRAINT fk_routes_year
    FOREIGN KEY(year) REFERENCES years(year),

    CONSTRAINT unique_routes
    UNIQUE(airport_departure, airport_arrival, year)

);

CREATE TABLE weekdays(
    year INTEGER,
    weekday VARCHAR(10),
    weekday_factor double NOT NULL,

    CONSTRAINT pk_weekdays
    PRIMARY KEY(year, weekday),

    CONSTRAINT fk_year
    FOREIGN KEY(year) REFERENCES years(year)
);

CREATE TABLE weekly_flights(
    id INTEGER AUTO_INCREMENT,
    route INTEGER NOT NULL,
    departure_time TIME NOT NULL,
    year INTEGER NOT NULL,
    weekday VARCHAR(10) NOT NULL,

    CONSTRAINT pk_weekly_flights
    PRIMARY KEY(id),

    CONSTRAINT fk_weekly_flights_route
    FOREIGN KEY(route) REFERENCES routes(id),

    CONSTRAINT fk_weekly_flights_year
    FOREIGN KEY(year) REFERENCES years(year),

    CONSTRAINT fk_weekly_flights_weekday
    FOREIGN KEY(year, weekday) REFERENCES weekdays(year, weekday)
);

CREATE TABLE flights(
    id INTEGER AUTO_INCREMENT,
    weekly_flight INTEGER NOT NULL,
    week INTEGER NOT NULL,

    CONSTRAINT pk_flights
    PRIMARY KEY(id),

    CONSTRAINT fk_flights_weekly_flight
    FOREIGN KEY(weekly_flight) REFERENCES weekly_flights(id)
);

CREATE TABLE passengers(
    passport_number INTEGER,
    name VARCHAR(30) NOT NULL,

    CONSTRAINT pk_passengers
    PRIMARY KEY(passport_number)
);

CREATE TABLE contacts(
    passenger INTEGER,
    email VARCHAR(30) NOT NULL,
    phone_number BIGINT NOT NULL,

    CONSTRAINT pk_contacts
    PRIMARY KEY(passenger),

    CONSTRAINT fk_contact_contact
    FOREIGN KEY(passenger) REFERENCES passengers(passport_number)
);

CREATE TABLE reservations(
    reservation_number INTEGER,
    flight INTEGER NOT NULL,
    contact INTEGER,

    CONSTRAINT pk_reservations
    PRIMARY KEY(reservation_number),

    CONSTRAINT fk_reservations_flight
    FOREIGN KEY(flight) REFERENCES flights(id),

    CONSTRAINT fk_reservations_contact
    FOREIGN KEY(contact) REFERENCES contacts(passenger)
);

CREATE TABLE bookings(
    reservation INTEGER,
    creditcard_holder VARCHAR(30) NOT NULL,
    creditcard_number BIGINT NOT NULL,
    price DOUBLE NOT NULL,

    CONSTRAINT pk_bookings
    PRIMARY KEY(reservation),

    CONSTRAINT fk_bookings_reservation
    FOREIGN KEY(reservation) REFERENCES reservations(reservation_number)
);

CREATE TABLE passenger_reservations(
    passenger INTEGER,
    reservation INTEGER,

    CONSTRAINT pk_passenger_reservations
    PRIMARY KEY(passenger, reservation),

    CONSTRAINT fk_passenger_reservations_passenger
    FOREIGN KEY(passenger) REFERENCES passengers(passport_number),

    CONSTRAINT fk_passenger_reservations_reservation
    FOREIGN KEY(reservation) REFERENCES reservations(reservation_number)
);

CREATE TABLE passenger_bookings(
    passenger INTEGER,
    booking INTEGER,
    ticket_number INTEGER NOT NULL,

    CONSTRAINT pk_passenger_bookings
    PRIMARY KEY(passenger, booking),

    CONSTRAINT fk_passenger_bookings_passenger
    FOREIGN KEY(passenger) REFERENCES passengers(passport_number),

    CONSTRAINT fk_passenger_bokings_booking
    FOREIGN KEY(booking) REFERENCES bookings(reservation),

    CONSTRAINT unique_ticket
    UNIQUE (ticket_number)
);

DELIMITER //
CREATE PROCEDURE addYear(IN year INTEGER, IN factor DOUBLE)
BEGIN
    INSERT INTO years VALUES (year,factor);
END;//



CREATE PROCEDURE addDay(IN year INTEGER, IN weekday VARCHAR(10), IN factor DOUBLE)
BEGIN
    INSERT INTO weekdays VALUES (year, weekday, factor);
END;//



CREATE PROCEDURE addDestination(IN airport_code VARCHAR(3), IN name VARCHAR(30), IN country VARCHAR(30))
BEGIN
    INSERT INTO airports VALUES (airport_code, country, name);
END;//



CREATE PROCEDURE addRoute(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3),
                          IN year INTEGER, IN routeprice DOUBLE)
BEGIN
    INSERT INTO routes (price, year, airport_departure, airport_arrival) 
    VALUES (routeprice, year, departure_airport_code, arrival_airport_code);
END;//



CREATE PROCEDURE addFlight(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3),
                           IN year INTEGER, IN weekday VARCHAR(10), IN departure_time TIME)
BEGIN
    DECLARE route_id INTEGER;
    DECLARE weekly_flight_id INTEGER;
    DECLARE week_number INTEGER;

    -- Always returns one id because route has uniqueness constraint for (arrival, destination, year)
    SELECT id INTO route_id
    FROM routes
    WHERE airport_arrival = arrival_airport_code AND airport_departure = departure_airport_code 
        AND routes.year = year;

    INSERT INTO weekly_flights (route, departure_time, year, weekday)
    VALUES (route_id, departure_time, year, weekday);

    SET week_number = 1;
    SET weekly_flight_id = LAST_INSERT_ID();
    WHILE week_number <= 52 DO
        INSERT INTO flights (weekly_flight, week)
        VALUES (weekly_flight_id, week_number);
        
        SET week_number = week_number + 1;
    END WHILE;
END;//



CREATE FUNCTION calculateFreeSeats(flight_ID INTEGER)
RETURNS INTEGER
BEGIN
    DECLARE booked_seats INTEGER;
    DECLARE free_seats INTEGER;

    SELECT COUNT(*) INTO booked_seats
    FROM reservations inner join passenger_bookings 
    ON reservations.reservation_number = passenger_bookings.booking
    WHERE reservations.flight = flight_ID;

    SET free_seats = 40 - booked_seats;
    RETURN free_seats;

END;//


 
CREATE FUNCTION calculatePrice(flight_ID INTEGER)
RETURNS DOUBLE
BEGIN
    DECLARE route_price DOUBLE;
    DECLARE weekday_factor DOUBLE;
    DECLARE profit_factor DOUBLE;
    DECLARE booked_seats INTEGER;

    SELECT routes.price, weekdays.weekday_factor, years.profit_factor 
    INTO route_price, weekday_factor, profit_factor
    FROM flights INNER JOIN weekly_flights ON flights.weekly_flight = weekly_flights.id
    INNER JOIN routes ON weekly_flights.route = routes.id
    INNER JOIN weekdays ON weekly_flights.weekday = weekdays.weekday AND weekly_flights.year = weekdays.year
    INNER JOIN years ON weekly_flights.year = years.year
    WHERE flights.id = flight_ID;

    SELECT 40 - calculateFreeSeats(flight_ID) INTO booked_seats;

    RETURN ROUND(route_price * weekday_factor * (booked_seats + 1) / 40 * profit_factor, 3);
END;//


-- Returns a unique and unguessable value between 0 and 100000000
CREATE FUNCTION issueTicket()
RETURNS INTEGER
BEGIN
    DECLARE ticket INTEGER;
    DECLARE not_unique BOOLEAN DEFAULT TRUE;
    WHILE not_unique DO
        SET ticket = FLOOR(RAND() * 100000000);
        SELECT COUNT(*) INTO not_unique
        FROM passenger_bookings
        WHERE ticket_number = ticket;
    END WHILE;
    RETURN ticket;
END;//


-- We interpreted "once paid" as a row inserted into bookings
CREATE TRIGGER PassengerBookingsTrigger
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO passenger_bookings
    SELECT pr.passenger, NEW.reservation, issueTicket()
    FROM passenger_reservations AS pr
    WHERE pr.reservation = NEW.reservation;
END;//



-- Returns a unique and unguessable value between 0 and 100000000
CREATE FUNCTION issueReservationNumber()
RETURNS INTEGER
BEGIN
    DECLARE reservation_nr INTEGER;
    DECLARE not_unique BOOLEAN DEFAULT TRUE;
    WHILE not_unique DO
        SET reservation_nr = FLOOR(RAND() * 100000000);
        SELECT COUNT(*) INTO not_unique
        FROM reservations
        WHERE reservation_number = reservation_nr;
    END WHILE;
    RETURN reservation_nr;
END;//



CREATE PROCEDURE addReservation(IN departure_airport_code VARCHAR(3), IN arrival_airport_code VARCHAR(3), 
                                IN year INTEGER, IN week INTEGER, IN day VARCHAR(10), IN time TIME, 
                                IN number_of_passengers INTEGER, OUT output_reservation_nr INTEGER)
BEGIN
    DECLARE flight_number INTEGER;
    DECLARE unguessable_reservation_number INTEGER;
    
    SELECT flights.id INTO flight_number
    FROM flights INNER JOIN weekly_flights ON flights.weekly_flight = weekly_flights.id
    INNER JOIN routes ON weekly_flights.route = routes.id
    WHERE routes.airport_departure = departure_airport_code AND 
    routes.airport_arrival = arrival_airport_code AND routes.year = year AND flights.week = week AND
    weekly_flights.weekday = day AND weekly_flights.departure_time = time;

    IF flight_number IS NULL THEN
        SELECT "There exist no flight for the given route, date and time" AS error_message;
    ELSE
        IF calculateFreeSeats(flight_number) < number_of_passengers THEN
            SELECT "There are not enough seats available on the chosen flight" AS error_message;
        ELSE
            SET unguessable_reservation_number = issueReservationNumber();

            INSERT INTO reservations (reservation_number, flight)
            VALUES (unguessable_reservation_number, flight_number);

            SET output_reservation_nr = unguessable_reservation_number;
        END IF;
    END IF;
END;//



CREATE PROCEDURE addPassenger(IN reservation_nr INTEGER, IN passport_number INTEGER, IN name VARCHAR(30))
BEGIN
    DECLARE boo_nr INTEGER;
    DECLARE res_nr INTEGER;
    DECLARE pas_nr INTEGER;

    -- It should not be possible to add passengers to a payed reservation (ie booking)
    SELECT reservation INTO boo_nr
    FROM bookings
    WHERE reservation = reservation_nr;

    IF boo_nr IS NOT NULL THEN
        SELECT "The booking has already been payed and no futher passengers can be added" AS error_message;
    ELSE
        SELECT reservations.reservation_number INTO res_nr
        FROM reservations
        WHERE reservations.reservation_number = reservation_nr;

        IF res_nr IS NULL THEN
            SELECT "The given reservation number does not exist" AS error_message;
        ELSE
            -- Insert into passengers if not already stored
            SELECT passport_number INTO pas_nr
            FROM passengers
            WHERE passengers.passport_number = passport_number;

            IF pas_nr IS NULL THEN
                INSERT INTO passengers VALUES (passport_number, name);
            END IF;
            
            -- Insert into passengers reservations
            INSERT INTO passenger_reservations VALUES (passport_number, reservation_nr);
        END IF;
    END IF;
END;//



CREATE PROCEDURE addContact(IN reservation_nr INTEGER, IN passport_number INTEGER, 
                            IN email VARCHAR(30), IN phone BIGINT)
BEGIN
    DECLARE res_nr INTEGER;
    DECLARE pas_nr INTEGER;
    DECLARE con_pa INTEGER;

    SELECT reservations.reservation_number INTO res_nr
    FROM reservations
    WHERE reservations.reservation_number = reservation_nr;

    IF res_nr IS NULL THEN
        SELECT "The given reservation number does not exist" AS error_message;
    ELSE
        SELECT passenger_reservations.passenger INTO pas_nr
        FROM passenger_reservations
        WHERE passenger_reservations.reservation = reservation_nr AND 
              passenger_reservations.passenger = passport_number;

        IF pas_nr IS NULL THEN
            SELECT "The person is not a passenger of the reservation" AS error_message;
        ELSE
            -- Insert into contacts if not already stored
            SELECT contacts.passenger INTO con_pa
            FROM contacts
            WHERE passenger = passport_number;

            IF con_pa IS NULL THEN
                INSERT INTO contacts VALUES (passport_number, email, phone);
            END IF;

            UPDATE reservations SET reservations.contact = passport_number
            WHERE reservations.reservation_number = reservation_nr;
        END IF;
    END IF;
END;//



CREATE PROCEDURE addPayment(IN reservation_nr INTEGER, IN cardholder_name VARCHAR(30), 
                            IN credit_card_number BIGINT)
BEGIN
    DECLARE res_nr INTEGER;
    DECLARE res_seats INTEGER;
    DECLARE res_con INTEGER;
    DECLARE res_price DOUBLE DEFAULT 0;
    DECLARE flight_nr INTEGER;

    SELECT reservations.reservation_number INTO res_nr
    FROM reservations
    WHERE reservations.reservation_number = reservation_nr;

    IF res_nr IS NULL THEN
        SELECT "The given reservation number does not exist" AS error_message;
    ELSE
        SELECT COUNT(*) INTO res_seats
        FROM passenger_reservations
        WHERE reservation = reservation_nr;

        SELECT flight INTO flight_nr
        FROM reservations
        WHERE reservation_number = reservation_nr;

        IF res_seats > calculateFreeSeats(flight_nr) THEN
            SELECT "There are not enough seats available on the flight anymore, deleting reservation" AS error_message;
            
            DELETE FROM passenger_reservations WHERE reservation = reservation_nr;
            DELETE FROM reservations WHERE reservation_number = reservation_nr;
        ELSE
            -- SELECT SLEEP(5); 

            SELECT contact INTO res_con
            FROM reservations
            WHERE reservation_number = reservation_nr;

            IF res_con IS NULL THEN
                SELECT "The reservation has no contact yet" AS error_message;
            ELSE
                WHILE res_seats > 0 DO
                    SET res_price = res_price + calculatePrice(flight_nr);
                    SET res_seats = res_seats - 1;
                END WHILE;

                INSERT INTO bookings
                VALUES (reservation_nr, cardholder_name, credit_card_number, res_price);
                -- Triggers PassengerBookingsTrigger which will populate passenger_bookings
            END IF;
        END IF;
    END IF;
END;//

DELIMITER ;


CREATE VIEW allFlights AS
SELECT departure.name AS departure_city_name, arrival.name AS destination_city_name, 
       departure_time, weekday AS departure_day, week AS departure_week, 
       weekly_flights.year AS departure_year, calculateFreeSeats(flights.id) AS nr_of_free_seats,
       calculatePrice(flights.id) AS current_price_per_seat
FROM flights INNER JOIN weekly_flights ON flights.weekly_flight = weekly_flights.id
INNER JOIN routes ON weekly_flights.route = routes.id
INNER JOIN airports AS arrival ON routes.airport_arrival = arrival.code
INNER JOIN airports AS departure ON routes.airport_departure = departure.code;



/*
Question 8a: How can you protect the credit card information in the database from hackers?

Answer:
The credit card information can be protected by applying a strong encryption algorithm. Thereby
even if a hacker gains access to the database they won't be able to view the users's sensitive
data without the encryption keys, which can be stored on a seperate database with strict access
restrictions. Moreover, authorized user access should also be restricted so that for example,
users who only need to view flight information don't have access to user data.

*/



/*
Question 8b:  Give three advantages of using stored procedures in the database (and, thereby, 
execute them on the server) instead of writing the same functions in the frontend 
of the system (for example, in JavaScript on a Web page)?

Answer:
One advantage of using server-side procedures is having increased security over the database. This is 
because we can restrict the access of different database users to specificc sets of procedures.These 
users can thereby only work with the database as intended by designers of these procedures, allowing
productive use without full access.

A second advantage of using server-side procedures is improved performance and reduced network traffic.
This is because the procedures are executed on the server-side and not the client-side. This means that
only the final dataset needs to be sent back to the client while all the intermediate querry results are
handled on the server. Thereby, users with a long round-trip time to the server don't experience as big
of an delay as they would if the procedures were executed on the client-side.

A third advantage of using server-side procedures is enhanced programming productivity. This is because
server-side procedures can be reused by many different users of the database. Client-side procedures can 
however only be used by the one client who developed the procedure. This can lead to many widespread
procedures with duplicate functionality that all need to be seperately maintained and updated when the
database is altered. Thereby, server-side procedures can save on programming time by offering a
centralized solution.
*/



/*
Question 9b: Open two SQL sessions in two terminals. We call one of them A and the other one B. 
Write START TRANSACTION; in both terminals. In session A, add a new reservation. Is this reservation 
visible in session B? Why? Why not? 

Answer:
No, the reservation is not visible in session B. This is because session A has not yet commited 
the changes of it's transaction. Session B therefore reads the table in the state it was in during
the last commit (before sesson A started).
*/



/*
Question 9c: What happens if you try to modify the reservation from A in B? Explain what 
happens and why this happens and how this relates to the concept of isolation 
of transactions. 

Answer:
When session B tries to update the reservation that A created, the update statement will be stalled 
until session A is committed. This happens because in MariaDB a write-lock is implicitly added during
inserts and updates in a table. So when A inserts the reservation it holds the write-lock. When B 
then updates it is asking for the write-lock that A is holding and is therefore stalled. When A is 
committed it releases the write-lock and B can now acquire it. This behaviour is implemented for 
transaction isolation. Transaction isolation ensures that concurrent transaction do not interfere 
with each other's results.
*/



/*
Question 10a: Is your BrianAir implementation safe when handling multiple concurrent 
transactions? Let two customers try to simultaneously book more seats than what are 
available on a flight and see what happens. This is tested by executing the test scripts 
available on the course Website using two different SQL sessions. Note that you 
should not use explicit transaction control unless this is your solution on 10c. 
Did overbooking occur when the scripts were executed? If so, why? If not, why not? 

Answer:
An overbooking did not occur when running the scripts with the original implementation of 
addPayment(). This is because the first terminal finishes adding all the passengers in 
passenger_bookings before the second terminal reads from passenger_bookings how many free 
seats the reservation has. 
*/



/*
Question 10b: Can an overbooking theoretically occur? If an overbooking is possible, in what 
order must the lines of code in your procedures/functions be executed. 

Answer:
Yes, an overbooking can occur in theory. This can be proven by calling sleep(5) in addPayment()
somewhere between the line that calls calculateFreeSeats() and the line that inserts the 
booking in bookings, thereby calling the trigger that inserts the passengers in passenger_bookings.
The order in which there occurs an overbooking is:
1. Terminal 1 runs calculateFreeSeats() and calculates that there are enough free seats on the plane.
2. Terminal 2 runs calculateFreeSeats() and calculates that there are enough free seats on the plane.
3. Terminal 1 adds the bookings and triggers the addition of the passengers to the booking.
4. Terminal 2 adds the booking and triggers the addition of the passengers to the booking.
*/



/*
Question 20: Try to make the theoretical case occur in reality by simulating that multiple 
sessions call the procedure at the same time. To specify the order in which the 
lines of code are executed use the SQL statement SELECT sleep(5); which makes 
the session sleep for 5 seconds. Note that it is not always possible to make the 
theoretical case occur; if not, motivate why. 

Answer:
Adding sleep() between lines 483 and 497 did make overbooking happen.
*/



/*
Question 21: Modify the test scripts so that overbookings are no longer possible using (some 
of) the commands START TRANSACTION, COMMIT, LOCK TABLES, UNLOCK TABLES, 
ROLLBACK, SAVEPOINT, and SELECT…FOR UPDATE. Motivate why your solution 
solves the issue, and test that this also is the case using the sleep implemented in 
10c. Note that it is not okay if one of the sessions ends up in a deadlock. Also, try 
to hold locks on the common resources for as short time as possible to allow 
multiple sessions to be active at the same time. 

Answer:
With this implementation, reservation of the same flight will be blocked from running 
addPayment concurrently.

In Question10MakeBooking.sql:
...
START TRANSACTION;
SELECT flight
FROM reservations
WHERE reservation_number = @a
FOR UPDATE;
CALL addPayment (@a, "Sauron",7878787878);
COMMIT;
...
*/


/*
Secondary index question: Identify one case where a secondary index would be useful. Design the index, 
describe and motivate your design. (Do not implement this.)

Answer:
Secondary indexes are used for speeding up retrieval on a non-ordering field. In MariaDB the table's
physical storage is ordered by the primary key. Therefore we want to find a non-primary-key field
where faster retirieval would be useful. One such example is the ticket_number field in the
passenger_bookings table. This field it not a primary key and is searched for in the issueTicket()
trigger for every booked passenger. Since ticket_number has the uniqueness contraint we can use
a secondary index on key field, where the index file consists of one column for the ticket numbers
and one column for the pointers. The index file is sorted based on the first column with the ticket
numbers and stores one index for each data record (ticket). The poitners point to the block where the
data record is stored.

Searching for a specific ticket_number would therefore consist of:
1. Retrieving the index file.
2. Doing a binary search for the specified ticket_number in the index file.
3. After the index is found, retrieving the block which the index is pointing to.
4. Doing a linear search for the specified ticket_number in the data file.

*/
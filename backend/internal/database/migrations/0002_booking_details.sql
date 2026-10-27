ALTER TABLE bookings ADD COLUMN passenger_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE bookings ADD COLUMN parcel_weight_kg REAL;
ALTER TABLE bookings ADD COLUMN parcel_size TEXT;
ALTER TABLE bookings ADD COLUMN parcel_image_data TEXT;

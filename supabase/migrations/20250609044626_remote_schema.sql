

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."get_venue_available_slots"("venue_id" "uuid", "booking_date" "date") RETURNS TABLE("time_slot" time without time zone)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_day_of_week INTEGER;
  v_open_time TIME;
  v_close_time TIME;
  v_is_closed BOOLEAN;
  slot_interval INTERVAL := '30 minutes';
  current_slot TIME;
  end_slot TIME;
BEGIN
  -- Get the day of week (0 = Sunday, 1 = Monday, etc.)
  v_day_of_week := EXTRACT(DOW FROM booking_date);
  
  -- Get venue hours for this day with proper table alias
  SELECT vh.open_time, vh.close_time, vh.is_closed
  INTO v_open_time, v_close_time, v_is_closed
  FROM venue_hours vh
  WHERE vh.venue_id = get_venue_available_slots.venue_id
    AND vh.day_of_week = v_day_of_week;
  
  -- If venue is closed or hours not found, return empty result
  IF v_is_closed IS TRUE OR v_open_time IS NULL OR v_close_time IS NULL THEN
    RETURN;
  END IF;
  
  -- Calculate end slot (1 hour before closing for last seating)
  end_slot := v_close_time - interval '1 hour';
  
  -- If end slot is before or equal to open time, return empty
  IF end_slot <= v_open_time THEN
    RETURN;
  END IF;
  
  -- Generate time slots manually using a loop
  current_slot := v_open_time;
  
  WHILE current_slot <= end_slot LOOP
    -- Check if this slot is not already booked
    IF NOT EXISTS (
      SELECT 1 
      FROM bookings b 
      WHERE b.venue_id = get_venue_available_slots.venue_id
        AND b.date = get_venue_available_slots.booking_date
        AND b.time = current_slot
        AND b.status IN ('confirmed', 'seated')
    ) THEN
      time_slot := current_slot;
      RETURN NEXT;
    END IF;
    
    -- Move to next slot
    current_slot := current_slot + slot_interval;
  END LOOP;
  
  RETURN;
END;
$$;


ALTER FUNCTION "public"."get_venue_available_slots"("venue_id" "uuid", "booking_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, phone, type, status)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'first_name',
    new.raw_user_meta_data->>'last_name',
    new.raw_user_meta_data->>'phone',
    COALESCE(new.raw_user_meta_data->>'user_type', 'customer'),
    'active'
  );
  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_venue_booking_count"("venue_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE venues
  SET booking_count = COALESCE(booking_count, 0) + 1
  WHERE id = venue_id;
END;
$$;


ALTER FUNCTION "public"."increment_venue_booking_count"("venue_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "venue_id" "uuid",
    "user_id" "uuid",
    "date" "date" NOT NULL,
    "time" time without time zone NOT NULL,
    "party_size" integer NOT NULL,
    "status" character varying(20) DEFAULT 'pending'::character varying,
    "special_requests" "text",
    "confirmation_number" character varying(20),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "customer_email" character varying(255),
    "customer_phone" character varying(20),
    "customer_first_name" character varying(100),
    "customer_last_name" character varying(100)
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "first_name" character varying(100),
    "last_name" character varying(100),
    "phone" character varying(20),
    "type" character varying(20) DEFAULT 'customer'::character varying,
    "status" character varying(20) DEFAULT 'active'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_login" timestamp with time zone,
    "email" character varying(255)
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_features" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "venue_id" "uuid",
    "feature" character varying(100) NOT NULL
);


ALTER TABLE "public"."venue_features" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_hours" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "venue_id" "uuid",
    "day_of_week" integer NOT NULL,
    "open_time" time without time zone,
    "close_time" time without time zone,
    "is_closed" boolean DEFAULT false
);


ALTER TABLE "public"."venue_hours" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_images" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "venue_id" "uuid",
    "image_url" "text" NOT NULL,
    "position" integer DEFAULT 0
);


ALTER TABLE "public"."venue_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venue_settings" (
    "venue_id" "uuid" NOT NULL,
    "max_party_size" integer DEFAULT 8,
    "advance_booking_days" integer DEFAULT 30,
    "cancellation_hours" integer DEFAULT 2,
    "auto_confirm" boolean DEFAULT false,
    "require_phone" boolean DEFAULT true,
    "allow_special_requests" boolean DEFAULT true,
    "email_notifications" boolean DEFAULT true,
    "sms_notifications" boolean DEFAULT false
);


ALTER TABLE "public"."venue_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."venues" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" character varying(255) NOT NULL,
    "description" "text",
    "cuisine" character varying(100),
    "price_range" character varying(10),
    "address" character varying(255),
    "location" character varying(100),
    "phone" character varying(20),
    "website" character varying(255),
    "owner_id" "uuid",
    "status" character varying(20) DEFAULT 'pending'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "rating" numeric(3,2),
    "review_count" integer DEFAULT 0
);


ALTER TABLE "public"."venues" OWNER TO "postgres";


ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_features"
    ADD CONSTRAINT "venue_features_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_hours"
    ADD CONSTRAINT "venue_hours_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_images"
    ADD CONSTRAINT "venue_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."venue_settings"
    ADD CONSTRAINT "venue_settings_pkey" PRIMARY KEY ("venue_id");



ALTER TABLE ONLY "public"."venues"
    ADD CONSTRAINT "venues_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_bookings_customer_email" ON "public"."bookings" USING "btree" ("customer_email");



CREATE INDEX "idx_bookings_date" ON "public"."bookings" USING "btree" ("date");



CREATE INDEX "idx_bookings_user_id" ON "public"."bookings" USING "btree" ("user_id");



CREATE INDEX "idx_bookings_venue_id" ON "public"."bookings" USING "btree" ("venue_id");



CREATE INDEX "idx_venues_cuisine" ON "public"."venues" USING "btree" ("cuisine");



CREATE INDEX "idx_venues_location" ON "public"."venues" USING "btree" ("location");



CREATE INDEX "idx_venues_status" ON "public"."venues" USING "btree" ("status");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_features"
    ADD CONSTRAINT "venue_features_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_hours"
    ADD CONSTRAINT "venue_hours_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_images"
    ADD CONSTRAINT "venue_images_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."venue_settings"
    ADD CONSTRAINT "venue_settings_venue_id_fkey" FOREIGN KEY ("venue_id") REFERENCES "public"."venues"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can manage bookings" ON "public"."bookings" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND (("profiles"."type")::"text" = 'admin'::"text")))));



CREATE POLICY "Admins can manage venues" ON "public"."venues" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND (("profiles"."type")::"text" = 'admin'::"text")))));



CREATE POLICY "Anyone can view active venues" ON "public"."venues" FOR SELECT USING ((("status")::"text" = 'active'::"text"));



CREATE POLICY "Service role can manage profiles" ON "public"."profiles" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can create bookings" ON "public"."bookings" FOR INSERT WITH CHECK ((("auth"."uid"() = "user_id") OR ("user_id" IS NULL)));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own bookings" ON "public"."bookings" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Venue owners can update own venues" ON "public"."venues" FOR UPDATE USING (("auth"."uid"() = "owner_id"));



CREATE POLICY "Venue owners can update venue bookings" ON "public"."bookings" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."venues"
  WHERE (("venues"."id" = "bookings"."venue_id") AND ("venues"."owner_id" = "auth"."uid"())))));



CREATE POLICY "Venue owners can view own venues" ON "public"."venues" FOR SELECT USING (("auth"."uid"() = "owner_id"));



CREATE POLICY "Venue owners can view venue bookings" ON "public"."bookings" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."venues"
  WHERE (("venues"."id" = "bookings"."venue_id") AND ("venues"."owner_id" = "auth"."uid"())))));



ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."venues" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_venue_available_slots"("venue_id" "uuid", "booking_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_venue_available_slots"("venue_id" "uuid", "booking_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_venue_available_slots"("venue_id" "uuid", "booking_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_venue_booking_count"("venue_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_venue_booking_count"("venue_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_venue_booking_count"("venue_id" "uuid") TO "service_role";


















GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."venue_features" TO "anon";
GRANT ALL ON TABLE "public"."venue_features" TO "authenticated";
GRANT ALL ON TABLE "public"."venue_features" TO "service_role";



GRANT ALL ON TABLE "public"."venue_hours" TO "anon";
GRANT ALL ON TABLE "public"."venue_hours" TO "authenticated";
GRANT ALL ON TABLE "public"."venue_hours" TO "service_role";



GRANT ALL ON TABLE "public"."venue_images" TO "anon";
GRANT ALL ON TABLE "public"."venue_images" TO "authenticated";
GRANT ALL ON TABLE "public"."venue_images" TO "service_role";



GRANT ALL ON TABLE "public"."venue_settings" TO "anon";
GRANT ALL ON TABLE "public"."venue_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."venue_settings" TO "service_role";



GRANT ALL ON TABLE "public"."venues" TO "anon";
GRANT ALL ON TABLE "public"."venues" TO "authenticated";
GRANT ALL ON TABLE "public"."venues" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";


RESET ALL;


ALTER TABLE venues
ADD CONSTRAINT venues_owner_id_fkey
FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE SET NULL;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
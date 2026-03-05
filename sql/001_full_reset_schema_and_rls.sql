-- ==========================================
-- JAI GURUDEV PET CLINIC - FULL RESET
-- PUBLIC BOOKING + STAFF AUTH
-- WARNING: DELETES EXISTING CLINIC TABLE DATA
-- ==========================================

create extension if not exists pgcrypto;
create extension if not exists "uuid-ossp";

-- ==========================================
-- DROP TRIGGERS
-- ==========================================
drop trigger if exists trigger_update_patient_stats on appointments;
drop trigger if exists trigger_update_daily_tally on appointments;

-- ==========================================
-- DROP FUNCTIONS
-- ==========================================
drop function if exists public.update_patient_stats() cascade;
drop function if exists public.update_daily_tally() cascade;
drop function if exists public.find_or_create_patient(text, text, text, text) cascade;
drop function if exists public.is_admin(uuid) cascade;
drop function if exists public.get_booked_slots(date) cascade;
drop function if exists public.get_patient_booking_profile(text) cascade;
drop function if exists public.book_public_appointment(date, time, text, text, text, text, text, text) cascade;
drop function if exists public.sync_staff_identity(uuid, text) cascade;

-- ==========================================
-- DROP TABLES
-- ==========================================
drop table if exists audit_log cascade;
drop table if exists daily_tally cascade;
drop table if exists appointments cascade;
drop table if exists patients cascade;
drop table if exists services cascade;
drop table if exists staff cascade;

-- ==========================================
-- TABLES
-- ==========================================

create table staff (
    id uuid primary key default gen_random_uuid(),
    email text not null unique,
    name text not null,
    role text not null default 'staff',
    phone text,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

create table patients (
    id uuid primary key default gen_random_uuid(),
    owner_name text not null,
    phone text not null unique,
    email text,
    address text,
    pet_name text not null,
    pet_type text not null,
    pet_breed text,
    pet_dob date,
    pet_gender text,
    allergies jsonb not null default '[]'::jsonb,
    chronic_conditions jsonb not null default '[]'::jsonb,
    vaccination_history jsonb not null default '[]'::jsonb,
    total_visits integer not null default 0,
    total_spent integer not null default 0,
    last_visit_date date,
    created_at timestamptz not null default now()
);

create table appointments (
    id uuid primary key default gen_random_uuid(),
    appointment_date date not null,
    appointment_time time not null,

    owner_name text not null,
    phone text not null,
    pet_name text not null,
    pet_type text not null,
    pet_breed text,

    reason text not null,
    diagnosis text,
    treatment_given text,
    medicines_prescribed jsonb not null default '[]'::jsonb,
    vitals jsonb,
    notes text,
    next_visit_date date,

    consultation_fee integer not null default 0,
    medicine_charges integer not null default 0,
    procedure_charges integer not null default 0,
    total_amount integer not null default 0,
    payment_method text,
    payment_status text not null default 'pending',

    status text not null default 'scheduled',
    is_walkin boolean not null default false,
    walkin_added_by text,

    patient_id uuid references patients(id),

    created_by text not null default 'website',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table daily_tally (
    id uuid primary key default gen_random_uuid(),
    date date not null unique,
    total_appointments integer not null default 0,
    walkins integer not null default 0,
    completed_visits integer not null default 0,
    total_revenue integer not null default 0,
    cash_collected integer not null default 0,
    upi_collected integer not null default 0,
    card_collected integer not null default 0,
    pending_amount integer not null default 0,
    created_at timestamptz not null default now()
);

create table audit_log (
    id uuid primary key default gen_random_uuid(),
    table_name text not null,
    record_id uuid,
    action text not null,
    old_data jsonb,
    new_data jsonb,
    performed_by text,
    performed_at timestamptz not null default now()
);

create table services (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    category text,
    description text,
    base_price integer,
    duration_minutes integer,
    icon text,
    color text,
    is_active boolean not null default true,
    display_order integer not null default 0
);

create index idx_patients_phone on patients(phone);
create index idx_appointments_date_time on appointments(appointment_date, appointment_time);
create index idx_appointments_patient_id on appointments(patient_id);
create index idx_staff_email on staff(email);

-- ==========================================
-- FUNCTIONS
-- ==========================================

create or replace function public.update_patient_stats()
returns trigger
language plpgsql
as $$
begin
    if new.status = 'completed' and (old.status is null or old.status <> 'completed') then
        update patients
        set
            total_visits = total_visits + 1,
            total_spent = total_spent + coalesce(new.total_amount, 0),
            last_visit_date = new.appointment_date
        where id = new.patient_id;
    end if;

    return new;
end;
$$;

create or replace function public.update_daily_tally()
returns trigger
language plpgsql
as $$
declare
    v_date date;
    v_total integer;
    v_walkins integer;
    v_completed integer;
    v_revenue integer;
    v_cash integer;
    v_upi integer;
    v_card integer;
    v_pending integer;
begin
    v_date := new.appointment_date;

    select
        count(*),
        count(*) filter (where is_walkin = true),
        count(*) filter (where status = 'completed'),
        coalesce(sum(total_amount) filter (where status = 'completed' and payment_status = 'paid'), 0),
        coalesce(sum(total_amount) filter (where status = 'completed' and payment_method = 'cash' and payment_status = 'paid'), 0),
        coalesce(sum(total_amount) filter (where status = 'completed' and payment_method = 'upi' and payment_status = 'paid'), 0),
        coalesce(sum(total_amount) filter (where status = 'completed' and payment_method = 'card' and payment_status = 'paid'), 0),
        coalesce(sum(total_amount) filter (where status = 'treatment-done'), 0)
    into v_total, v_walkins, v_completed, v_revenue, v_cash, v_upi, v_card, v_pending
    from appointments
    where appointment_date = v_date;

    insert into daily_tally (
        date,
        total_appointments,
        walkins,
        completed_visits,
        total_revenue,
        cash_collected,
        upi_collected,
        card_collected,
        pending_amount
    )
    values (
        v_date,
        v_total,
        v_walkins,
        v_completed,
        v_revenue,
        v_cash,
        v_upi,
        v_card,
        v_pending
    )
    on conflict (date) do update set
        total_appointments = excluded.total_appointments,
        walkins = excluded.walkins,
        completed_visits = excluded.completed_visits,
        total_revenue = excluded.total_revenue,
        cash_collected = excluded.cash_collected,
        upi_collected = excluded.upi_collected,
        card_collected = excluded.card_collected,
        pending_amount = excluded.pending_amount;

    return new;
end;
$$;

create or replace function public.find_or_create_patient(
    p_phone text,
    p_owner_name text,
    p_pet_name text,
    p_pet_type text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_patient_id uuid;
begin
    select id into v_patient_id
    from patients
    where phone = p_phone
    limit 1;

    if v_patient_id is null then
        insert into patients (phone, owner_name, pet_name, pet_type)
        values (p_phone, p_owner_name, p_pet_name, p_pet_type)
        returning id into v_patient_id;
    end if;

    return v_patient_id;
end;
$$;

create or replace function public.sync_staff_identity(
    p_user_id uuid,
    p_email text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_staff_id uuid;
begin
    if p_user_id is null or p_email is null then
        return null;
    end if;

    select id into v_staff_id
    from staff
    where id = p_user_id
    limit 1;

    if v_staff_id is not null then
        return v_staff_id;
    end if;

    update staff
    set id = p_user_id
    where lower(email) = lower(p_email)
      and id <> p_user_id;

    select id into v_staff_id
    from staff
    where id = p_user_id
       or lower(email) = lower(p_email)
    limit 1;

    return v_staff_id;
end;
$$;

create or replace function public.is_admin(user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
    return exists (
        select 1
        from staff
        where (id = user_id or lower(email) = lower(auth.jwt() ->> 'email'))
          and role = 'admin'
          and is_active = true
    );
end;
$$;

create or replace function public.get_booked_slots(p_date date)
returns table (appointment_time text)
language sql
security definer
set search_path = public
as $$
    select to_char(a.appointment_time, 'HH24:MI') as appointment_time
    from appointments a
    where a.appointment_date = p_date
      and a.status in ('scheduled', 'checked-in', 'in-progress')
    order by a.appointment_time;
$$;

create or replace function public.get_patient_booking_profile(p_phone text)
returns table (
    owner_name text,
    pet_name text,
    pet_type text,
    pet_breed text
)
language sql
security definer
set search_path = public
as $$
    select
        p.owner_name,
        p.pet_name,
        p.pet_type,
        p.pet_breed
    from patients p
    where p.phone = p_phone
    limit 1;
$$;

create or replace function public.book_public_appointment(
    p_appointment_date date,
    p_appointment_time time,
    p_owner_name text,
    p_phone text,
    p_pet_name text,
    p_pet_type text,
    p_pet_breed text,
    p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_patient_id uuid;
    v_appointment_id uuid;
begin
    if exists (
        select 1
        from appointments a
        where a.appointment_date = p_appointment_date
          and a.appointment_time = p_appointment_time
          and a.status in ('scheduled', 'checked-in', 'in-progress')
    ) then
        raise exception 'This slot is already booked';
    end if;

    select id into v_patient_id
    from patients
    where phone = p_phone
    limit 1;

    if v_patient_id is null then
        insert into patients (
            owner_name,
            phone,
            pet_name,
            pet_type,
            pet_breed
        )
        values (
            p_owner_name,
            p_phone,
            p_pet_name,
            p_pet_type,
            p_pet_breed
        )
        returning id into v_patient_id;
    else
        update patients
        set
            owner_name = p_owner_name,
            pet_name = p_pet_name,
            pet_type = p_pet_type,
            pet_breed = p_pet_breed
        where id = v_patient_id;
    end if;

    insert into appointments (
        appointment_date,
        appointment_time,
        owner_name,
        phone,
        pet_name,
        pet_type,
        pet_breed,
        reason,
        status,
        is_walkin,
        patient_id,
        created_by
    )
    values (
        p_appointment_date,
        p_appointment_time,
        p_owner_name,
        p_phone,
        p_pet_name,
        p_pet_type,
        p_pet_breed,
        p_reason,
        'scheduled',
        false,
        v_patient_id,
        'website'
    )
    returning id into v_appointment_id;

    return v_appointment_id;
end;
$$;

-- ==========================================
-- TRIGGERS
-- ==========================================

create trigger trigger_update_patient_stats
after update on appointments
for each row
execute function public.update_patient_stats();

create trigger trigger_update_daily_tally
after insert or update on appointments
for each row
execute function public.update_daily_tally();

-- ==========================================
-- RLS
-- ==========================================

alter table staff enable row level security;
alter table patients enable row level security;
alter table appointments enable row level security;
alter table daily_tally enable row level security;
alter table audit_log enable row level security;
alter table services enable row level security;

create policy "Staff can read own profile"
on staff
for select
to authenticated
using (
    id = auth.uid()
    or lower(email) = lower(auth.jwt() ->> 'email')
);

create policy "Staff full access patients"
on patients
for all
to authenticated
using (true)
with check (true);

create policy "Staff full access appointments"
on appointments
for all
to authenticated
using (true)
with check (true);

create policy "Admin only daily tally"
on daily_tally
for all
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

create policy "Admin only audit"
on audit_log
for all
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

create policy "Public read services"
on services
for select
to anon, authenticated
using (is_active = true);

-- ==========================================
-- GRANTS
-- ==========================================

grant execute on function public.find_or_create_patient(text, text, text, text) to authenticated;
grant execute on function public.sync_staff_identity(uuid, text) to authenticated;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.get_booked_slots(date) to anon, authenticated;
grant execute on function public.get_patient_booking_profile(text) to anon, authenticated;
grant execute on function public.book_public_appointment(date, time, text, text, text, text, text, text) to anon, authenticated;

-- ==========================================
-- INITIAL SERVICES
-- ==========================================

insert into services (name, category, description, base_price, duration_minutes, icon, color, display_order) values
('General Consultation', 'consultation', 'Routine health checkup', 300, 15, 'stethoscope', 'blue', 1),
('Vaccination', 'preventive', 'Vaccination shots', 400, 10, 'syringe', 'green', 2),
('Deworming', 'preventive', 'Deworming treatment', 200, 5, 'pill', 'teal', 3),
('Minor Surgery', 'surgery', 'Minor procedures', 1500, 45, 'scissors', 'purple', 4),
('Major Surgery', 'surgery', 'Complex surgery', 5000, 120, 'scan', 'red', 5),
('X-Ray', 'diagnostic', 'Digital X-ray', 800, 20, 'scan', 'amber', 6),
('Blood Test', 'diagnostic', 'Lab testing', 600, 10, 'test-tube', 'pink', 7),
('Grooming', 'care', 'Bath, nail trim', 500, 30, 'scissors', 'cyan', 8),
('Emergency Care', 'emergency', '24/7 emergency', 1000, 60, 'heart-pulse', 'red', 9),
('Hospitalization', 'care', 'Overnight stay', 1500, 1440, 'bed', 'indigo', 10);


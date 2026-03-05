create table if not exists public.medicine_purchases (
    id uuid primary key default gen_random_uuid(),
    purchase_date date not null default current_date,
    vendor_name text,
    bill_number text,
    amount integer not null check (amount >= 0),
    notes text,
    created_by text,
    created_at timestamptz not null default now()
);

create table if not exists public.staff_salaries (
    id uuid primary key default gen_random_uuid(),
    payment_date date not null default current_date,
    salary_month date not null,
    staff_name text not null,
    amount integer not null check (amount >= 0),
    notes text,
    created_by text,
    created_at timestamptz not null default now()
);

create index if not exists idx_medicine_purchases_date on public.medicine_purchases(purchase_date);
create index if not exists idx_staff_salaries_payment_date on public.staff_salaries(payment_date);
create index if not exists idx_staff_salaries_salary_month on public.staff_salaries(salary_month);

alter table public.medicine_purchases enable row level security;
alter table public.staff_salaries enable row level security;

drop policy if exists "admin_only_medicine_purchases" on public.medicine_purchases;
create policy "admin_only_medicine_purchases"
on public.medicine_purchases
for all
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

drop policy if exists "admin_only_staff_salaries" on public.staff_salaries;
create policy "admin_only_staff_salaries"
on public.staff_salaries
for all
to authenticated
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

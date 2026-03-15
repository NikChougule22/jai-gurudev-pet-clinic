alter table public.appointments
add column if not exists payment_received_date date;

create index if not exists idx_appointments_payment_received_date
on public.appointments(payment_received_date);

update public.appointments
set payment_received_date = appointment_date
where status = 'completed'
  and coalesce(payment_status, 'paid') = 'paid'
  and payment_received_date is null;

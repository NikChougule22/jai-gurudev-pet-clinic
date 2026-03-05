-- Fix: allow staff users to perform appointment workflow updates
-- when triggers write to public.daily_tally.
--
-- Run this in Supabase SQL Editor as project owner.

alter table public.daily_tally enable row level security;

drop policy if exists "daily_tally_select_staff_admin" on public.daily_tally;
drop policy if exists "daily_tally_insert_staff_admin" on public.daily_tally;
drop policy if exists "daily_tally_update_staff_admin" on public.daily_tally;
drop policy if exists "daily_tally_delete_staff_admin" on public.daily_tally;

create policy "daily_tally_select_staff_admin"
on public.daily_tally
for select
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.role in ('admin', 'staff')
      and (
        s.id = auth.uid()
        or lower(coalesce(s.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  )
);

create policy "daily_tally_insert_staff_admin"
on public.daily_tally
for insert
to authenticated
with check (
  exists (
    select 1
    from public.staff s
    where s.role in ('admin', 'staff')
      and (
        s.id = auth.uid()
        or lower(coalesce(s.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  )
);

create policy "daily_tally_update_staff_admin"
on public.daily_tally
for update
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.role in ('admin', 'staff')
      and (
        s.id = auth.uid()
        or lower(coalesce(s.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.role in ('admin', 'staff')
      and (
        s.id = auth.uid()
        or lower(coalesce(s.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  )
);

create policy "daily_tally_delete_staff_admin"
on public.daily_tally
for delete
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.role in ('admin', 'staff')
      and (
        s.id = auth.uid()
        or lower(coalesce(s.email, '')) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  )
);

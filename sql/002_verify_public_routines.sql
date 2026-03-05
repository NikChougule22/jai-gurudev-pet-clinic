select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'get_booked_slots',
    'get_patient_booking_profile',
    'book_public_appointment',
    'sync_staff_identity'
  );

select * from public.get_booked_slots(current_date);


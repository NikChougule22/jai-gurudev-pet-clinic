// ==========================================
// JAI GURUDEV PET CLINIC - CONFIGURATION
// UPDATE ALL VALUES BELOW BEFORE DEPLOYING
// ==========================================

const CONFIG = {
    // Supabase credentials (from Project Settings → API)
    SUPABASE: {
        URL: 'https://npazmhtqxqbrfrhqidvf.supabase.co',  // ← YOUR URL
        KEY: 'sb_publishable_tdAk5dgvm67xA1JXHGx2Bw_AO49IIyl' // ← YOUR ANON KEY
    },
    
    // Clinic Information
    CLINIC: {
        NAME: 'Jai Gurudev Pet Clinic',
        PHONE: '+91 98765 43210',           // ← YOUR PHONE
        EMAIL: 'contact@jaigurudevclinic.com',
        ADDRESS: {
            LINE1: 'Vishrambag, Parshwanath Colony',
            LINE2: 'Sangli, Maharashtra - 416416',
            MAPS_LINK: 'https://maps.google.com/?q=Jai+Gurudev+Pet+Clinic+Sangli'
        },
        HOURS: {
            MON_SAT: '9:00 AM - 8:00 PM',
            SUNDAY: '10:00 AM - 2:00 PM',
            EMERGENCY: '24/7 Available'
        }
    },
    
    // Doctor Information
    DOCTOR: {
        NAME: 'Dr. R. B. Chougule',            // ← DOCTOR NAME
        QUALIFICATION: 'BVSc & AH',
        EXPERIENCE: '40+ years',
        REGISTRATION: 'Registration No: MSVC2532',  // ← REGISTRATION NUMBER
        PHOTO: 'assets/images/doctor-photo.jpg'
    },
    
    // External Links
    LINKS: {
        GOOGLE_REVIEW: 'https://share.google/x3ZTUMJNIuf6gRY1J',
        GOOGLE_WRITE: 'https://g.page/r/CWvPKF7o8I9hEAI/review',
        JUSTDIAL: 'https://www.justdial.com/Sangli/Jai-Gurudev-Pet-Clinic-Vishrambag-Parshwanath-Colony/9999PX233-X233-181205214907-N3K4_BZDET',
        JUSTDIAL_WRITE: 'https://www.justdial.com/Sangli/Jai-Gurudev-Pet-Clinic-Vishrambag-Parshwanath-Colony/9999PX233-X233-181205214907-N3K4_BZDET/write-review',
        WHATSAPP: 'https://wa.me/8805014700',  // ← YOUR WHATSAPP
        INSTAGRAM: 'https://instagram.com/jaigurudevpetclinic'
    },
    
    SETTINGS: {
        TIMEZONE: 'Asia/Kolkata',
        CURRENCY: '₹',
        SLOT_DURATION: 30,
        MAX_DAILY_APPOINTMENTS: 50,
        BOOKING_WINDOWS: [
            { start: '09:00', end: '14:00' },
            { start: '18:00', end: '21:00' }
        ]
    }
};

// Initialize Supabase client
function initSupabase() {
    return supabase.createClient(CONFIG.SUPABASE.URL, CONFIG.SUPABASE.KEY);
}

// Resolve a staff record using auth user id first, then email as a compatibility fallback.
async function getStaffProfile(client, user) {
    let query = await client
        .from('staff')
        .select('id, role, name, email')
        .eq('id', user.id)
        .single();

    if (query.data) {
        return query;
    }

    if (!user.email) {
        return query;
    }

    return client
        .from('staff')
        .select('id, role, name, email')
        .eq('email', user.email)
        .single();
}

// Optional login-time sync so legacy staff rows keyed by email can be migrated to auth user ids.
async function syncStaffIdentity(client, user) {
    if (!user?.id || !user?.email) {
        return { data: null, error: null };
    }

    return client.rpc('sync_staff_identity', {
        p_user_id: user.id,
        p_email: user.email
    });
}

function getDefaultBookingSettings() {
    return {
        slotDuration: CONFIG.SETTINGS.SLOT_DURATION,
        bookingWindows: [...CONFIG.SETTINGS.BOOKING_WINDOWS]
    };
}

function timeToMinutes(value) {
    const [hours, minutes] = String(value || '00:00').split(':').map(Number);
    return (hours * 60) + minutes;
}

function minutesToTime(totalMinutes) {
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function normalizeBookingWindows(windows) {
    return (windows || [])
        .filter((window) => window?.start && window?.end)
        .map((window) => ({
            start: String(window.start).slice(0, 5),
            end: String(window.end).slice(0, 5)
        }))
        .filter((window) => timeToMinutes(window.end) > timeToMinutes(window.start))
        .sort((a, b) => timeToMinutes(a.start) - timeToMinutes(b.start));
}

function buildBookingSlots(settings) {
    const slotDuration = Number(settings?.slotDuration) || CONFIG.SETTINGS.SLOT_DURATION;
    const windows = normalizeBookingWindows(settings?.bookingWindows || CONFIG.SETTINGS.BOOKING_WINDOWS);
    const slots = [];

    windows.forEach((window) => {
        for (let time = timeToMinutes(window.start); time < timeToMinutes(window.end); time += slotDuration) {
            slots.push(minutesToTime(time));
        }
    });

    return slots;
}

function formatBookingWindows(windows) {
    return normalizeBookingWindows(windows)
        .map((window) => `${window.start}-${window.end}`)
        .join('\n');
}

function parseBookingWindowsInput(value) {
    return normalizeBookingWindows(
        String(value || '')
            .split('\n')
            .map((line) => line.trim())
            .filter(Boolean)
            .map((line) => {
                const [start, end] = line.split('-').map((part) => part?.trim());
                return { start, end };
            })
    );
}

async function fetchBookingSettings(client) {
    const fallback = getDefaultBookingSettings();
    const { data, error } = await client.rpc('get_booking_settings');

    if (error || !data) {
        return fallback;
    }

    const record = Array.isArray(data) ? data[0] : data;
    return {
        slotDuration: Number(record.slot_duration) || fallback.slotDuration,
        bookingWindows: normalizeBookingWindows(record.booking_windows || fallback.bookingWindows)
    };
}

async function saveBookingSettings(client, settings) {
    return client.rpc('upsert_booking_settings', {
        p_slot_duration: Number(settings.slotDuration),
        p_booking_windows: normalizeBookingWindows(settings.bookingWindows)
    });
}

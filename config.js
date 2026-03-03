// ==========================================
// JAI GURUDEV PET CLINIC - CONFIGURATION
// UPDATE ALL VALUES BELOW BEFORE DEPLOYING
// ==========================================

const CONFIG = {
    // Supabase credentials (from Project Settings → API)
    SUPABASE: {
        URL: 'https://npazmhtqxqbrfrhqidvf.supabase.co',  // ← YOUR URL
        KEY: 'sb_publishable_tdAk5dgvm67xA1JXHGx2Bw_AO49IIyl'                       // ← YOUR ANON KEY
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
        WHATSAPP: 'https://wa.me/8805014700'  // ← YOUR WHATSAPP
    },
    
    SETTINGS: {
        TIMEZONE: 'Asia/Kolkata',
        CURRENCY: '₹',
        SLOT_DURATION: 30,
        MAX_DAILY_APPOINTMENTS: 50
    }
};

// Initialize Supabase client
function initSupabase() {
    return supabase.createClient(CONFIG.SUPABASE.URL, CONFIG.SUPABASE.KEY);
}
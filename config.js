// =====================================================================
//  EFALP Nurseries – Plant Management App · CONFIGURATION
//  Fill in the 2 values below (see SETUP_GUIDE.md), then commit.
//  Both values are safe to be public: the database only lets approved,
//  signed-in staff see or change data.
// =====================================================================
window.EFALP_CONFIG = {
  // Supabase → Project Settings → API (or "Connect") → Project URL
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",

  // Supabase → Project Settings → API Keys → "anon public" key  (or the "publishable" key)
  supabaseKey: "PASTE-YOUR-ANON-OR-PUBLISHABLE-KEY-HERE",

  // How often (seconds) the app checks for changes made by other users
  refreshSeconds: 5
};

import { createClient } from '@supabase/supabase-js'

// Publishable keys are designed for browser use. Never put a service_role or
// sb_secret key in this file. Access to data must be protected with RLS.
const url =
  (import.meta.env.VITE_SUPABASE_URL as string | undefined) ??
  'https://mvezbjpnofwlerouzayj.supabase.co'

const key =
  (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined) ??
  'sb_publishable_-xMLhkUrmUum0PSNlDoh3g_pKUjBJyR'

export const isSupabaseConfigured = Boolean(url && key)

export const supabase = isSupabaseConfigured
  ? createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null

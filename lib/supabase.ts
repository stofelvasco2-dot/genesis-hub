import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// Initialize only if URL is provided, else it will be null and the app falls back to local state
export const supabase = supabaseUrl ? createClient(supabaseUrl, supabaseAnonKey) : null;

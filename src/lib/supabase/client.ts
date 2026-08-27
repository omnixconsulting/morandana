import { createClient } from "@supabase/supabase-js";

// Browser/client Supabase instance. Uses the public anon key — safe to expose,
// access is governed by Row Level Security policies (see supabase/migrations).
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  // Fail loud in dev; the landing still renders since nothing imports this yet.
  console.warn(
    "[supabase] Falta NEXT_PUBLIC_SUPABASE_URL o NEXT_PUBLIC_SUPABASE_ANON_KEY (ver .env.local.example)",
  );
}

export const supabase = createClient(url ?? "", anonKey ?? "");

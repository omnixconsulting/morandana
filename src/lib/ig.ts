import { createClient } from "@supabase/supabase-js";

export type IgPost = { image_url: string; post_url: string | null };

/**
 * Lee el feed curado de Instagram desde Supabase (tabla ig_posts).
 * Devuelve null si no hay env configurado o si la consulta falla, para que la
 * página caiga al grid estático sin romperse.
 */
export async function getIgPosts(): Promise<IgPost[] | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;

  try {
    const sb = createClient(url, key);
    const { data, error } = await sb
      .from("ig_posts")
      .select("image_url, post_url")
      .eq("is_active", true)
      .order("sort_order", { ascending: true });
    if (error || !data) return null;
    return data as IgPost[];
  } catch {
    return null;
  }
}

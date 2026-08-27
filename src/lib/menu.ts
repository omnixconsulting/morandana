import { createClient } from "@supabase/supabase-js";

export type MenuItem = {
  name: string;
  desc: string;
  price: string;
  img: string | null;
  imgPosition?: string;
};
export type Menu = { am: MenuItem[]; pm: MenuItem[]; bebidas: MenuItem[] };

type Cat = "am" | "pm" | "bebidas";

/**
 * Lee el menú desde Supabase (tabla menu_items), agrupado por categoría y
 * ordenado por sort_order. Devuelve null (para caer al menú estático) si falta
 * env, la consulta falla, o alguna categoría queda vacía.
 */
export async function getMenu(): Promise<Menu | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;

  try {
    const sb = createClient(url, key);
    const { data, error } = await sb
      .from("menu_items")
      .select("category, name, description, price, image_path, img_position, sort_order")
      .eq("is_active", true)
      .order("sort_order", { ascending: true });
    if (error || !data || data.length === 0) return null;

    const menu: Menu = { am: [], pm: [], bebidas: [] };
    for (const row of data) {
      const cat = row.category as Cat;
      if (!menu[cat]) continue;
      menu[cat].push({
        name: row.name,
        desc: row.description ?? "",
        price: row.price,
        img: row.image_path ?? null,
        imgPosition: row.img_position ?? undefined,
      });
    }
    if (!menu.am.length || !menu.pm.length || !menu.bebidas.length) return null;
    return menu;
  } catch {
    return null;
  }
}

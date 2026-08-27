-- Semilla del feed con las 6 fotos curadas actuales (rutas en /public), para
-- que el grid no quede vacío tras el push. Reemplazar con posts reales
-- (subir foto al bucket 'ig' y actualizar image_url + post_url).

delete from public.ig_posts;

insert into public.ig_posts (image_url, post_url, sort_order) values
  ('/img/foto-chilaquiles.jpg', 'https://www.instagram.com/morandanamx', 1),
  ('/img/hero-brindis.jpg',     'https://www.instagram.com/morandanamx', 2),
  ('/img/menu/beb-006.jpg',     'https://www.instagram.com/morandanamx', 3),
  ('/img/foto-cafe.jpg',        'https://www.instagram.com/morandanamx', 4),
  ('/img/menu/pm-008.jpg',      'https://www.instagram.com/morandanamx', 5),
  ('/img/menu/am-018.jpg',      'https://www.instagram.com/morandanamx', 6);

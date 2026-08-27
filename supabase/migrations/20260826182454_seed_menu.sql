-- Morandana — datos iniciales del menú (mismo contenido que el landing).
-- Idempotente: limpia y recarga el catálogo base.

delete from public.menu_items;

insert into public.menu_items (category, name, description, price, image_path, img_position, sort_order) values
  -- A.M.
  ('am', 'Chilaquiles Morandana', 'Totopo en salsa a elegir, frijoles negros, queso, crema, aguacate', '$150', '/img/menu/am-000.jpg', null, 1),
  ('am', 'French Toast', 'Pan brioche con azúcar, canela y frutos rojos del bosque', '$160', '/img/menu/am-018.jpg', null, 2),
  ('am', 'Waffles Morandana', 'Tres waffles con huevo, aguacate, tocino crujiente y miel de maple', '$160', '/img/menu/am-008.jpg', null, 3),
  ('am', 'Avo Toast', 'Masa madre, aguacate, pesto, huevo y queso parmesano', '$160', '/img/menu/am-002.jpg', null, 4),
  ('am', 'Bowl de Fruta', 'Yogurt griego, fresa, moras, frambuesa, granola y miel de abeja', '$135', '/img/menu/am-014.jpg', null, 5),
  -- P.M.
  ('pm', 'Comida del Día', '1 guiso + 2 guarniciones + agua fresca a elegir', '$190', '/img/menu/pm-006.jpg', null, 1),
  ('pm', 'Sopa Morandana', 'Caldo de tomate, pollo, queso panela, aguacate y tiras de tortilla', '$145', '/img/menu/pm-004.jpg', null, 2),
  ('pm', 'Enmoladas', 'Pollo en mole negro con ajonjolí y crema ácida', '$160', '/img/menu/pm-002.jpg', null, 3),
  ('pm', 'Panini de Pollo', 'Pollo búfalo, queso, tomate, lechugas, mayonesa y papas fritas', '$185', '/img/menu/pm-010.jpg', null, 4),
  ('pm', 'Crepas', 'Nutella y fresas · Dulce de leche y plátano · Jamón y queso', 'desde $90', '/img/menu/pm-008.jpg', null, 5),
  -- Bebidas
  ('bebidas', 'Matcha', 'Matcha japonés con leche cremosa, frío o caliente', '$67', '/img/menu/beb-006.jpg', 'top', 1),
  ('bebidas', 'Latte', 'Espresso doble con leche vaporizada al gusto', 'desde $66', '/img/menu/beb-004.jpg', 'top', 2),
  ('bebidas', 'Dirty Chai', 'Chai especiado con un shot de espresso', '$68', '/img/menu/beb-002.jpg', 'top', 3),
  ('bebidas', 'Jugos Cold Press', 'Verde · Rojo · Tropical · Energía — prensados en frío', '$68', '/img/menu/beb-008.jpg', 'top', 4),
  ('bebidas', 'Tisana Frutos Rojos', 'Infusión de frutos del bosque, fría o caliente', '$70', '/img/menu/beb-tisana.jpg', 'top', 5);

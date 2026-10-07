insert into public.routine_template_categories (id, slug, name_fr, name_en, icon, sort_order, is_active)
values
    ('10000000-0000-0000-0000-000000000001', 'going_out', 'Sortir', 'Going out', 'figure.walk', 10, true),
    ('10000000-0000-0000-0000-000000000002', 'health', 'Santé', 'Health', 'cross.case', 20, true),
    ('10000000-0000-0000-0000-000000000003', 'work', 'Travail', 'Work', 'briefcase', 30, true),
    ('10000000-0000-0000-0000-000000000004', 'study', 'Études', 'Study', 'book', 40, true),
    ('10000000-0000-0000-0000-000000000005', 'daily', 'Quotidien', 'Daily', 'sun.max', 50, true)
on conflict (slug) do update set
    name_fr = excluded.name_fr,
    name_en = excluded.name_en,
    icon = excluded.icon,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now();

insert into public.routine_templates (id, category_id, slug, name_fr, name_en, description_fr, description_en, icon, default_margin_seconds, sort_order, is_active)
values
    ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'restaurant', 'Se préparer pour sortir', 'Get ready to go out', 'Une préparation simple avant de partir.', 'A simple preparation before heading out.', 'figure.walk', 300, 10, true),
    ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'gym', 'Se préparer pour le sport', 'Get ready for the gym', 'Préparer le nécessaire et partir sans friction.', 'Prepare what you need and leave without friction.', 'figure.run', 300, 20, true),
    ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'medical_appointment', 'Se préparer pour un rendez-vous médical', 'Prepare for a medical appointment', 'Avoir les documents et les affaires utiles.', 'Gather the documents and items you need.', 'cross.case', 600, 30, true),
    ('20000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', 'airport', 'Se préparer pour l''aéroport', 'Get ready for the airport', 'Vérifier l''essentiel et partir à temps.', 'Check the essentials and leave on time.', 'airplane', 900, 40, true),
    ('20000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000003', 'start_work', 'Commencer le travail', 'Start work', 'Passer du mode veille au premier geste utile.', 'Move from idle to the first useful action.', 'briefcase', 300, 50, true),
    ('20000000-0000-0000-0000-000000000006', '10000000-0000-0000-0000-000000000004', 'study', 'Se préparer à étudier', 'Get ready to study', 'Installer le contexte et commencer petit.', 'Set up the context and start small.', 'book', 300, 60, true),
    ('20000000-0000-0000-0000-000000000007', '10000000-0000-0000-0000-000000000005', 'morning', 'Démarrer la journée', 'Start the day', 'Un départ doux et concret.', 'A gentle, concrete start.', 'sun.max', 300, 70, true),
    ('20000000-0000-0000-0000-000000000008', '10000000-0000-0000-0000-000000000005', 'bedtime', 'Se préparer à dormir', 'Get ready for bed', 'Fermer la journée sans tout laisser en suspens.', 'Close the day without leaving everything open.', 'moon.stars', 300, 80, true),
    ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000001', 'quick_leave', 'Sortie express', 'Quick leave', 'Le minimum concret pour sortir.', 'The concrete minimum to get out.', 'door.left.hand.open', 120, 90, true),
    ('20000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000003', 'meeting', 'Se préparer pour une réunion', 'Prepare for a meeting', 'Arriver avec le contexte nécessaire.', 'Arrive with the context you need.', 'person.2', 300, 100, true)
on conflict (slug) do update set
    category_id = excluded.category_id,
    name_fr = excluded.name_fr,
    name_en = excluded.name_en,
    description_fr = excluded.description_fr,
    description_en = excluded.description_en,
    icon = excluded.icon,
    default_margin_seconds = excluded.default_margin_seconds,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now();

insert into public.routine_template_steps (template_id, step_key, title_fr, title_en, estimated_duration_seconds, sort_order, is_optional, is_active)
select templates.id, steps.step_key, steps.title_fr, steps.title_en, steps.duration, steps.sort_order, steps.is_optional, true
from (values
    ('restaurant', 'shower', 'Douche', 'Shower', 480, 10, false), ('restaurant', 'dress', 'S''habiller', 'Get dressed', 600, 20, false), ('restaurant', 'gather', 'Préparer ses affaires', 'Gather your things', 300, 30, false), ('restaurant', 'leave', 'Partir', 'Leave', 120, 40, false),
    ('gym', 'change', 'Changer de tenue', 'Change clothes', 300, 10, false), ('gym', 'bottle', 'Remplir la gourde', 'Fill your water bottle', 120, 20, false), ('gym', 'bag', 'Préparer le sac', 'Pack your bag', 300, 30, false), ('gym', 'shoes', 'Mettre ses chaussures', 'Put on your shoes', 120, 40, false), ('gym', 'leave', 'Partir', 'Leave', 120, 50, false),
    ('medical_appointment', 'documents', 'Préparer les documents', 'Gather the documents', 300, 10, false), ('medical_appointment', 'card', 'Prendre carte et assurance', 'Take your card and insurance', 120, 20, false), ('medical_appointment', 'bag', 'Préparer les affaires', 'Pack what you need', 300, 30, false), ('medical_appointment', 'leave', 'Partir', 'Leave', 120, 40, false),
    ('airport', 'tickets', 'Vérifier billet et papiers', 'Check your ticket and documents', 300, 10, false), ('airport', 'bag', 'Vérifier le sac', 'Check your bag', 600, 20, false), ('airport', 'charge', 'Charger le téléphone', 'Charge your phone', 120, 30, false), ('airport', 'leave', 'Partir', 'Leave', 300, 40, false),
    ('start_work', 'water', 'Boire un verre d''eau', 'Get a glass of water', 60, 10, false), ('start_work', 'desk', 'Ouvrir le poste de travail', 'Open your workspace', 180, 20, false), ('start_work', 'first_action', 'Choisir la première action', 'Choose the first action', 120, 30, false), ('start_work', 'start', 'Commencer 5 minutes', 'Start for 5 minutes', 300, 40, false),
    ('study', 'materials', 'Sortir le matériel', 'Take out your materials', 180, 10, false), ('study', 'water', 'Prendre de l''eau', 'Get some water', 60, 20, false), ('study', 'first_task', 'Choisir un premier exercice', 'Choose one first exercise', 180, 30, false), ('study', 'start', 'Commencer 10 minutes', 'Start for 10 minutes', 600, 40, false),
    ('morning', 'wash', 'Se laver', 'Wash up', 300, 10, false), ('morning', 'dress', 'S''habiller', 'Get dressed', 600, 20, false), ('morning', 'water', 'Boire de l''eau', 'Drink some water', 60, 30, false), ('morning', 'first_action', 'Choisir la première action', 'Choose the first action', 120, 40, false),
    ('bedtime', 'tidy', 'Ranger un point', 'Tidy one thing', 180, 10, true), ('bedtime', 'wash', 'Se laver les dents', 'Brush your teeth', 180, 20, false), ('bedtime', 'clothes', 'Préparer les vêtements de demain', 'Set out tomorrow''s clothes', 300, 30, true), ('bedtime', 'bed', 'Aller au lit', 'Get into bed', 120, 40, false),
    ('quick_leave', 'keys', 'Prendre clés et téléphone', 'Take keys and phone', 60, 10, false), ('quick_leave', 'shoes', 'Mettre ses chaussures', 'Put on your shoes', 120, 20, false), ('quick_leave', 'leave', 'Partir', 'Leave', 120, 30, false),
    ('meeting', 'context', 'Relire le contexte', 'Review the context', 300, 10, false), ('meeting', 'notes', 'Noter un point à aborder', 'Note one point to discuss', 180, 20, false), ('meeting', 'link', 'Ouvrir le lien ou l''adresse', 'Open the link or address', 120, 30, false), ('meeting', 'join', 'Se connecter ou partir', 'Join or leave', 180, 40, false)
) as steps(slug, step_key, title_fr, title_en, duration, sort_order, is_optional)
join public.routine_templates templates on templates.slug = steps.slug
on conflict (template_id, step_key) do update set
    title_fr = excluded.title_fr,
    title_en = excluded.title_en,
    estimated_duration_seconds = excluded.estimated_duration_seconds,
    sort_order = excluded.sort_order,
    is_optional = excluded.is_optional,
    is_active = excluded.is_active,
    updated_at = now();

insert into public.routine_template_keywords (template_id, locale, keyword, weight)
select templates.id, keywords.locale, keywords.keyword, keywords.weight
from (values
    ('restaurant', 'fr', 'restaurant', 10), ('restaurant', 'fr', 'dîner', 8), ('restaurant', 'en', 'restaurant', 10), ('restaurant', 'en', 'dinner', 8),
    ('gym', 'fr', 'sport', 8), ('gym', 'fr', 'salle de sport', 12), ('gym', 'fr', 'gym', 10), ('gym', 'en', 'gym', 10), ('gym', 'en', 'workout', 8),
    ('medical_appointment', 'fr', 'médecin', 10), ('medical_appointment', 'fr', 'médical', 10), ('medical_appointment', 'fr', 'dentiste', 10), ('medical_appointment', 'en', 'doctor', 10), ('medical_appointment', 'en', 'dentist', 10),
    ('airport', 'fr', 'aéroport', 12), ('airport', 'fr', 'vol', 8), ('airport', 'en', 'airport', 12), ('airport', 'en', 'flight', 8),
    ('start_work', 'fr', 'travail', 8), ('start_work', 'fr', 'bureau', 8), ('start_work', 'en', 'work', 8), ('start_work', 'en', 'office', 8),
    ('study', 'fr', 'étude', 8), ('study', 'fr', 'réviser', 8), ('study', 'en', 'study', 8), ('study', 'en', 'revision', 8),
    ('morning', 'fr', 'matin', 10), ('morning', 'fr', 'réveil', 10), ('morning', 'en', 'morning', 10),
    ('bedtime', 'fr', 'coucher', 10), ('bedtime', 'fr', 'dormir', 10), ('bedtime', 'en', 'bedtime', 10),
    ('quick_leave', 'fr', 'partir', 6), ('quick_leave', 'fr', 'sortir', 8), ('quick_leave', 'en', 'leave', 8),
    ('meeting', 'fr', 'réunion', 12), ('meeting', 'fr', 'meeting', 12), ('meeting', 'en', 'meeting', 12)
) as keywords(slug, locale, keyword, weight)
join public.routine_templates templates on templates.slug = keywords.slug
on conflict (template_id, locale, keyword) do update set weight = excluded.weight;

-- Adds the cafes and restaurants to the Info tab. Run once in Supabase: SQL Editor -> New query -> paste -> Run.
insert into public.docs (collection, id, data) values
  ('directory', 'dir-manta', '{"type": "Restaurant", "name": "Manta Cafe", "phone": "+960 791-9217", "addr": "Ameenee Magu, Hanimaadhoo", "note": ""}'::jsonb),
  ('directory', 'dir-chill', '{"type": "Restaurant", "name": "Chill Time", "phone": "+960 763-0009", "addr": "Kaneeru Hingun, Hanimaadhoo", "note": ""}'::jsonb),
  ('directory', 'dir-breaktime', '{"type": "Restaurant", "name": "Break Time Cafe'' & Restaurant", "phone": "+960 944-1953", "addr": "Hanimaadhoo", "note": ""}'::jsonb),
  ('directory', 'dir-youth', '{"type": "Cafe", "name": "Youth Café", "phone": "+960 995-5505", "addr": "Hanimaadhoo", "note": ""}'::jsonb)
on conflict (collection, id) do nothing;

-- Disable RLS for development to fix "violates row-level security policy" error
-- You can run this in Supabase SQL Editor
ALTER TABLE menu_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items DISABLE ROW LEVEL SECURITY;

-- Alternatively, if you want to keep RLS enabled but allow access:
-- CREATE POLICY "Allow all access" ON menu_categories FOR ALL USING (true) WITH CHECK (true);
-- CREATE POLICY "Allow all access" ON menu_items FOR ALL USING (true) WITH CHECK (true);

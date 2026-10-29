-- Create menu_categories table
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    visual_index INT NOT NULL DEFAULT 0,
    is_visible_in_all_outlets BOOLEAN NOT NULL DEFAULT true,
    visible_outlet_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add comment to the table
COMMENT ON TABLE menu_categories IS 'Table to store menu categories for the catalog management.';

-- Enable Row Level Security (optional, depends on project requirements)
-- ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all for now (development mode)
-- CREATE POLICY "Allow all for authenticated users" ON menu_categories
--     FOR ALL USING (auth.role() = 'authenticated');

-- Function to handle updated_at
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
CREATE TRIGGER update_menu_categories_updated_at
    BEFORE UPDATE ON menu_categories
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

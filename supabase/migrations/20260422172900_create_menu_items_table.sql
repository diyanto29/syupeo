-- Create menu_items table
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- Corresponds to MenuCategory enum name
    price NUMERIC NOT NULL DEFAULT 0,
    description TEXT DEFAULT '',
    image_url TEXT,
    stock_available BOOLEAN NOT NULL DEFAULT true,
    ingredients TEXT[] DEFAULT '{}',
    recipe_cost NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add comment to the table
COMMENT ON TABLE menu_items IS 'Table to store menu items (products) for the catalog.';

-- Trigger for updated_at
CREATE TRIGGER update_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

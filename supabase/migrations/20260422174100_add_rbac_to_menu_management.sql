-- Add business_id to menu management tables
ALTER TABLE menu_categories 
ADD COLUMN business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE menu_items 
ADD COLUMN business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS menu_categories_business_id_idx ON menu_categories(business_id);
CREATE INDEX IF NOT EXISTS menu_items_business_id_idx ON menu_items(business_id);

-- Enable RLS
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- RBAC Policies for menu_categories
DROP POLICY IF EXISTS "menu_categories_select_policy" ON menu_categories;
CREATE POLICY "menu_categories_select_policy" ON menu_categories
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1 FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = menu_categories.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "menu_categories_manage_policy" ON menu_categories;
CREATE POLICY "menu_categories_manage_policy" ON menu_categories
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);

-- RBAC Policies for menu_items
DROP POLICY IF EXISTS "menu_items_select_policy" ON menu_items;
CREATE POLICY "menu_items_select_policy" ON menu_items
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1 FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = menu_items.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "menu_items_manage_policy" ON menu_items;
CREATE POLICY "menu_items_manage_policy" ON menu_items
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);

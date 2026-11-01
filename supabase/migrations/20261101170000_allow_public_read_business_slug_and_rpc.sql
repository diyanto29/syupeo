-- ==============================================================================
-- IZINKAN PENGUNJUNG PUBLIK MEMBUKA TOKO ONLINE SYUPEO BERDASARKAN SLUG
-- ==============================================================================

-- 1. Tambahkan policy publik untuk membaca data profil toko publik
DROP POLICY IF EXISTS "businesses_select_public_slug" ON public.businesses;
CREATE POLICY "businesses_select_public_slug"
ON public.businesses
FOR SELECT
TO anon, authenticated
USING (true);

-- 2. RPC helper berkeamanan tinggi (SECURITY DEFINER) untuk mengambil profil toko
CREATE OR REPLACE FUNCTION public.get_public_store_by_slug(p_slug text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'id', b.id,
    'name', b.name,
    'slug', b.slug,
    'phone', b.phone,
    'address', b.address,
    'logo_url', b.logo_url,
    'banner_url', b.banner_url,
    'business_type', b.business_type,
    'district', b.district,
    'regency', b.regency,
    'province', b.province
  ) INTO v_result
  FROM public.businesses b
  WHERE b.slug = p_slug
  LIMIT 1;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_store_by_slug(text) TO anon, authenticated;


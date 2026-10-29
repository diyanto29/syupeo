import { getKosankuAdminSupabase } from '@/lib/supabase/kosankuServer';
import KosankuDashboardView, {
  KosankuProperty,
  KosankuRoom,
  KosankuTenant,
  KosankuBill,
  KosankuLicense,
  KosankuPackage,
} from './KosankuDashboardView';

export const dynamic = 'force-dynamic';

export default async function KosankuDashboardPage() {
  let dbConnected = false;
  let dbError: string | null = null;
  let properties: KosankuProperty[] = [];
  let rooms: KosankuRoom[] = [];
  let tenants: KosankuTenant[] = [];
  let bills: KosankuBill[] = [];
  let licenses: KosankuLicense[] = [];
  let packages: KosankuPackage[] = [];
  let authUsers: { id: string; email: string }[] = [];

  try {
    const supabase = getKosankuAdminSupabase();

    // 1. Fetch Subscription Packages
    try {
      const { data: pkgsData, error: pkgsError } = await supabase
        .from('subscription_packages')
        .select('*')
        .order('sort_order', { ascending: true });
      if (!pkgsError && pkgsData) {
        packages = pkgsData as KosankuPackage[];
      }
    } catch (_) {}

    // 2. Fetch Properties
    const { data: propsData, error: propsError } = await supabase
      .from('properties')
      .select('*')
      .order('created_at', { ascending: false });

    if (propsError) {
      dbError = `Gagal memuat properti: ${propsError.message}`;
    } else {
      dbConnected = true;
      properties = (propsData as KosankuProperty[]) || [];
    }

    // 3. Fetch Rooms
    const { data: roomsData } = await supabase
      .from('rooms')
      .select('*')
      .order('room_number', { ascending: true });
    rooms = (roomsData as KosankuRoom[]) || [];

    // 4. Fetch Tenants
    const { data: tenantsData } = await supabase
      .from('tenants')
      .select('*')
      .order('name', { ascending: true });
    tenants = (tenantsData as KosankuTenant[]) || [];

    // 5. Fetch Bills
    const { data: billsData } = await supabase
      .from('bills')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50);
    bills = (billsData as KosankuBill[]) || [];

    // 6. Fetch Licenses
    const { data: licensesData } = await supabase
      .from('user_licenses')
      .select('*')
      .order('created_at', { ascending: false });
    licenses = (licensesData as KosankuLicense[]) || [];

    // 7. Fetch Auth Users (Emails Juragan)
    try {
      const { data: usersData } = await supabase.auth.admin.listUsers();
      if (usersData?.users) {
        authUsers = usersData.users.map((u) => ({
          id: u.id,
          email: u.email || '',
        }));
      }
    } catch (_) {}

  } catch (err: any) {
    dbError = err.message || 'Gagal terhubung ke Supabase KosanKu';
  }

  return (
    <KosankuDashboardView
      properties={properties}
      rooms={rooms}
      tenants={tenants}
      bills={bills}
      licenses={licenses}
      packages={packages}
      authUsers={authUsers}
      dbConnected={dbConnected}
      dbError={dbError}
    />
  );
}

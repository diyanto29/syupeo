export interface BusinessTypeTemplate {
  id: string;
  name: string;
  code: string;
  description?: string | null;
  icon_name?: string | null;
  default_enabled_features: string[];
  features_config?: Record<string, 'off' | 'free' | 'pro' | string>;
  limits_config?: {
    free?: {
      max_transactions?: number;
      max_products?: number;
      max_outlets?: number;
    };
    pro?: {
      max_transactions?: number;
      max_products?: number;
      max_outlets?: number;
    };
    [key: string]: any;
  };
  role_labels?: Record<string, string>;
  max_transactions?: number;
  max_products?: number;
  max_outlets?: number;
  show_ads?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface SubscriptionPlan {
  id: string;
  name: string;
  code: string; // 'free' | 'pro'
  max_transactions_month: number;
  max_products: number;
  max_outlets: number;
  price_monthly: number;
  pricing_tiers?: Record<string, number>;
  features?: Record<string, boolean>;
  created_at?: string;
  updated_at?: string;
}

export interface Business {
  id: string;
  name: string;
  slug?: string | null;
  business_type?: string | null;
  owner_user_id: string;
  status?: string | null;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  plan_id?: string | null;
  subscription_status?: string | null;
  subscription_end_at?: string | null;
  max_transactions?: number;
  max_products?: number;
  max_outlets?: number;
  show_ads?: boolean;
  enabled_features?: string[];
  features_config?: Record<string, string>;
  limits_config?: Record<string, any>;
  role_labels?: Record<string, string>;
  referred_by_partner_id?: string | null;
  created_at?: string;
  updated_at?: string;
  profiles?: {
    id: string;
    full_name?: string | null;
    email?: string | null;
    phone?: string | null;
  } | null;
  subscription_plans?: SubscriptionPlan | null;
  partners?: Partner | null;
}

export interface Partner {
  id: string;
  name: string;
  phone?: string | null;
  email?: string | null;
  referral_code?: string | null;
  commission_rate: number; // e.g. 20 (percent)
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  status: 'active' | 'inactive';
  notes?: string | null;
  created_at?: string;
  updated_at?: string;
  // Computed stats for UI
  total_earned?: number;
  total_withdrawn?: number;
  current_balance?: number;
  client_count?: number;
}

export interface SubscriptionHistory {
  id: string;
  business_id: string;
  plan_id?: string | null;
  action_type: 'trial' | 'new' | 'renewal' | 'upgrade' | 'manual_admin';
  duration_type: 'days' | 'months' | 'lifetime';
  duration_value: number;
  price_paid: number;
  started_at?: string;
  ended_at?: string | null;
  partner_id?: string | null;
  commission_rate: number;
  commission_amount: number;
  payment_status: 'paid' | 'free_trial' | 'waived';
  payment_method?: string | null;
  notes?: string | null;
  created_by_admin?: string | null;
  created_at: string;
  // Joins
  businesses?: {
    id: string;
    name: string;
    subscription_status?: string | null;
    profiles?: {
      full_name?: string | null;
      email?: string | null;
      phone?: string | null;
    } | null;
  } | null;
  subscription_plans?: SubscriptionPlan | null;
  partners?: Partner | null;
}

export interface PartnerCommission {
  id: string;
  partner_id: string;
  business_id: string;
  subscription_history_id?: string | null;
  subscription_amount: number;
  commission_rate: number;
  commission_amount: number;
  description?: string | null;
  status: 'earned' | 'cancelled';
  created_at: string;
  businesses?: {
    id: string;
    name: string;
  } | null;
  partners?: Partner | null;
}

export interface PartnerPayout {
  id: string;
  partner_id: string;
  amount: number;
  bank_name?: string | null;
  bank_account_number?: string | null;
  bank_account_holder?: string | null;
  status: 'completed' | 'pending' | 'rejected';
  reference_note?: string | null;
  proof_url?: string | null;
  processed_by?: string | null;
  processed_at?: string;
  created_at: string;
  partners?: Partner | null;
}

export interface Profile {
  id: string;
  email?: string | null;
  full_name?: string | null;
  role?: string | null;
  avatar_url?: string | null;
  created_at?: string;
}

export interface AdminUser {
  id: string;
  email: string;
  name?: string | null;
  role: 'super_admin' | 'admin' | 'partner';
  is_active: boolean;
  can_manage_licenses?: boolean;
  partner_id?: string | null;
  partners?: Partner | null;
  created_at: string;
  updated_at: string;
}

export interface MasterCatalogItem {
  id: string;
  barcode?: string | null;
  name: string;
  category?: string | null;
  brand?: string | null;
  base_price: number;
  selling_price: number;
  unit?: string | null;
  created_at?: string;
}

export interface OrderPayment {
  id: string;
  method_name: string;
  method_type: string;
  amount: number;
}

export interface Order {
  id: string;
  outlet_id: string;
  business_id: string;
  invoice_number: string;
  customer_name?: string | null;
  customer_phone?: string | null;
  table_number?: number | null;
  status: 'draft' | 'confirmed' | 'paid' | 'void' | 'refunded';
  notes?: string | null;
  void_reason?: string | null;
  subtotal: number;
  discount_total: number;
  tax_amount: number;
  grand_total: number;
  total_amount?: number;
  paid_amount: number;
  change_amount: number;
  payment_method?: string | null;
  created_at: string;
  paid_at?: string | null;
  businesses?: {
    id: string;
    name: string;
  } | null;
  outlets?: {
    id: string;
    name: string;
  } | null;
  order_payments?: OrderPayment[];
}

export type LeadStatus = 'new' | 'contacted' | 'demo' | 'quoted' | 'won' | 'lost';

export interface Lead {
  id: string;
  partner_id?: string | null;
  business_name: string;
  contact_name?: string | null;
  phone?: string | null;
  email?: string | null;
  city?: string | null;
  business_type: string; // 'fnb' | 'retail' | 'service' | 'other'
  status: LeadStatus;
  estimated_deal_value: number;
  notes?: string | null;
  lost_reason?: string | null;
  converted_business_id?: string | null;
  created_by?: string | null;
  created_at: string;
  updated_at: string;
  // Joins
  partners?: Partner | null;
  converted_business?: Business | null;
  lead_activities?: LeadActivity[];
}

export interface LeadActivity {
  id: string;
  lead_id: string;
  partner_id?: string | null;
  activity_type: 'whatsapp' | 'call' | 'meeting' | 'demo' | 'note';
  notes: string;
  created_at: string;
  partners?: Partner | null;
}

export interface QuotationItem {
  description: string;
  qty: number;
  unit_price: number;
  total_price: number;
}

export interface Quotation {
  id: string;
  lead_id?: string | null;
  partner_id?: string | null;
  quote_number: string;
  client_name: string;
  client_business_name: string;
  client_phone?: string | null;
  items: QuotationItem[];
  subtotal: number;
  discount_amount: number;
  final_amount: number;
  valid_until?: string | null;
  status: 'draft' | 'sent' | 'accepted' | 'rejected' | 'expired';
  notes?: string | null;
  created_at: string;
  updated_at: string;
  // Joins
  leads?: Lead | null;
  partners?: Partner | null;
}

export interface CashShift {
  id: string;
  business_id: string;
  outlet_id: string;
  cashier_id?: string | null;
  cashier_name?: string | null;
  shift_name?: string | null;
  starting_cash: number;
  expected_cash?: number | null;
  expected_ending_cash?: number | null;
  actual_cash?: number | null;
  actual_ending_cash?: number | null;
  difference_amount?: number | null;
  difference?: number | null;
  total_sales_cash?: number | null;
  total_cash_in?: number | null;
  total_cash_out?: number | null;
  status: 'open' | 'closed';
  notes?: string | null;
  opened_at: string;
  closed_at?: string | null;
  created_at: string;
  updated_at: string;
  // Joins
  businesses?: {
    id: string;
    name: string;
  } | null;
  outlets?: {
    id: string;
    name: string;
  } | null;
}

export interface CashFlowEntry {
  id: string;
  business_id: string;
  outlet_id: string;
  shift_id?: string | null;
  user_id: string;
  user_name?: string | null;
  type: 'in' | 'out';
  category: string;
  amount: number;
  payment_source: string;
  notes?: string | null;
  created_at: string;
  // Joins
  businesses?: {
    id: string;
    name: string;
  } | null;
  outlets?: {
    id: string;
    name: string;
  } | null;
}

export interface HardwarePackage {
  id: string;
  name: string;
  slug?: string;
  badge?: string;
  price: number;
  original_price?: number;
  description?: string;
  suitable_for?: string;
  items_included: string[];
  is_popular?: boolean;
  is_active: boolean;
  sort_order: number;
  created_at?: string;
  updated_at?: string;
}

export interface Outlet {
  id: string;
  business_id: string;
  name: string;
  code?: string | null;
  phone?: string | null;
  address?: string | null;
  is_active: boolean;
  created_at?: string;
}

export interface Category {
  id: string;
  business_id: string;
  name: string;
  icon?: string | null;
  sort_order?: number;
  created_at?: string;
}

export interface MenuItemVariant {
  id?: string;
  menu_item_id?: string;
  business_id?: string | null;
  name: string;
  price: number;
  sku?: string | null;
  barcode?: string | null;
  stock_available?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface MenuItemTieredPrice {
  id?: string;
  menu_item_id?: string;
  business_id?: string | null;
  min_quantity: number;
  price: number;
  created_at?: string;
  updated_at?: string;
}

export interface MenuItem {
  id: string;
  business_id: string;
  category_id?: string | null;
  name: string;
  price: number;
  cost_price?: number;
  recipe_cost?: number;
  sku?: string | null;
  barcode?: string | null;
  image_url?: string | null;
  is_active?: boolean;
  stock_available?: boolean;
  track_stock_quantity?: boolean;
  stock_quantity?: number;
  stock?: number;
  unit?: string | null;
  description?: string | null;
  created_at?: string;
  menu_categories?: {
    id: string;
    name: string;
  } | null;
  categories?: {
    id: string;
    name: string;
  } | null;
  menu_item_variants?: MenuItemVariant[];
  menu_item_tiered_prices?: MenuItemTieredPrice[];
}

export interface OrderItem {
  id: string;
  order_id: string;
  menu_item_id?: string | null;
  name: string;
  unit_price: number;
  price?: number;
  quantity: number;
  subtotal: number;
  cost_price?: number;
  variant_name?: string | null;
  discount_applied?: number;
  notes?: string | null;
}

export interface Discount {
  id: string;
  business_id: string;
  name: string;
  code?: string | null;
  description?: string | null;
  type: 'percentage' | 'fixed_amount';
  percentage_value?: number | null;
  amount_value?: number | null;
  max_discount_amount?: number | null;
  is_active: boolean;
  starts_at?: string | null;
  ends_at?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface Customer {
  id: string;
  business_id: string;
  name: string;
  phone: string;
  address?: string | null;
  credit_limit: number;
  current_debt: number;
  notes?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface CustomerDebt {
  id: string;
  business_id: string;
  outlet_id: string;
  customer_id: string;
  order_id?: string | null;
  invoice_number?: string | null;
  total_amount: number;
  remaining_amount: number;
  due_date?: string | null;
  status: 'unpaid' | 'partially_paid' | 'paid' | 'bad_debt';
  notes?: string | null;
  created_at: string;
  updated_at?: string;
  customers?: Customer | null;
  outlets?: Outlet | null;
}

export interface DebtPayment {
  id: string;
  debt_id: string;
  customer_id: string;
  outlet_id: string;
  amount_paid: number;
  payment_method: 'cash' | 'transfer' | 'qris';
  notes?: string | null;
  created_at: string;
  customer_debts?: CustomerDebt | null;
}

export interface InventoryIngredient {
  id: string;
  business_id: string;
  outlet_id?: string | null;
  sku?: string | null;
  name: string;
  category?: string | null;
  base_unit: string;
  purchase_unit?: string | null;
  conversion_ratio?: number;
  current_stock: number;
  min_stock_alert: number;
  cost_per_base_unit: number;
  storage_type?: 'dry' | 'chilled' | 'frozen';
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface BusinessMember {
  id: string;
  business_id: string;
  user_id: string;
  role: 'owner' | 'admin' | 'cashier' | 'waiter' | 'kitchen';
  status: 'active' | 'invited' | 'disabled';
  created_at: string;
  updated_at: string;
  profiles?: Profile | null;
}

export interface MenuItemRecipe {
  id: string;
  business_id: string;
  menu_item_id: string;
  ingredient_id: string;
  variant_id?: string | null;
  modifier_option_id?: string | null;
  quantity_required: number;
  unit: string;
  notes?: string | null;
  created_at?: string;
  inventory_ingredients?: InventoryIngredient | null;
}

export interface StockOpnameSession {
  id: string;
  business_id: string;
  outlet_id: string;
  session_number: string;
  status: 'draft' | 'in_progress' | 'completed' | 'cancelled';
  opname_type: 'daily_closing' | 'weekly' | 'full_monthly';
  notes?: string | null;
  total_system_value: number;
  total_physical_value: number;
  total_discrepancy_value: number;
  started_at: string;
  completed_at?: string | null;
  conducted_by?: string | null;
  approved_by?: string | null;
  created_at?: string;
  stock_opname_items?: StockOpnameItem[];
}

export interface StockOpnameItem {
  id: string;
  session_id: string;
  ingredient_id?: string | null;
  menu_item_id?: string | null;
  item_name: string;
  storage_location?: string;
  unit: string;
  system_stock: number;
  physical_stock: number;
  discrepancy_quantity: number;
  unit_cost: number;
  discrepancy_value: number;
  discrepancy_reason?: string | null;
  notes?: string | null;
  counted_at?: string;
}



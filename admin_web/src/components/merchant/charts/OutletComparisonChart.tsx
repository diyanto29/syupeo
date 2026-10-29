'use client';

import React from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts';

interface OutletPoint {
  name: string;
  revenue: number;
  orders: number;
}

interface OutletComparisonChartProps {
  data: OutletPoint[];
}

const formatRupiah = (val: number) => {
  if (val >= 1000000) {
    return `${(val / 1000000).toFixed(1)} jt`;
  }
  if (val >= 1000) {
    return `${(val / 1000).toFixed(0)} rb`;
  }
  return `${val}`;
};

const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    const item: OutletPoint = payload[0].payload;
    return (
      <div className="bg-slate-900 text-white p-3 rounded-xl shadow-xl border border-slate-800 text-xs space-y-1">
        <p className="font-bold text-slate-300">{item.name}</p>
        <p className="text-sm font-black text-orange-400">
          {new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0,
          }).format(item.revenue)}
        </p>
        <p className="text-[11px] text-slate-400">{item.orders} pesanan</p>
      </div>
    );
  }
  return null;
};

export default function OutletComparisonChart({ data }: OutletComparisonChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 text-xs">
        Belum ada data perbandingan outlet di periode ini.
      </div>
    );
  }

  return (
    <div className="w-full h-72">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 15, right: 10, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
          <XAxis dataKey="name" stroke="#94a3b8" fontSize={11} tickLine={false} axisLine={false} />
          <YAxis stroke="#94a3b8" fontSize={10} tickLine={false} axisLine={false} tickFormatter={formatRupiah} width={65} />
          <Tooltip content={<CustomTooltip />} />
          <Bar name="Omzet Outlet" dataKey="revenue" fill="#f97316" radius={[6, 6, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

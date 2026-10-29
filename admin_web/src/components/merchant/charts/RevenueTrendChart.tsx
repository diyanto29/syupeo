'use client';

import React from 'react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts';

interface DataPoint {
  label: string;
  revenue: number;
  orderCount: number;
}

interface RevenueTrendChartProps {
  data: DataPoint[];
  title?: string;
  isHourly?: boolean;
}

const formatRupiah = (val: number) => {
  if (val >= 1000000) {
    return `Rp ${(val / 1000000).toFixed(1)} jt`;
  }
  if (val >= 1000) {
    return `Rp ${(val / 1000).toFixed(0)} rb`;
  }
  return `Rp ${val}`;
};

const CustomTooltip = ({ active, payload, label }: any) => {
  if (active && payload && payload.length) {
    const data: DataPoint = payload[0].payload;
    return (
      <div className="bg-slate-900 text-white p-3 rounded-xl shadow-xl border border-slate-800 text-xs space-y-1">
        <p className="font-bold text-slate-300">{label}</p>
        <p className="text-sm font-black text-orange-400">
          {new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0,
          }).format(data.revenue)}
        </p>
        <p className="text-[11px] text-slate-400">
          {data.orderCount} transaksi berhasil
        </p>
      </div>
    );
  }
  return null;
};

export default function RevenueTrendChart({ data, title, isHourly = false }: RevenueTrendChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 text-xs">
        Belum ada data penjualan pada periode ini.
      </div>
    );
  }

  return (
    <div className="w-full h-72">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor="#f97316" stopOpacity={0.4} />
              <stop offset="95%" stopColor="#f97316" stopOpacity={0.0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
          <XAxis
            dataKey="label"
            stroke="#94a3b8"
            fontSize={11}
            tickLine={false}
            axisLine={false}
          />
          <YAxis
            stroke="#94a3b8"
            fontSize={10}
            tickLine={false}
            axisLine={false}
            tickFormatter={formatRupiah}
            width={65}
          />
          <Tooltip content={<CustomTooltip />} />
          <Area
            type="monotone"
            dataKey="revenue"
            stroke="#ea580c"
            strokeWidth={3}
            fillOpacity={1}
            fill="url(#revenueGradient)"
            activeDot={{ r: 6, fill: '#ea580c', stroke: '#fff', strokeWidth: 2 }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

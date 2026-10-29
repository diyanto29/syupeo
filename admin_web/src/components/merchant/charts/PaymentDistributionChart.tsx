'use client';

import React from 'react';
import { ResponsiveContainer, PieChart, Pie, Cell, Tooltip, Legend } from 'recharts';

interface PaymentSlice {
  name: string;
  value: number;
  count: number;
}

interface PaymentDistributionChartProps {
  data: PaymentSlice[];
}

const COLORS: Record<string, string> = {
  qris: '#2563EB', // Blue
  cash: '#059669', // Emerald
  tunai: '#059669',
  transfer: '#7C3AED', // Purple
  debit: '#D97706', // Amber
  edc: '#EA580C', // Orange
};

const getColor = (name: string, index: number) => {
  const lower = name.toLowerCase();
  for (const [key, color] of Object.entries(COLORS)) {
    if (lower.includes(key)) return color;
  }
  const fallback = ['#2563EB', '#059669', '#7C3AED', '#EA580C', '#0891B2', '#EC4899'];
  return fallback[index % fallback.length];
};

const formatRupiah = (val: number) => {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
  }).format(val || 0);
};

const CustomTooltip = ({ active, payload }: any) => {
  if (active && payload && payload.length) {
    const item: PaymentSlice = payload[0].payload;
    return (
      <div className="bg-slate-900 text-white p-3 rounded-xl shadow-xl border border-slate-800 text-xs space-y-1">
        <p className="font-bold text-slate-300 capitalize">{item.name}</p>
        <p className="text-sm font-black text-amber-400">{formatRupiah(item.value)}</p>
        <p className="text-[11px] text-slate-400">{item.count} kali transaksi</p>
      </div>
    );
  }
  return null;
};

export default function PaymentDistributionChart({ data }: PaymentDistributionChartProps) {
  if (!data || data.length === 0 || data.every((d) => d.value === 0)) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 text-xs">
        Belum ada transaksi pembayaran di periode ini.
      </div>
    );
  }

  const total = data.reduce((acc, curr) => acc + curr.value, 0);

  return (
    <div className="w-full h-72 flex flex-col items-center justify-center">
      <ResponsiveContainer width="100%" height="85%">
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={85}
            paddingAngle={4}
            dataKey="value"
          >
            {data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={getColor(entry.name, index)} strokeWidth={2} stroke="#fff" />
            ))}
          </Pie>
          <Tooltip content={<CustomTooltip />} />
        </PieChart>
      </ResponsiveContainer>

      {/* Legend */}
      <div className="flex flex-wrap items-center justify-center gap-3 text-xs mt-1">
        {data.map((item, index) => {
          const percent = total > 0 ? ((item.value / total) * 100).toFixed(0) : 0;
          return (
            <div key={item.name} className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full"
                style={{ backgroundColor: getColor(item.name, index) }}
              />
              <span className="font-semibold text-slate-700 capitalize">
                {item.name} <span className="text-slate-400 font-normal">({percent}%)</span>
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

'use client';

import React from 'react';
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  CartesianGrid,
} from 'recharts';

interface FinancialBarPoint {
  label: string;
  gross: number;
  net: number;
  discount: number;
  tax: number;
}

interface FinancialComparisonChartProps {
  data: FinancialBarPoint[];
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
    return (
      <div className="bg-slate-900 text-white p-3 rounded-xl shadow-xl border border-slate-800 text-xs space-y-1.5">
        <p className="font-bold text-slate-300">{label}</p>
        {payload.map((item: any) => (
          <div key={item.name} className="flex items-center justify-between gap-4">
            <span className="text-slate-400 capitalize">{item.name}:</span>
            <span className="font-bold" style={{ color: item.color }}>
              {new Intl.NumberFormat('id-ID', {
                style: 'currency',
                currency: 'IDR',
                minimumFractionDigits: 0,
              }).format(item.value)}
            </span>
          </div>
        ))}
      </div>
    );
  }
  return null;
};

export default function FinancialComparisonChart({ data }: FinancialComparisonChartProps) {
  if (!data || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 text-xs">
        Belum ada data keuangan untuk ditampilkan dalam grafik.
      </div>
    );
  }

  return (
    <div className="w-full h-80">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 20, right: 10, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
          <XAxis dataKey="label" stroke="#94a3b8" fontSize={11} tickLine={false} axisLine={false} />
          <YAxis stroke="#94a3b8" fontSize={10} tickLine={false} axisLine={false} tickFormatter={formatRupiah} width={65} />
          <Tooltip content={<CustomTooltip />} />
          <Legend
            verticalAlign="top"
            height={36}
            formatter={(value) => <span className="text-xs font-semibold text-slate-700 capitalize">{value}</span>}
          />
          <Bar name="Penjualan Bersih" dataKey="net" fill="#ea580c" radius={[4, 4, 0, 0]} />
          <Bar name="Penjualan Kotor" dataKey="gross" fill="#0284c7" radius={[4, 4, 0, 0]} />
          <Bar name="Diskon" dataKey="discount" fill="#ef4444" radius={[4, 4, 0, 0]} />
          <Bar name="Pajak PB1" dataKey="tax" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

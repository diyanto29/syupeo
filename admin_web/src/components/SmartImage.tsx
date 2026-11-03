'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Package, ImageOff } from 'lucide-react';

export interface SmartImageProps extends Omit<React.ImgHTMLAttributes<HTMLImageElement>, 'src'> {
  src?: string | null;
  containerClassName?: string;
  fallbackIcon?: React.ReactNode;
  fallback?: React.ReactNode;
  showShimmer?: boolean;
}

/**
 * SmartImage — Equivalent to Flutter's CachedNetworkImage for Syupeo Admin Web
 * - Shimmer skeleton wave placeholder during network fetch
 * - Smooth fade-in transition on load
 * - Instant display if already cached in browser memory
 * - Graceful fallback on broken image or null src
 * - Native lazy loading and asynchronous decoding
 */
export function SmartImage({
  src,
  alt = '',
  className = '',
  containerClassName = '',
  fallbackIcon,
  fallback,
  showShimmer = true,
  loading = 'lazy',
  decoding = 'async',
  ...props
}: SmartImageProps) {
  const [isLoading, setIsLoading] = useState<boolean>(Boolean(src));
  const [hasError, setHasError] = useState<boolean>(false);
  const imgRef = useRef<HTMLImageElement>(null);

  // Reset state when src changes
  useEffect(() => {
    if (!src) {
      setIsLoading(false);
      setHasError(false);
      return;
    }

    setHasError(false);

    // If image is already cached in browser memory, no need to show shimmer
    if (imgRef.current && imgRef.current.complete && imgRef.current.naturalWidth > 0) {
      setIsLoading(false);
    } else {
      setIsLoading(true);
    }
  }, [src]);

  // Fallback state: empty URL or error loading
  if (!src || hasError) {
    if (fallback) {
      return <>{fallback}</>;
    }
    return (
      <div
        className={`flex items-center justify-center bg-slate-100 text-slate-400 select-none ${containerClassName || className}`}
      >
        {fallbackIcon || (
          <Package className="w-1/2 h-1/2 max-w-6 max-h-6 text-slate-300 stroke-[1.5]" />
        )}
      </div>
    );
  }

  return (
    <div className={`relative overflow-hidden ${containerClassName}`}>
      {/* Shimmer Skeleton Placeholder */}
      {showShimmer && isLoading && (
        <div className="absolute inset-0 bg-slate-100 overflow-hidden z-10">
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/60 to-transparent animate-shimmer" />
        </div>
      )}

      {/* Target Image with Fade-in */}
      <img
        ref={imgRef}
        src={src}
        alt={alt}
        loading={loading}
        decoding={decoding}
        onLoad={() => setIsLoading(false)}
        onError={() => {
          setIsLoading(false);
          setHasError(true);
        }}
        className={`transition-opacity duration-300 ease-out ${
          isLoading ? 'opacity-0' : 'opacity-100'
        } ${className}`}
        {...props}
      />
    </div>
  );
}

export default SmartImage;


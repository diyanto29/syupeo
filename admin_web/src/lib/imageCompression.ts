/**
 * Image compression utility using HTML5 Canvas
 * Runs 100% on the client browser without external libraries.
 * Scales large smartphone photos (3-15 MB) down to optimal web size (~60-150 KB)
 * while preserving high visual fidelity for POS and Web storefronts.
 */

export interface CompressImageOptions {
  maxWidth?: number;
  maxHeight?: number;
  quality?: number; // 0 to 1
  mimeType?: 'image/webp' | 'image/jpeg';
}

export interface CompressedImageResult {
  blob: Blob;
  file: File;
  dataUrl: string;
  originalSize: number;
  compressedSize: number;
  compressionRatio: number; // percentage saved, e.g. 95.4%
  width: number;
  height: number;
}

export function formatBytes(bytes: number, decimals: number = 1): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(dm))} ${sizes[i]}`;
}

export async function compressImage(
  file: File,
  options: CompressImageOptions = {}
): Promise<CompressedImageResult> {
  const {
    maxWidth = 1024,
    maxHeight = 1024,
    quality = 0.82,
    mimeType = 'image/webp',
  } = options;

  return new Promise((resolve, reject) => {
    // Validasi tipe file
    if (!file.type.startsWith('image/')) {
      return reject(new Error('File yang dipilih bukan file gambar yang valid.'));
    }

    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Gagal membaca file gambar.'));
    reader.onload = (e) => {
      const img = new Image();
      img.onerror = () => reject(new Error('Format file gambar tidak didukung atau rusak.'));
      img.onload = () => {
        let width = img.naturalWidth || img.width;
        let height = img.naturalHeight || img.height;

        // Hitung skala aspect ratio
        if (width > maxWidth || height > maxHeight) {
          if (width / height > maxWidth / maxHeight) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          } else {
            width = Math.round((width * maxHeight) / height);
            height = maxHeight;
          }
        }

        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');
        if (!ctx) {
          return reject(new Error('Canvas 2D context tidak tersedia di browser ini.'));
        }

        // Kualitas rendering canvas tinggi
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(img, 0, 0, width, height);

        // Coba kompresi ke target format (default: webp, fallback: jpeg)
        const exportMime =
          canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0
            ? mimeType
            : 'image/jpeg';

        canvas.toBlob(
          (blob) => {
            if (!blob) {
              return reject(new Error('Gagal mengompres gambar ke dalam format biner.'));
            }

            const ext = exportMime === 'image/webp' ? 'webp' : 'jpg';
            const baseName = file.name.replace(/\.[^/.]+$/, '');
            const compressedFile = new File([blob], `${baseName}.${ext}`, {
              type: exportMime,
              lastModified: Date.now(),
            });

            const dataUrl = canvas.toDataURL(exportMime, quality);
            const originalSize = file.size;

            let finalBlob = blob;
            let finalFile = compressedFile;
            let finalSize = blob.size;

            // Jika hasil re-encode justru lebih besar dari file asli (misal file asli sudah kecil)
            if (blob.size >= file.size && file.size < 500 * 1024) {
              finalBlob = file;
              finalFile = file;
              finalSize = file.size;
            }

            const savedPercentage = Math.max(
              0,
              Math.round(((originalSize - finalSize) / originalSize) * 100)
            );

            resolve({
              blob: finalBlob,
              file: finalFile,
              dataUrl,
              originalSize,
              compressedSize: finalSize,
              compressionRatio: savedPercentage,
              width,
              height,
            });
          },
          exportMime,
          quality
        );
      };

      img.src = e.target?.result as string;
    };

    reader.readAsDataURL(file);
  });
}


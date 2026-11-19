import { useState } from 'react';
import { API_URL } from '../api/client';

/**
 * The server's 480-pixel copy of a catalogue photo (backend PhotoVariants):
 * "/uploads/products/w480/abc.webp" for "/uploads/products/abc.jpg". Null
 * for anything else (a bill photo, an object URL being uploaded).
 */
export function thumbUrl(path: string): string | null {
  const match = /^(.*\/uploads\/[^/]+)\/([^/]+)\.(?:jpe?g|png|webp)$/.exec(path);
  return match ? `${match[1]}/w480/${match[2]}.webp` : null;
}

/**
 * A list's small photo: the light copy (about a tenth of the original), and
 * only once scrolled near (loading="lazy"). Falls back to the original when
 * the copy is missing, e.g. for a photo the server hasn't made copies of yet.
 */
export function Thumb({ path, alt = '' }: { path: string; alt?: string }) {
  const original = `${API_URL}${path}`;
  const copy = thumbUrl(path);
  const [src, setSrc] = useState(copy ? `${API_URL}${copy}` : original);

  return (
    <img
      src={src}
      alt={alt}
      loading="lazy"
      decoding="async"
      onError={() => {
        if (src !== original) setSrc(original);
      }}
    />
  );
}

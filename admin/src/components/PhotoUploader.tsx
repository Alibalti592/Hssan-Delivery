import { useRef, useState, type ChangeEvent } from 'react';
import { API_URL } from '../api/client';

// Mirrors PhotoUploader::MAX_SIZE_BYTES on the backend — checking here
// rejects an oversized file instantly instead of uploading it in full just
// to have the backend reject it afterwards.
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

export function PhotoUploader({
  photoUrl,
  onUpload,
  onRemove,
  uploading,
  removing,
}: {
  photoUrl: string | null;
  onUpload: (file: File) => void;
  onRemove: () => void;
  uploading: boolean;
  removing: boolean;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [sizeError, setSizeError] = useState<string | null>(null);

  function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';

    if (!file) return;

    if (file.size > MAX_UPLOAD_BYTES) {
      setSizeError('Image must be smaller than 5 MB.');
      return;
    }

    setSizeError(null);
    onUpload(file);
  }

  return (
    <div className="photo-row">
      <div className="photo-box">
        {photoUrl ? (
          <img src={`${API_URL}${photoUrl}`} alt="" />
        ) : (
          <span className="placeholder">No photo</span>
        )}
      </div>
      <div className="photo-actions">
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          style={{ display: 'none' }}
          onChange={handleFileChange}
        />
        <button
          type="button"
          className="btn ghost sm"
          disabled={uploading}
          onClick={() => inputRef.current?.click()}
        >
          {uploading ? 'Uploading…' : photoUrl ? 'Replace photo' : 'Upload photo'}
        </button>
        {photoUrl && (
          <button type="button" className="btn ghost sm" disabled={removing} onClick={onRemove}>
            {removing ? 'Removing…' : 'Remove photo'}
          </button>
        )}
        {sizeError && <p className="field-error">{sizeError}</p>}
      </div>
    </div>
  );
}

import { useRef, type ChangeEvent } from 'react';
import { API_URL } from '../api/client';

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

  function handleFileChange(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) onUpload(file);
    e.target.value = '';
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
      </div>
    </div>
  );
}

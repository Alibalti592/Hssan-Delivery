import type { ApiErrorBody } from './types';

export const API_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8000';

// Registered once by AuthProvider so a 401 on any authenticated request
// (the cookie expired or was revoked mid-session, not just the initial
// mount check) clears local auth state and sends the user back to
// /login — instead of leaving stale UI up while every request from then
// on silently fails.
type UnauthorizedHandler = () => void;
let unauthorizedHandler: UnauthorizedHandler | null = null;

export function setUnauthorizedHandler(handler: UnauthorizedHandler | null): void {
  unauthorizedHandler = handler;
}

// These never trigger the global handler: a failed login attempt's 401 is
// normal form validation (the user is on /login already, nothing to
// redirect from), and the initial /me check on mount is how AuthContext
// discovers there's no session yet — both are already handled directly by
// AuthContext, not by "the session we thought we had just expired".
const EXCLUDED_FROM_GLOBAL_401_HANDLING = new Set(['/api/auth/login', '/api/auth/me']);

export class ApiError extends Error {
  status: number;
  fieldErrors: { field: string; message: string }[];

  constructor(
    message: string,
    status: number,
    fieldErrors: { field: string; message: string }[] = [],
  ) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.fieldErrors = fieldErrors;
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  // FormData bodies (photo uploads) must NOT get a Content-Type here: the
  // browser sets multipart/form-data with the correct boundary itself, and
  // only when it's the one adding the header.
  const isFormData = options.body instanceof FormData;

  const headers: Record<string, string> = {
    ...(options.body && !isFormData ? { 'Content-Type': 'application/json' } : {}),
    // Tells the backend's login handler this is a browser client so it can
    // strip the JWT from the login response body — the httpOnly cookie that
    // same response sets is all we need, and never holding the token in JS
    // is the whole point of the cookie migration (see WebLoginResponseSanitizer
    // on the backend). Harmless to send on every request, not just login.
    'X-Client-Platform': 'web',
  };

  // Auth is an httpOnly cookie the backend sets on login (see
  // lexik_jwt_authentication.yaml) — JS never holds the token itself, so
  // there's nothing to attach as an Authorization header here. `include`
  // makes the browser send/store that cookie on this cross-origin request.
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers,
    credentials: 'include',
  });

  if (response.status === 204) {
    return undefined as T;
  }

  const isJson = response.headers
    .get('content-type')
    ?.includes('application/json');

  const body = isJson ? await response.json() : null;

  if (!response.ok) {
    const errorBody = (body ?? {}) as ApiErrorBody;
    const message =
      errorBody.message ?? errorBody.error ?? `Request failed (${response.status})`;

    if (response.status === 401 && !EXCLUDED_FROM_GLOBAL_401_HANDLING.has(path)) {
      unauthorizedHandler?.();
    }

    throw new ApiError(message, response.status, errorBody.errors ?? []);
  }

  return body as T;
}

export const api = {
  get: <T>(path: string) => request<T>(path, { method: 'GET' }),
  post: <T>(path: string, data?: unknown) =>
    request<T>(path, {
      method: 'POST',
      body: data !== undefined ? JSON.stringify(data) : undefined,
    }),
  put: <T>(path: string, data: unknown) =>
    request<T>(path, { method: 'PUT', body: JSON.stringify(data) }),
  patch: <T>(path: string, data: unknown) =>
    request<T>(path, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
  // No Content-Type header here: the browser sets multipart/form-data with
  // the correct boundary itself, which it can only do when we don't set it.
  upload: <T>(path: string, file: File, field = 'photo') => {
    const body = new FormData();
    body.append(field, file);
    return request<T>(path, { method: 'POST', body });
  },
};

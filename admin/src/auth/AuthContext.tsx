import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { authApi } from '../api/resources';
import type { CurrentUser } from '../api/types';

interface AuthState {
  user: CurrentUser | null;
  isLoading: boolean;
  isRestoringSession: boolean;
  error: string | null;
  login: (phone: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<CurrentUser | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isRestoringSession, setIsRestoringSession] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // The auth cookie is httpOnly — JS can't check whether it exists, so
    // the only way to know if a session survived a page refresh is to ask
    // the backend. A missing/expired cookie just makes this 401, same as
    // any other unauthenticated request.
    authApi
      .me()
      .then((me) => {
        if (me.roles.includes('ROLE_ADMIN')) {
          setUser(me);
        }
      })
      .catch(() => {
        // Not signed in (no cookie, or an admin account signed out
        // elsewhere) — nothing to clear locally, there's no token in JS.
      })
      .finally(() => setIsRestoringSession(false));
  }, []);

  async function login(phone: string, password: string) {
    setIsLoading(true);
    setError(null);

    try {
      // The backend sets the auth cookie directly on this response; there's
      // no token for us to store — see api/client.ts's `credentials: 'include'`.
      await authApi.login(phone, password);

      const me = await authApi.me();

      if (!me.roles.includes('ROLE_ADMIN')) {
        await authApi.logout();
        throw new Error(
          "This account isn't an administrator account.",
        );
      }

      setUser(me);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed.');
      throw err;
    } finally {
      setIsLoading(false);
    }
  }

  function logout() {
    void authApi.logout();
    setUser(null);
  }

  return (
    <AuthContext.Provider
      value={{ user, isLoading, isRestoringSession, error, login, logout }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);

  if (!ctx) {
    throw new Error('useAuth must be used within AuthProvider');
  }

  return ctx;
}

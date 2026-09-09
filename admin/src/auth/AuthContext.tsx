import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { clearToken, getToken, setToken as persistToken } from '../api/client';
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
    if (!getToken()) {
      setIsRestoringSession(false);
      return;
    }

    authApi
      .me()
      .then((me) => {
        if (me.roles.includes('ROLE_ADMIN')) {
          setUser(me);
        } else {
          clearToken();
        }
      })
      .catch(() => clearToken())
      .finally(() => setIsRestoringSession(false));
  }, []);

  async function login(phone: string, password: string) {
    setIsLoading(true);
    setError(null);

    try {
      const { token } = await authApi.login(phone, password);
      persistToken(token);

      const me = await authApi.me();

      if (!me.roles.includes('ROLE_ADMIN')) {
        clearToken();
        throw new Error(
          "This account isn't an administrator account.",
        );
      }

      setUser(me);
    } catch (err) {
      clearToken();
      setError(err instanceof Error ? err.message : 'Login failed.');
      throw err;
    } finally {
      setIsLoading(false);
    }
  }

  function logout() {
    clearToken();
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

import { Navigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { Loading } from './ui';

export default function RequireAuth({ children }: { children: React.ReactNode }) {
  const { user, isRestoringSession } = useAuth();

  if (isRestoringSession) {
    return <Loading />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

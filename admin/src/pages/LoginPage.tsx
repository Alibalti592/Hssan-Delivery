import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function LoginPage() {
  const { login, isLoading, error } = useAuth();
  const navigate = useNavigate();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();

    try {
      await login(phone, password);
      navigate('/', { replace: true });
    } catch {
      // error is surfaced via useAuth().error
    }
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header">
          <h1>Delivery Hassen</h1>
          <p>Administration</p>
        </div>
        <div className="login-body">
          <form onSubmit={handleSubmit}>
            <div className="field-group">
              <label className="field-label" htmlFor="phone">
                Phone
              </label>
              <input
                id="phone"
                className="field-input"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+216 22 000 000"
                autoComplete="username"
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="password">
                Password
              </label>
              <input
                id="password"
                className="field-input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
            </div>
            {error && <div className="error-banner">{error}</div>}
            <button
              type="submit"
              className="btn"
              style={{ width: '100%', justifyContent: 'center', marginTop: 4 }}
              disabled={isLoading}
            >
              {isLoading ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useDispatchAlert, useDispatchSound } from './dispatch';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/restaurants', label: 'Restaurants' },
  { to: '/delivery-zones', label: 'Delivery Zones' },
  { to: '/couriers', label: 'Couriers' },
  { to: '/orders', label: 'Orders' },
  { to: '/deliveries', label: 'Deliveries' },
  { to: '/promotions', label: 'Promotions' },
  { to: '/bill-providers', label: 'Bill Providers' },
  { to: '/courier-map', label: 'Courier Map' },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [soundOn, toggleSound] = useDispatchSound();
  const waiting = useDispatchAlert(soundOn);

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <div className="app-shell">
      <div className="side">
        <div className="sbrand">
          Delivery Hassen
          <span>Admin</span>
        </div>
        <nav className="snav">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => `sitem${isActive ? ' on' : ''}`}
            >
              {item.label}
              {item.to === '/' && waiting > 0 && (
                <span className="snav-count" title="Orders waiting for a courier">
                  {waiting}
                </span>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="sfoot">
          {user?.name}
          <br />
          <NavLink to="/account/password" className="sfoot-link">
            Change password
          </NavLink>
          <br />
          <button type="button" onClick={toggleSound}>
            New-order sound: {soundOn ? 'on' : 'off'}
          </button>
          <br />
          <button type="button" onClick={handleLogout}>
            Log out
          </button>
        </div>
      </div>
      <div className="main">
        <Outlet />
      </div>
    </div>
  );
}

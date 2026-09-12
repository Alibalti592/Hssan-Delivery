import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/restaurants', label: 'Restaurants' },
  { to: '/delivery-zones', label: 'Delivery Zones' },
  { to: '/couriers', label: 'Couriers' },
  { to: '/orders', label: 'Orders' },
  { to: '/deliveries', label: 'Deliveries' },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

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
            </NavLink>
          ))}
        </nav>
        <div className="sfoot">
          {user?.name}
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

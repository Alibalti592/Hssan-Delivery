import { useEffect, useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useDispatchAlert, useDispatchSound } from './dispatch';
import monogramUrl from '../assets/monogram.svg';

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
  { to: '/password-reset', label: 'Password Reset' },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [soundOn, toggleSound] = useDispatchSound();
  const waiting = useDispatchAlert(soundOn);
  // Phones and portrait tablets: the sidebar slides in from a menu button.
  const [navOpen, setNavOpen] = useState(false);
  const closeNav = () => setNavOpen(false);

  useEffect(() => {
    if (!navOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setNavOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [navOpen]);

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <div className={`app-shell${navOpen ? ' nav-open' : ''}`}>
      <header className="mobile-bar">
        <button
          type="button"
          className="menu-btn"
          aria-label="Open menu"
          aria-expanded={navOpen}
          onClick={() => setNavOpen(true)}
        >
          <span />
          <span />
          <span />
        </button>
        <img className="monogram" src={monogramUrl} alt="" aria-hidden="true" />
        <div className="brand-name">Delivery Hassen</div>
        {waiting > 0 && (
          <NavLink to="/" className="mobile-waiting" title="Orders waiting for a courier" onClick={closeNav}>
            {waiting} waiting
          </NavLink>
        )}
      </header>
      {navOpen && <div className="nav-backdrop" onClick={closeNav} aria-hidden="true" />}
      <div className="side">
        <div className="sbrand">
          <img className="monogram" src={monogramUrl} alt="" aria-hidden="true" />
          <div className="brand-name">
            Delivery Hassen
            <span>Admin</span>
          </div>
        </div>
        <nav className="snav">
          {NAV_ITEMS.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => `sitem${isActive ? ' on' : ''}`}
              onClick={closeNav}
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
          <NavLink to="/account/password" className="sfoot-link" onClick={closeNav}>
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

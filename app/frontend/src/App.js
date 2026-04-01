/**
 * Root app component — declares all client-side routes.
 *
 * NGINX Ingress routing (Phase 4):
 *   /api/*   → backend service (FastAPI)
 *   /*       → frontend service (this React app served by Nginx)
 *
 * React Router handles /items, /users, etc. client-side;
 * Nginx serves index.html for any /* miss so deep-links work.
 */
import React from 'react';
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';
import Home from './pages/Home';
import ItemsList from './pages/ItemsList';
import ItemDetail from './pages/ItemDetail';
import UsersList from './pages/UsersList';
import UserDetail from './pages/UserDetail';
import HealthPage from './pages/HealthPage';
import NotFound from './pages/NotFound';

export default function App() {
  return (
    <BrowserRouter>
      <nav style={{ padding: '1rem', borderBottom: '1px solid #ccc', marginBottom: '1rem' }}>
        <Link to="/" style={{ marginRight: '1rem' }}>Home</Link>
        <Link to="/items" style={{ marginRight: '1rem' }}>Items</Link>
        <Link to="/users" style={{ marginRight: '1rem' }}>Users</Link>
        <Link to="/health">Health</Link>
      </nav>
      <div style={{ padding: '0 1rem' }}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/items" element={<ItemsList />} />
          <Route path="/items/:id" element={<ItemDetail />} />
          <Route path="/users" element={<UsersList />} />
          <Route path="/users/:id" element={<UserDetail />} />
          <Route path="/health" element={<HealthPage />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </div>
    </BrowserRouter>
  );
}

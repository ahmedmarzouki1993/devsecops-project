import React from 'react';
import { Link } from 'react-router-dom';

export default function Home() {
  return (
    <div>
      <h1>DevSecOps Demo App</h1>
      <p>3-tier app: React → FastAPI → PostgreSQL, deployed on AKS via ArgoCD.</p>
      <ul>
        <li><Link to="/items">Browse Items</Link></li>
        <li><Link to="/users">Browse Users</Link></li>
        <li><Link to="/health">Health Status</Link></li>
        <li><a href="/api/docs" target="_blank" rel="noreferrer">API Docs (Swagger)</a></li>
      </ul>
    </div>
  );
}

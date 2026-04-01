import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

export default function ItemsList() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch('/api/v1/items/')
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(setItems)
      .catch(e => setError(`Failed to load items: ${e}`));
  }, []);

  if (error) return <p style={{ color: 'red' }}>{error}</p>;

  return (
    <div>
      <h2>Items</h2>
      {items.length === 0 ? <p>Loading...</p> : (
        <ul>
          {items.map(item => (
            <li key={item.id}>
              <Link to={`/items/${item.id}`}>{item.name}</Link> — ${item.price}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

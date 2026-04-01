import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';

export default function ItemDetail() {
  const { id } = useParams();
  const [item, setItem] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`/api/v1/items/${id}`)
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(setItem)
      .catch(e => setError(e === 404 ? 'Item not found' : `Error: ${e}`));
  }, [id]);

  if (error) return <p style={{ color: 'red' }}>{error}</p>;
  if (!item) return <p>Loading...</p>;

  return (
    <div>
      <Link to="/items">← Back to Items</Link>
      <h2>{item.name}</h2>
      <p><strong>ID:</strong> {item.id}</p>
      <p><strong>Description:</strong> {item.description || '—'}</p>
      <p><strong>Price:</strong> ${item.price}</p>
      <p><strong>Created:</strong> {new Date(item.created_at).toLocaleString()}</p>
    </div>
  );
}

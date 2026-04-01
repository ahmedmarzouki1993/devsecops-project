import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';

export default function UserDetail() {
  const { id } = useParams();
  const [user, setUser] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`/api/v1/users/${id}`)
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(setUser)
      .catch(e => setError(e === 404 ? 'User not found' : `Error: ${e}`));
  }, [id]);

  if (error) return <p style={{ color: 'red' }}>{error}</p>;
  if (!user) return <p>Loading...</p>;

  return (
    <div>
      <Link to="/users">← Back to Users</Link>
      <h2>{user.username}</h2>
      <p><strong>ID:</strong> {user.id}</p>
      <p><strong>Email:</strong> {user.email}</p>
      <p><strong>Joined:</strong> {new Date(user.created_at).toLocaleString()}</p>
    </div>
  );
}

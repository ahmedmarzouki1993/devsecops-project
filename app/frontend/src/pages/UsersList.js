import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

export default function UsersList() {
  const [users, setUsers] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch('/api/v1/users/')
      .then(r => r.ok ? r.json() : Promise.reject(r.status))
      .then(setUsers)
      .catch(e => setError(`Failed to load users: ${e}`));
  }, []);

  if (error) return <p style={{ color: 'red' }}>{error}</p>;

  return (
    <div>
      <h2>Users</h2>
      {users.length === 0 ? <p>Loading...</p> : (
        <ul>
          {users.map(user => (
            <li key={user.id}>
              <Link to={`/users/${user.id}`}>{user.username}</Link> — {user.email}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

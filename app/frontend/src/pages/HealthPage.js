import React, { useEffect, useState } from 'react';

export default function HealthPage() {
  const [liveness, setLiveness] = useState(null);
  const [readiness, setReadiness] = useState(null);

  useEffect(() => {
    fetch('/healthz').then(r => r.json()).then(setLiveness).catch(() => setLiveness({ status: 'error' }));
    fetch('/readyz').then(r => r.json()).then(setReadiness).catch(() => setReadiness({ status: 'error' }));
  }, []);

  const badge = status => (
    <span style={{ color: status === 'error' ? 'red' : 'green', fontWeight: 'bold' }}>
      {status ?? '...'}
    </span>
  );

  return (
    <div>
      <h2>Health Status</h2>
      <p>Liveness (/healthz): {badge(liveness?.status)}</p>
      <p>Readiness (/readyz): {badge(readiness?.status)}</p>
    </div>
  );
}

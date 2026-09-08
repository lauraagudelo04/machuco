import express from 'express';

const port = Number(process.env.PORT || 8080);
const domain = process.env.AUTH0_DOMAIN || '';
const clientId = process.env.AUTH0_M2M_CLIENT_ID || '';
const clientSecret = process.env.AUTH0_M2M_CLIENT_SECRET || '';

if (!domain || !clientId || !clientSecret) {
  throw new Error(
    'Missing AUTH0_DOMAIN, AUTH0_M2M_CLIENT_ID or AUTH0_M2M_CLIENT_SECRET',
  );
}

const managementAudience = `https://${domain}/api/v2/`;
const app = express();

let cachedToken = '';
let tokenExpiresAt = 0;

async function getManagementToken() {
  if (cachedToken && Date.now() < tokenExpiresAt) {
    return cachedToken;
  }

  const tokenResponse = await fetch(`https://${domain}/oauth/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      grant_type: 'client_credentials',
      client_id: clientId,
      client_secret: clientSecret,
      audience: managementAudience,
    }),
  });

  if (!tokenResponse.ok) {
    const details = await tokenResponse.text();
    throw new Error(`Auth0 token error: ${tokenResponse.status} ${details}`);
  }

  const body = await tokenResponse.json();
  cachedToken = body.access_token;
  const expiresInMs = Number(body.expires_in || 60) * 1000;
  tokenExpiresAt = Date.now() + Math.max(expiresInMs - 10_000, 30_000);
  return cachedToken;
}

function toRole(rawUser) {
  const metadataRole = String(
    rawUser?.user_metadata?.profile_type ||
      rawUser?.app_metadata?.profile_type ||
      '',
  ).toLowerCase();
  if (metadataRole === 'administrator') return 'administrator';
  if (metadataRole === 'owner') return 'owner';
  return 'final_user';
}

function toApiUser(rawUser) {
  return {
    id: rawUser.user_id || '',
    fullName: rawUser.name || rawUser.nickname || 'Usuario sin nombre',
    email: rawUser.email || 'sin-correo',
    phoneNumber: rawUser.phone_number || '',
    role: toRole(rawUser),
    createdAt: rawUser.created_at || new Date().toISOString(),
  };
}

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.get('/users', async (_req, res) => {
  try {
    const token = await getManagementToken();
    const usersResponse = await fetch(
      `https://${domain}/api/v2/users?per_page=100&page=0&include_totals=false`,
      {
        headers: { Authorization: `Bearer ${token}` },
      },
    );

    if (!usersResponse.ok) {
      const details = await usersResponse.text();
      res.status(usersResponse.status).json({
        message: 'Auth0 users query failed',
        details,
      });
      return;
    }

    const users = await usersResponse.json();
    if (!Array.isArray(users)) {
      res.status(502).json({ message: 'Unexpected Auth0 response shape.' });
      return;
    }

    res.json(users.map(toApiUser));
  } catch (error) {
    res.status(500).json({
      message: 'Failed to list Auth0 users',
      details: error instanceof Error ? error.message : String(error),
    });
  }
});

app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Auth0 users API listening on port ${port}`);
});

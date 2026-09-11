import { cookies } from 'next/headers';
import type { NextRequest } from 'next/server';

async function proxy(request: NextRequest) {
  if (request.method !== 'GET' && request.headers.get('origin') !== request.nextUrl.origin) return Response.json({error: {code: 'invalid_origin'}}, {status: 403});
  const token = (await cookies()).get('eatme_session')?.value;
  const base = process.env.EATME_API_URL;
  if (!base) return Response.json({error: {code: 'api_not_configured'}}, {status: 503});
  if (!token) return Response.json({error: {code: 'unauthorized'}}, {status: 401});
  const resource = request.nextUrl.searchParams.get('resource') ?? 'admin/content';
  if (!['admin/content', 'catalog', 'profile'].includes(resource)) return Response.json({error: {code: 'not_found'}}, {status: 404});
  if (resource === 'profile' && request.method !== 'DELETE') return Response.json({error: {code: 'not_found'}}, {status: 404});
  try {
    const body = request.method === 'GET' ? undefined : await request.text();
    if (body && body.length > 262144) return Response.json({error: {code: 'payload_too_large'}}, {status: 413});
    const upstream = await fetch(`${base.replace(/\/$/, '')}/${resource}`, {
      method: request.method, body,
      headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'Idempotency-Key': request.headers.get('idempotency-key') ?? ''},
      cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(20000),
    });
    if (request.method === 'DELETE' && upstream.ok) (await cookies()).delete('eatme_session');
    return Response.json(await upstream.json(), {status: upstream.status, headers: {'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff'}});
  } catch { return Response.json({error: {code: 'upstream_unavailable'}}, {status: 502}); }
}
export const GET = proxy;
export const POST = proxy;
export const DELETE = proxy;

import { cookies } from 'next/headers';
import type { NextRequest } from 'next/server';

function sameOrigin(request: NextRequest) { return request.headers.get('origin') === request.nextUrl.origin; }
export async function POST(request: NextRequest) {
  if (!sameOrigin(request)) return Response.json({error: 'invalid_origin'}, {status: 403});
  if (Number(request.headers.get('content-length') ?? 0) > 16384) return Response.json({error: 'request_too_large'}, {status: 413});
  try {
    const body = await request.json() as {email?: string; password?: string; token?: string};
    let token = body.token;
    if (!token) {
      if (!body.email || !body.password || body.email.length > 240 || body.password.length > 128) return Response.json({error: 'invalid_credentials'}, {status: 422});
      const supabase = process.env.SUPABASE_URL;
      const api = process.env.EATME_API_URL;
      if (!api) return Response.json({error: 'api_not_configured'}, {status: 503});
      const upstream = await fetch(supabase ? `${supabase}/auth/v1/token?grant_type=password` : `${api}/auth/login`, {
        method: 'POST', headers: {'Content-Type': 'application/json', ...(supabase ? {apikey: process.env.SUPABASE_ANON_KEY ?? ''} : {})},
        body: JSON.stringify({email: body.email, password: body.password}), cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000),
      });
      if (!upstream.ok) return Response.json({error: 'authentication_failed'}, {status: 401});
      token = (await upstream.json() as {access_token: string}).access_token;
    }
    if (!token || token.length > 8192) return Response.json({error: 'invalid_session'}, {status: 422});
    (await cookies()).set('eatme_session', token, {httpOnly: true, sameSite: 'strict', secure: process.env.NODE_ENV === 'production', path: '/', maxAge: 1800});
    return Response.json({authenticated: true}, {headers: {'Cache-Control': 'no-store'}});
  } catch { return Response.json({error: 'authentication_unavailable'}, {status: 502}); }
}
export async function DELETE(request: NextRequest) {
  if (!sameOrigin(request)) return Response.json({error: 'invalid_origin'}, {status: 403});
  (await cookies()).delete('eatme_session');
  return Response.json({signed_out: true});
}

import type { NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const authorization=request.headers.get('authorization');
  if(!authorization?.startsWith('Bearer ')||authorization.length>8192) {
    return Response.json({error:{code:'unauthorized'}},{status:401});
  }
  const base=process.env.EATME_API_URL;
  if(!base) return Response.json({error:{code:'api_not_configured'}},{status:503});
  try {
    const result=await fetch(`${base.replace(/\/$/,'')}/admin/catalog`,{
      headers:{Authorization:authorization},cache:'no-store',signal:AbortSignal.timeout(12000),redirect:'error'
    });
    return Response.json(await result.json(),{status:result.status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
  } catch {
    return Response.json({error:{code:'upstream_unavailable'}},{status:502});
  }
}

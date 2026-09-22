import type {NextRequest} from 'next/server';

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) return Response.json({error:{code:'invalid_origin'}},{status:403});
  if (Number(request.headers.get('content-length')??0)>16384) return Response.json({error:{code:'request_too_large'}},{status:413});
  try {
    const body=await request.json() as {email?:string;password?:string;confirm?:boolean};
    if(!body.email||!body.password||body.confirm!==true||body.email.length>240||body.password.length>128) return Response.json({error:{code:'invalid_request'}},{status:422});
    const supabase=process.env.SUPABASE_URL, publishable=process.env.SUPABASE_ANON_KEY, api=process.env.EATME_API_URL;
    if(!supabase||!publishable||!api) return Response.json({error:{code:'service_not_configured'}},{status:503});
    const login=await fetch(`${supabase}/auth/v1/token?grant_type=password`,{method:'POST',headers:{'Content-Type':'application/json',apikey:publishable},body:JSON.stringify({email:body.email,password:body.password}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(15000)});
    if(!login.ok) return Response.json({error:{code:'authentication_failed'}},{status:401});
    const token=(await login.json() as {access_token?:string}).access_token;
    if(!token) return Response.json({error:{code:'authentication_failed'}},{status:401});
    const deleted=await fetch(`${api.replace(/\/$/,'')}/profile`,{method:'DELETE',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({confirm:true}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(20000)});
    return Response.json(await deleted.json(),{status:deleted.status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
  } catch { return Response.json({error:{code:'service_unavailable'}},{status:502}); }
}

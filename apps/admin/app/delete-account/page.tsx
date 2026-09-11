'use client';
import {useState, type FormEvent} from 'react';
export default function DeleteAccount() {
  const [email,setEmail]=useState(''),[password,setPassword]=useState(''),[confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
  async function submit(event: FormEvent) {
    event.preventDefault();setBusy(true);setMessage('');
    try {
      const login=await fetch('/api/session',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password})});setPassword('');
      if(!login.ok) throw new Error('Sign-in failed. You can also delete your account from the mobile app.');
      const result=await fetch('/api/content?resource=profile',{method:'DELETE',headers:{'Content-Type':'application/json'},body:JSON.stringify({confirm:true})});
      const body=await result.json();
      if(!result.ok) throw new Error((body.error?.code??'Deletion failed').replaceAll('_',' '));
      setMessage('Your account and personal app data have been deleted.');setConfirm(false);
    }catch(error){setMessage(error instanceof Error?error.message:'Request failed.');}finally{setBusy(false);}
  }
  return <main><header><a className="brand" href="/">EatMe</a><span>Account deletion</span></header><h1>Delete your EatMe account.</h1><p>Sign in to confirm your identity. Account deletion removes your personal profile, preferences, private recipes, processing records and personal plans. Shared inventory remains with the household; transfer ownership first. Store subscriptions must be cancelled separately.</p><p>For Google or Apple sign-in, use Profile → Privacy in the mobile app. If you cannot access your account, contact the operator listed in the <a href="/privacy">privacy information</a>.</p>
    <form onSubmit={submit}><label htmlFor="email">Account email</label><input id="email" type="email" autoComplete="username" required value={email} onChange={e=>setEmail(e.target.value)} /><label htmlFor="password">Password</label><input id="password" type="password" autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} /><label><input style={{width:'auto'}} type="checkbox" checked={confirm} onChange={e=>setConfirm(e.target.checked)} /> I understand this permanently deletes my account.</label><button disabled={busy||!confirm}>{busy?'Deleting…':'Delete account'}</button></form>{message&&<p role="status">{message}</p>}</main>;
}

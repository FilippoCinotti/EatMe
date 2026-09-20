'use client';
import {useState, type FormEvent} from 'react';

export default function DeleteAccount() {
  const [email,setEmail]=useState(''),[password,setPassword]=useState(''),[confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
  async function submit(event: FormEvent) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const result=await fetch('/api/delete-account',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,confirm:true})});
      setPassword(''); const body=await result.json();
      if(!result.ok) throw new Error((body.error?.code??'Deletion failed').replaceAll('_',' '));
      setMessage('Your EatMe+ account and personal app data have been deleted.'); setConfirm(false);
    } catch(error) { setMessage(error instanceof Error?error.message:'Request failed.'); } finally { setBusy(false); }
  }
  return <main className="legal"><header><a className="wordmark" href="/"><img src="/eatme-mark.svg" alt="" />EatMe+</a><span>Account deletion</span></header><h1>Delete your<br />EatMe+ account.</h1>
    <p>Email/password accounts can be deleted here after identity confirmation. Apple or Google accounts can be deleted in the app from Profile → Privacy. Transfer ownership of a shared household first. Store subscriptions must be cancelled separately.</p>
    <form onSubmit={submit}><label htmlFor="email">Account email</label><input id="email" type="email" autoComplete="username" required value={email} onChange={event=>setEmail(event.target.value)} /><label htmlFor="password">Password</label><input id="password" type="password" autoComplete="current-password" minLength={12} required value={password} onChange={event=>setPassword(event.target.value)} /><label><input style={{width:'auto'}} type="checkbox" checked={confirm} onChange={event=>setConfirm(event.target.checked)} /> I understand this permanently deletes my account.</label><button disabled={busy||!confirm}>{busy?'Deleting…':'Delete account'}</button></form>{message&&<p role="status">{message}</p>}
    <p><a href="/privacy">Privacy</a> · <a href="/support">Support</a></p></main>;
}

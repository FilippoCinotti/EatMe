'use client';
import { useState, type FormEvent } from 'react';

type Diet = { id: string; slug: string; name: Record<string,string>; status: string; selectable: boolean; medical: boolean };
type Catalog = { diets: Diet[]; foods: unknown[] };

export default function Review() {
  const [token,setToken]=useState('');
  const [catalog,setCatalog]=useState<Catalog|null>(null);
  const [error,setError]=useState('');
  const [busy,setBusy]=useState(false);
  async function load(event: FormEvent) {
    event.preventDefault();setBusy(true);setError('');
    try {
      const response=await fetch('/api/catalog',{headers:{Authorization:`Bearer ${token}`},cache:'no-store'});
      if(!response.ok) throw new Error(response.status===403?'Questo utente non ha il ruolo amministrativo.':'Accesso non riuscito. Verifica sessione e configurazione API.');
      setCatalog(await response.json() as Catalog);setToken('');
    } catch(error) {setError(error instanceof Error?error.message:'Errore di connessione.');}
    finally {setBusy(false);}
  }
  return <main>
    <header><span className="brand">EatMe</span><span>Content review · 0.1</span></header>
    <h1>Catalogo e profili alimentari.</h1>
    <p className="intro">Console di consultazione per il primo ciclo di sviluppo. Pubblicazione scientifica ed editing saranno introdotti con il relativo flusso di revisione.</p>
    {!catalog?<form onSubmit={load}>
      <label htmlFor="token">Token di sessione dell’amministratore</label>
      <input id="token" type="password" autoComplete="off" value={token} onChange={e=>setToken(e.target.value)} required />
      <p className="muted">La sessione non viene salvata nel browser. L’API verifica l’identità e l’autorizzazione.</p>
      <button disabled={busy}>{busy?'Accesso in corso…':'Apri catalogo'}</button>
    </form>:<>
      <div className="summary"><span>{catalog.foods.length} alimenti</span><span>{catalog.diets.length} profili</span>
        <button className="secondary" onClick={()=>{setCatalog(null);setToken('');}}>Chiudi sessione console</button></div>
      <div className="table-wrap"><table><thead><tr><th>Profilo</th><th>Categoria</th><th>Stato editoriale</th><th>Selezionabile</th></tr></thead>
        <tbody>{catalog.diets.map(d=><tr key={d.id}><td><strong>{d.name.it??d.name.en}</strong><small>{d.slug}</small></td>
          <td>{d.medical?'Nutrizione medica':'Stile alimentare'}</td><td>{d.status==='PUBLISHED'?'Pubblicato':'Richiede revisione'}</td><td>{d.selectable?'Sì':'No'}</td></tr>)}</tbody>
      </table></div>
      <p className="muted">I record iniziali sono dimostrativi. RAD non contiene regole cliniche attive.</p>
    </>}
    {error&&<p role="alert" className="error">{error}</p>}
  </main>;
}

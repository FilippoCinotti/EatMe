'use client';
import { useRef, useState, type FormEvent } from 'react';

type RecordData = {id: string; kind: string; subject_id: string; revision: number; status: string; data: Record<string, unknown>; created_by: string; reviewed_by: string | null};
type Report = {id: string; kind: string; message: string; status: string};
type ConsoleData = {role: string; items: RecordData[]; reports: Report[]; flags: {name: string; enabled: number}[]; audit: {id: string; action: string; subject_id: string; created_at: string}[]};
const templates: Record<string, object> = {
  food: {name: {en: '', it: ''}, group: 'vegetable', unit: 'g', ingredient_status: 'unknown', allergens: [], may_contain: [], intolerances: [], nutrition: null},
  recipe: {title: {en: '', it: ''}, servings: 2, minutes: 20, cuisine: 'other', ingredients: [{food_id: '', quantity: '100'}], steps: {en: [''], it: ['']}},
  diet: {slug: '', name: {en: '', it: ''}, medical: false, effective_from: '', review_date: '', evidence_references: [], rules: [], context: '', clinical_limitations: '', reviewer_qualification: ''},
  evidence: {title: '', publisher: '', claim: '', jurisdiction: '', strength: 'systematic_review', published_date: '', review_due: '', url: ''},
  recall: {barcode: '', lot: '', reason: '', url: '', published_date: ''},
  expiry: {food_id: '', days: 0, location: 'fridge', source_url: ''},
  alias: {alias: '', locale: 'en', food_id: ''},
};

export default function Review() {
  const [email, setEmail] = useState(''), [password, setPassword] = useState('');
  const [data, setData] = useState<ConsoleData | null>(null), [error, setError] = useState('');
  const [busy, setBusy] = useState(false), [kind, setKind] = useState('food'), [filter, setFilter] = useState('all');
  const [draft, setDraft] = useState(JSON.stringify(templates.food, null, 2)), [subject, setSubject] = useState('');
  const mutation = useRef<{fingerprint: string; key: string} | null>(null);
  const [roleUser, setRoleUser] = useState(''), [assignedRole, setAssignedRole] = useState('editor');
  const [selected, setSelected] = useState<RecordData | null>(null);
  const [catalog, setCatalog] = useState<{foods: {id: string; name: Record<string, string>}[]} | null>(null);
  async function request(body?: object) {
    const fingerprint = body ? JSON.stringify(body) : '';
    if (body && mutation.current?.fingerprint !== fingerprint) mutation.current = {fingerprint, key: crypto.randomUUID()};
    const result = await fetch('/api/content', body ? {method: 'POST', headers: {'Content-Type': 'application/json', 'Idempotency-Key': mutation.current!.key}, body: fingerprint} : {cache: 'no-store'});
    const value = await result.json();
    if (!result.ok) throw new Error(value.error?.code ?? 'Request failed');
    if (body) mutation.current = null;
    return value;
  }
  async function run(action: () => Promise<void>) { setBusy(true); setError(''); try { await action(); } catch (e) { setError(e instanceof Error ? e.message : 'Request failed'); } finally { setBusy(false); } }
  async function refresh() { setData(await request() as ConsoleData); }
  async function login(event: FormEvent) {
    event.preventDefault();
    await run(async () => {
      const response = await fetch('/api/session', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, password})});
      setPassword('');
      if (!response.ok) throw new Error('Sign-in failed. Check your credentials and API configuration.');
      await refresh();
      const catalogResponse = await fetch('/api/content?resource=catalog', {cache: 'no-store'});
      if (catalogResponse.ok) setCatalog(await catalogResponse.json());
    });
  }
  async function transition(record: RecordData, action: string) { await run(async () => { await request({action, id: record.id, expected_status: record.status}); await refresh(); setSelected(null); }); }
  return <main>
    <header><span className="brand">EatMe</span><span>Content & evidence studio</span></header>
    <h1>Thoughtful content.<br />Accountable decisions.</h1>
    <p className="intro">Maintain the food catalog, inspect reports and publish reviewed content. Every publication requires a different reviewer from its author.</p>
    {error && <p role="alert" className="error">{error.replaceAll('_', ' ')}</p>}
    {!data ? <form onSubmit={login}>
      <label htmlFor="email">Email</label><input id="email" type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} required />
      <label htmlFor="password">Password</label><input id="password" type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} required />
      <p className="muted">Use an existing EatMe account with an assigned editorial role. Sessions use an HTTP-only cookie and expire after 30 minutes.</p>
      <button disabled={busy}>{busy ? 'Signing in…' : 'Open studio'}</button>
    </form> : <>
      <div className="summary"><strong>{data.role}</strong><span>{data.items.length} revisions</span>
        <button className="secondary" disabled={busy} onClick={() => run(refresh)}>Refresh</button>
        <button className="secondary" onClick={async () => { await fetch('/api/session', {method: 'DELETE'}); setData(null); setSelected(null); }}>Sign out</button></div>
      {data.role === 'superadmin' && <section><h2>Editorial access</h2><form onSubmit={event => {event.preventDefault(); void run(async () => {await request({action: 'role', user_id: roleUser, role: assignedRole}); setRoleUser(''); await refresh();});}}>
        <label htmlFor="role-user">Existing account UUID</label><input id="role-user" value={roleUser} onChange={event => setRoleUser(event.target.value)} required pattern="[a-f0-9-]{36}" />
        <label htmlFor="assigned-role">Role</label><select id="assigned-role" value={assignedRole} onChange={event => setAssignedRole(event.target.value)}>{['support','editor','reviewer','admin','superadmin','none'].map(role => <option key={role}>{role}</option>)}</select>
        <button disabled={busy}>Update access</button></form></section>}
      {data.role !== 'support' && <section className="editor-grid">
        <div><h2>Create a revision</h2><label htmlFor="kind">Content type</label>
          <select id="kind" value={kind} onChange={e => { setKind(e.target.value); setDraft(JSON.stringify(templates[e.target.value], null, 2)); setSubject(''); }}>{Object.keys(templates).map(k => <option key={k}>{k}</option>)}</select>
          <label htmlFor="subject">Existing subject UUID (leave empty for new content)</label><input id="subject" value={subject} onChange={e => setSubject(e.target.value)} />
          <label htmlFor="draft">Structured content</label><textarea id="draft" rows={20} spellCheck={false} value={draft} onChange={e => setDraft(e.target.value)} />
          <button disabled={busy} onClick={() => run(async () => { await request({action: 'draft', kind, ...(subject ? {subject_id: subject} : {}), data: JSON.parse(draft)}); await refresh(); })}>Save draft</button>
          <p className="muted">Saving creates a new immutable revision. Submission validates the schema and source references. Clinical content requires evidence, limitations and reviewer qualifications.</p>
          <details><summary>Canonical food identifiers</summary>{catalog?.foods.map(f => <p key={f.id}><strong>{f.name.en}</strong><br /><code>{f.id}</code></p>)}</details>
        </div>
        <div><h2>Review queue</h2><label htmlFor="filter">Filter status</label><select id="filter" value={filter} onChange={e => setFilter(e.target.value)}>{['all', 'DRAFT', 'IN_REVIEW', 'PUBLISHED', 'DEPRECATED'].map(s => <option key={s}>{s}</option>)}</select>
          {data.items.filter(r => filter === 'all' || r.status === filter).map(record => <article className="review-card" key={record.id}>
            <span className="muted">{record.kind} · revision {record.revision}</span><h3>{String(record.data.title && typeof record.data.title === 'string' ? record.data.title : record.data.slug ?? record.subject_id)}</h3>
            <p>{record.status.replaceAll('_', ' ')}</p><div className="actions"><button className="secondary" onClick={() => setSelected(record)}>Inspect</button>
            {record.status === 'DRAFT' && <button disabled={busy} onClick={() => transition(record, 'submit')}>Submit for review</button>}
            {record.status === 'IN_REVIEW' && ['reviewer', 'admin', 'superadmin'].includes(data.role) && <button disabled={busy} onClick={() => transition(record, 'publish')}>Publish reviewed revision</button>}
            {record.status === 'PUBLISHED' && ['reviewer', 'admin', 'superadmin'].includes(data.role) && <button disabled={busy} onClick={() => transition(record, 'deprecate')}>Deprecate</button>}
            <button className="secondary" onClick={() => { setKind(record.kind); setSubject(record.subject_id); setDraft(JSON.stringify(record.data, null, 2)); }}>Create next revision</button></div>
          </article>)}
        </div>
      </section>}
      {selected && <section className="inspection" aria-label="Revision inspection"><h2>Revision {selected.revision}</h2><p>Author: {selected.created_by}<br />Reviewer: {selected.reviewed_by ?? 'Not reviewed'}</p><pre>{JSON.stringify(selected.data, null, 2)}</pre><button onClick={() => setSelected(null)}>Close inspection</button></section>}
      <section><h2>User reports</h2>{data.reports.length === 0 && <p className="muted">No reports.</p>}{data.reports.map(report => <article className="review-card" key={report.id}><strong>{report.kind} · {report.status}</strong><p>{report.message}</p><button disabled={busy} onClick={() => run(async () => { await request({action: 'resolve_report', id: report.id, status: 'RESOLVED'}); await refresh(); })}>Mark resolved</button></article>)}</section>
      {['admin', 'superadmin'].includes(data.role) && <section><h2>Feature availability</h2><div className="actions">{['ai_scan', 'ai_recipe', 'receipt_scan', 'barcode_scan', 'subscriptions'].map(name => <button key={name} disabled={busy} className="secondary" onClick={() => run(async () => { await request({action: 'flag', name, enabled: !data.flags.find(f => f.name === name)?.enabled}); await refresh(); })}>{name.replaceAll('_', ' ')}: {data.flags.find(f => f.name === name)?.enabled ? 'on' : 'off'}</button>)}</div><p className="muted">Provider configuration and entitlement checks still apply.</p></section>}
      {data.audit.length > 0 && <section><h2>Audit trail</h2><div className="table-wrap"><table><thead><tr><th>Action</th><th>Subject</th><th>Time</th></tr></thead><tbody>{data.audit.map(event => <tr key={event.id}><td>{event.action}</td><td>{event.subject_id}</td><td>{event.created_at}</td></tr>)}</tbody></table></div></section>}
    </>}
    <footer><a href="/privacy">Privacy</a> · <a href="/delete-account">Delete an account</a></footer>
  </main>;
}

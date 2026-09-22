export const metadata = {title: 'Support'};
export default function Support() {
  const contact = process.env.SUPPORT_CONTACT ?? process.env.PRIVACY_CONTACT;
  return <main className="legal"><header><a className="wordmark" href="/"><img src="/eatme-mark.svg" alt="" />EatMe+</a><span>Support</span></header><h1>Help with<br />your kitchen.</h1>
    <h2>Changes waiting to sync</h2><p>Open Profile → Offline sync. Reconnect and sync, or review and discard a conflicting local change. Cooking and purchase confirmation require a live connection.</p>
    <h2>Account access</h2><p>Use password recovery on the sign-in screen. For Apple or Google accounts, use the same sign-in provider you originally chose.</p>
    <h2>Contact</h2>{contact ? <p><a href={`mailto:${contact}`}>{contact}</a>. Include the app version and a description of the issue. Never send a password or unnecessary health information.</p> : <p>An operational support address will appear here before the beta opens to external testers.</p>}
    <p><a href="/privacy">Privacy</a> · <a href="/terms">Terms</a> · <a href="/delete-account">Delete account</a></p></main>;
}

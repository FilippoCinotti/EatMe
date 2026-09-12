export default function Support() {
  const contact = process.env.PRIVACY_CONTACT;
  return <main><header><a className="brand" href="/">EatMe</a><span>Support</span></header>
    <h1>Help with your kitchen.</h1>
    <h2>Changes waiting to sync</h2><p>Open Profile → Offline sync. Reconnect and sync, or discard a conflicting change after reviewing the current household. Cooking and purchases require a live connection.</p>
    <h2>Account access</h2><p>Use the password recovery option on the sign-in screen. For Apple or Google accounts, use the original sign-in provider.</p>
    <h2>Recipes and food data</h2><p>Use Report a problem on a recipe to send a correction to the editorial team. Check the product label yourself; unknown ingredients and unreviewed medical profiles cannot be treated as verified.</p>
    <h2>Contact</h2>{contact ? <p><a href={`mailto:${contact}`}>{contact}</a>. Include your app version and a description of the issue. Do not send passwords or unnecessary health information.</p> : <p>The deployment owner must configure an operational support contact before launch.</p>}
    <p><a href="/privacy">Privacy information</a> · <a href="/delete-account">Account deletion</a> · <a href="/terms">Terms</a></p>
  </main>;
}

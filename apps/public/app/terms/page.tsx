export const metadata = {title: 'Terms'};
export default function Terms() {
  const operator = process.env.PRIVACY_OPERATOR, contact = process.env.PRIVACY_CONTACT;
  return <main className="legal"><header><a className="wordmark" href="/"><img src="/eatme-mark.svg" alt="" />EatMe+</a><span>Terms</span></header><h1>Use EatMe+ thoughtfully.</h1>
    <p>EatMe+ helps adults organize food, recipes and shared kitchens. You remain responsible for checking product labels and deciding whether food can be used. A photograph cannot establish food safety.</p>
    <h2>Accounts and households</h2><p>Keep account access private. Household owners manage invitations and permissions. Share dietary constraints only when you choose to do so.</p>
    <h2>Imported and assisted content</h2><p>Import only material you may lawfully use. Review every ingredient, amount and instruction. Assisted results can be inaccurate and require confirmation.</p>
    <h2>Health information</h2><p>EatMe+ does not diagnose, treat or replace care from a qualified professional. A result with no known conflict is not a guarantee against allergens or other risks.</p>
    <h2>EatMe Premium</h2><p>Available prices, periods and trial conditions are displayed by your app store before purchase. Manage cancellation and refunds through the store. Account deletion does not cancel a store subscription.</p>
    {operator && contact ? <p>Service operator: {operator}. Contact: <a href={`mailto:${contact}`}>{contact}</a>. Mandatory consumer rights remain unaffected.</p> : <p>The service is not open for public registration until the owner completes operator identity, commercial terms, applicable jurisdiction, support and privacy information.</p>}
    <p><a href="/privacy">Privacy</a> · <a href="/delete-account">Delete account</a> · <a href="/support">Support</a></p></main>;
}

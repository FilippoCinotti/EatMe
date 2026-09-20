export default function Terms() {
  const operator = process.env.PRIVACY_OPERATOR, contact = process.env.PRIVACY_CONTACT;
  return <main><header><a className="brand" href="/">EatMe+</a><span>Terms of use</span></header><h1>Use EatMe+ thoughtfully.</h1>
    <p>EatMe+ helps adults organize food, recipes and shared kitchens. You are responsible for the information you enter, checking product labels and deciding whether food can be used. Photographs cannot establish food safety. Dietary assessments depend on the completeness and currency of their underlying data.</p>
    <h2>Accounts and households</h2><p>Keep account access private. Household owners manage invitations and permissions. Share dietary constraints only when you choose to do so. Transfer shared ownership before deleting an owner account.</p>
    <h2>Imported and assisted content</h2><p>Import only material you may lawfully use for your private purposes. Review every ingredient, amount and instruction. Assisted results can be inaccurate and require your confirmation. Do not use the service to upload unlawful content, bypass access controls or misrepresent scientific evidence.</p>
    <h2>Health information</h2><p>EatMe+ does not diagnose, treat or replace care from a qualified professional. Scientific profiles remain unavailable until independently reviewed. A result with no known conflict is not a guarantee against allergens or other risks.</p>
    <h2>EatMe Premium</h2><p>Available prices, periods and trial conditions are displayed by your app store before purchase. Store subscriptions renew under the terms displayed there. Manage cancellation and refunds through the store. Account deletion does not cancel a store subscription.</p>
    <h2>Privacy and support</h2><p><a href="/privacy">Privacy information</a> explains data processing and your controls. <a href="/delete-account">Account deletion</a> is available in the app and on this website.</p>
    {operator && contact ? <p>Service operator: {operator}. Contact: <a href={`mailto:${contact}`}>{contact}</a>. Mandatory consumer rights remain unaffected.</p> : <p>This development service is not open for public registration. The operator must complete the commercial terms, applicable jurisdiction, support and privacy information before release.</p>}
  </main>;
}

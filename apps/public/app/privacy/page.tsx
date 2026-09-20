export const metadata = {title: 'Privacy'};
export default function Privacy() {
  const operator = process.env.PRIVACY_OPERATOR, contact = process.env.PRIVACY_CONTACT;
  return <main className="legal"><header><a className="wordmark" href="/"><img src="/eatme-mark.svg" alt="" />EatMe+</a><span>Privacy</span></header><h1>Your kitchen.<br />Your data.</h1>
    <p>EatMe+ stores your account, household membership, inventory, recipes, meal plans, shopping lists and chosen preferences to provide the features you request.</p>
    <h2>Optional sensitive information</h2><p>Allergies, intolerances and medical nutrition profiles require explicit consent. Household members can use your dietary constraints for shared meal validation only if you enable sharing. Personal profiles are not exposed to other members.</p>
    <h2>Images and assisted processing</h2><p>Selected images and text are sent to the configured processing provider only with consent. Image metadata is stripped. Private images are encrypted before storage; temporary scan and receipt images expire after 24 hours. Assisted results require your review and explicit confirmation.</p>
    <h2>Crash diagnostics</h2><p>Release builds use Firebase Crashlytics to receive crash diagnostics needed to keep EatMe+ reliable. EatMe+ does not intentionally attach recipes, food choices, health information, authentication tokens or private images to crash reports. Crash diagnostics are not used for advertising.</p>
    <h2>Your controls</h2><p>You can change consent, export account data and request account deletion in Profile → Privacy. Account deletion does not cancel an App Store or Google Play subscription; manage that separately in your store account.</p>
    <h2>Operator and requests</h2>{operator && contact ? <p>{operator}<br /><a href={`mailto:${contact}`}>{contact}</a></p> : <p>Public registration will remain closed until the owner publishes the legal operator, privacy contact, hosting locations, processors, retention periods and applicable rights.</p>}
    <p><a href="/delete-account">Delete an account</a> · <a href="/terms">Terms</a> · <a href="/support">Support</a></p></main>;
}

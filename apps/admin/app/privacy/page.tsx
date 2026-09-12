export default function Privacy() {
  const operator = process.env.PRIVACY_OPERATOR;
  const contact = process.env.PRIVACY_CONTACT;
  return <main><header><a className="brand" href="/">EatMe</a><span>Privacy information</span></header><h1>Your kitchen. Your data.</h1>
    <p>This application stores your account, household membership, inventory, recipes, meal plans, shopping lists and chosen preferences to provide its features.</p>
    <h2>Optional sensitive information</h2><p>Allergies, intolerances and medical nutrition profiles require explicit consent. Household members can use your dietary constraints for shared meal validation only if you enable sharing. Personal profiles are not exposed to other members.</p>
    <h2>Images and assisted processing</h2><p>Selected images and text are sent to the configured processing provider only with consent. Image metadata is stripped; uploaded food and receipt images are encrypted at rest and expire after 24 hours. Processing results remain in your account until deletion. Provider retention terms also apply and must be disclosed by the service operator before enabling the integration.</p>
    <h2>Controls</h2><p>You can change consent, export account data and request account deletion in Profile → Privacy. An exported JSON file stays in the app's temporary directory until the next launch or sign-out so your chosen destination can read it. Copies you share are controlled by that destination. Shared household ownership must first be transferred. Deleting an account does not cancel an App Store or Google Play subscription; manage it in your store account.</p>
    <h2>Analytics and advertising</h2><p>Usage analytics are optional and limited to approved event fields. EatMe does not use health data for advertising. Authentication and transaction logs must be configured without request bodies, credentials or health details.</p>
    <h2>Operator and requests</h2>{operator && contact ? <p>{operator}<br /><a href={`mailto:${contact}`}>{contact}</a></p> : <p>The deployment owner must configure the legal operator, privacy contact, hosting locations, providers, retention and applicable rights before public release. This development deployment is not accepting public registrations.</p>}
    <p><a href="/delete-account">Request account deletion</a></p></main>;
}

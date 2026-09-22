import Image from 'next/image';

export default function Home() {
  return <main>
    <nav><a className="wordmark" href="/"><img src="/eatme-mark.svg" alt="" />EatMe+</a><div><a href="/support">Support</a><a href="/privacy">Privacy</a></div></nav>
    <section className="hero">
      <div><p className="eyebrow">A calmer kitchen</p><h1>Your recipes.<br />Your fridge.<br />One decision.</h1>
        <p className="lead">EatMe+ brings planning, ingredients and the food rules you choose into one private, practical place.</p>
        <span className="status">Preparing the first TestFlight beta</span>
      </div>
      <Image className="app-icon" src="/eatme-plus-icon.png" width={512} height={512} priority alt="EatMe+ two-leaf app icon" />
    </section>
    <section className="principles" aria-label="Product principles">
      <article><h2>Decide with context</h2><p>See what fits your kitchen and your saved preferences before you cook.</p></article>
      <article><h2>Review before change</h2><p>Imports, scans and substitutions stay proposals until you explicitly confirm them.</p></article>
      <article><h2>Safety stays firm</h2><p>Allergies and hard exclusions are never relaxed by flexible meal choices.</p></article>
    </section>
    <footer><span>EatMe+</span><div><a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="/support">Support</a><a href="/delete-account">Delete account</a></div></footer>
  </main>;
}

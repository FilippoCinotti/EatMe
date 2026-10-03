import { Wordmark } from "../components/guest-flow";

export default function Home() {
  return (
    <main className="centered">
      <Wordmark />
      <section className="card">
        <h1>Dinner RSVP</h1>
        <p>Open the private link shared by your host.</p>
      </section>
    </main>
  );
}

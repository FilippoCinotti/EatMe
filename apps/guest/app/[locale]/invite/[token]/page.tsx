import { notFound } from "next/navigation";
import GuestFlow, { type InvitePayload } from "../../../../components/guest-flow";
import { copy, isLocale } from "../../../../lib/i18n";

export const dynamic = "force-dynamic";
export const revalidate = 0;

async function loadInvitation(api: string, token: string): Promise<InvitePayload | null> {
  try {
    const response = await fetch(`${api}/guest/invites/${encodeURIComponent(token)}`, {
      cache: "no-store",
      headers: { Accept: "application/json" },
      referrerPolicy: "no-referrer",
    });
    if (!response.ok) return null;
    return (await response.json()) as InvitePayload;
  } catch {
    return null;
  }
}

export default async function InvitePage({
  params,
}: {
  params: Promise<{ locale: string; token: string }>;
}) {
  const { locale, token } = await params;
  if (!isLocale(locale)) notFound();
  const api = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api/v1";
  const invitation = await loadInvitation(api, token);
  if (!invitation) {
    const t = copy[locale];
    return (
      <main className="centered">
        <div className="brand">EatMe</div>
        <section className="card">
          <span className="eyebrow">{t.invitation}</span>
          <h1>{t.unavailable}</h1>
          <p>{t.unavailableDetail}</p>
        </section>
      </main>
    );
  }
  return <GuestFlow api={api} invitation={invitation} locale={locale} token={token} />;
}

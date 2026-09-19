import { notFound } from "next/navigation";
import GuestFlow, { GuestUnavailable, type InvitePayload, type InviteProblem } from "../../../../components/guest-flow";
import { isLocale } from "../../../../lib/i18n";

export const dynamic = "force-dynamic";
export const revalidate = 0;

async function loadInvitation(api: string, token: string): Promise<{ invitation: InvitePayload | null; problem: InviteProblem }> {
  try {
    const response = await fetch(`${api}/guest/invites/${encodeURIComponent(token)}`, {
      cache: "no-store",
      headers: { Accept: "application/json" },
      referrerPolicy: "no-referrer",
    });
    if (!response.ok) {
      const payload = (await response.json().catch(() => null)) as { error?: { details?: { reason?: string } } } | null;
      const reason = payload?.error?.details?.reason;
      return { invitation: null, problem: reason === "expired" || reason === "revoked" || reason === "cancelled" ? reason : "unavailable" };
    }
    return { invitation: (await response.json()) as InvitePayload, problem: "unavailable" };
  } catch {
    return { invitation: null, problem: "network" };
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
  const { invitation, problem } = await loadInvitation(api, token);
  if (!invitation) {
    return <GuestUnavailable locale={locale} problem={problem} />;
  }
  return <GuestFlow api={api} invitation={invitation} locale={locale} token={token} />;
}

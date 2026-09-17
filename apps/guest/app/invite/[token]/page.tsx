import { headers } from "next/headers";
import { redirect } from "next/navigation";

function preferredLocale(value: string | null): string {
  const language = (value ?? "en").toLowerCase();
  if (language.startsWith("it")) return "it";
  if (language.startsWith("es")) return "es";
  if (language.startsWith("fr")) return "fr";
  if (language.startsWith("de")) return "de";
  if (language.startsWith("zh")) return "zh-Hans";
  return "en";
}

export default async function InviteRedirect({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const requestHeaders = await headers();
  redirect(`/${preferredLocale(requestHeaders.get("accept-language"))}/invite/${encodeURIComponent(token)}`);
}

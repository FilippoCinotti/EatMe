import { notFound } from "next/navigation";
import GuestFlow, { GuestUnavailable, type InvitePayload, type InviteProblem } from "../../../components/guest-flow";
import { isLocale } from "../../../lib/i18n";

const invitation: InvitePayload = {
  event: {
    title: "Saturday dinner",
    starts_at: "2030-09-21T19:30:00+02:00",
    timezone: "Europe/Rome",
    location: "Home",
    host_name: "Alex",
  },
  guest: { display_name: "Sam", status: "invited" },
  response: null,
  questionnaire: {
    // Same codes the API sends (services/api/eatme/catalog.py, dinners.EATING_STYLES).
    eating_styles: ["balanced", "flexitarian", "gluten-free", "mediterranean", "omnivore", "pescatarian", "plant-forward", "vegan", "vegetarian"],
    allergies: ["gluten", "crustaceans", "eggs", "fish", "peanut", "soy", "milk", "nuts", "wheat", "celery", "mustard", "sesame"],
    intolerances: ["lactose", "fructose", "sorbitol", "fructans"],
    sensitivities: ["caffeine", "alcohol", "spicy_food", "histamine"],
    avoidances: [
      { id: "tomato", slug: "tomato", name: { en: "Tomato", it: "Pomodoro", es: "Tomate", fr: "Tomate", de: "Tomate", "zh-Hans": "番茄" } },
      { id: "mushroom", slug: "mushroom", name: { en: "Mushrooms", it: "Funghi", es: "Setas", fr: "Champignons", de: "Pilze", "zh-Hans": "蘑菇" } },
    ],
    note_max_length: 500,
  },
  expires_at: "2030-09-22T19:30:00+02:00",
};

const steps: Record<string, number> = {
  landing: 0,
  "eating-style": 1,
  allergies: 2,
  intolerances: 3,
  avoidances: 4,
  note: 5,
  review: 6,
  success: 7,
  edit: 7,
  error: 6,
};

export default async function ScreenshotFixture({
  params,
  searchParams,
}: {
  params: Promise<{ state: string }>;
  searchParams: Promise<{ locale?: string }>;
}) {
  if (process.env.SCREENSHOT_MODE !== "1") notFound();
  const { state } = await params;
  const query = await searchParams;
  const locale = query.locale && isLocale(query.locale) ? query.locale : "en";
  if (["expired", "revoked", "cancelled", "network", "unavailable"].includes(state)) {
    return <GuestUnavailable locale={locale} problem={state as InviteProblem} />;
  }
  if (!(state in steps)) notFound();
  const withResponse = state === "edit";
  const fixture = withResponse
    ? {
        ...invitation,
        response: {
          rsvp: "accepted" as const,
          eating_style: "mediterranean",
          settings: { diets: [], allergies: ["peanut"], intolerances: [], sensitivities: [], never_suggest: [] },
          note: "No shared serving utensils, please.",
          remember_me: false,
        },
      }
    : invitation;
  return (
    <GuestFlow
      api="https://api.eatme.invalid/api/v1"
      initialStatus={state === "error" ? "error" : state === "success" ? "saved" : "idle"}
      initialRsvp={state === "landing" ? undefined : "accepted"}
      initialStep={steps[state]}
      invitation={fixture}
      locale={locale}
      token="screenshot-fixture-token"
    />
  );
}

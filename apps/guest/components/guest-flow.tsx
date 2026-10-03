"use client";

import { useEffect, useMemo, useState } from "react";
import { copy, locales, type Locale } from "../lib/i18n";
import { optionName } from "../lib/options";

type FoodOption = { id: string; slug?: string; name: Record<string, string> };
type Settings = {
  diets: { diet_id: string; strictness: string }[];
  allergies: string[];
  intolerances: string[];
  sensitivities: string[];
  never_suggest: string[];
};
type GuestResponse = {
  rsvp: "accepted" | "declined";
  eating_style: string | null;
  settings: Settings;
  note: string;
  remember_me: boolean;
};
export type InvitePayload = {
  event: { title: string; starts_at: string; timezone: string; location: string | null; host_name: string };
  guest: { display_name: string; status: string };
  response: GuestResponse | null;
  questionnaire: {
    eating_styles: string[];
    allergies: string[];
    intolerances: string[];
    sensitivities: string[];
    avoidances: FoodOption[];
    note_max_length: number;
  };
  expires_at: string;
};
export type InviteProblem = "unavailable" | "expired" | "revoked" | "cancelled" | "network";
type Rsvp = "accepted" | "declined";

// Steps: 0 answer, 1 eating style, 2 allergies, 3 intolerances, 4 sensitivities and
// avoidances, 5 note, 6 review, 7 saved, 8 deleted. Guests who decline skip 1–4.
const REVIEW = 6;
const SAVED = 7;
const DELETED = 8;

/** The EatMe two-leaf mark, same geometry as the app and the public site. */
function LeafMark() {
  return (
    <svg aria-hidden="true" className="leaf" viewBox="0 0 24 24">
      <path d="M2.2 15.2C2.9 7.4 9.1 2.1 18.4 1.2c-.3 8.6-5.2 15-12.1 17-2.2.6-4.3-.8-4.1-3Z" />
      <path d="M13.7 17.2c.3-5 4.3-8 9.3-9.2 0 5-3 9-8 10Z" />
      <path className="vein" d="M4.7 18.8C8 14.6 11.5 10.6 16.7 5.6" />
    </svg>
  );
}

export function Wordmark() {
  return (
    <div aria-label="EatMe+" className="brand" role="img">
      <LeafMark />
      <span aria-hidden="true">EatMe<span className="plus">+</span></span>
    </div>
  );
}

export function GuestUnavailable({ locale, problem }: { locale: Locale; problem: InviteProblem }) {
  const t = copy[locale];
  const title = problem === "unavailable" ? t.unavailable : t[problem];
  const detail = problem === "unavailable" ? t.unavailableDetail : t[`${problem}Detail` as keyof typeof t];
  useDocumentLanguage(locale);
  return (
    <main className="centered">
      <Wordmark />
      <section className="card">
        <span className="eyebrow">{t.invitation}</span>
        <h1>{title}</h1>
        <p>{detail}</p>
      </section>
    </main>
  );
}

function useDocumentLanguage(locale: Locale) {
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);
}

function ToggleList({
  legend,
  options,
  selected,
  onChange,
  optionLabel,
}: {
  legend: string;
  options: string[];
  selected: string[];
  onChange: (values: string[]) => void;
  optionLabel: (value: string) => string;
}) {
  return (
    <fieldset>
      <legend>{legend}</legend>
      <div className="choices">
        {options.map((option) => {
          const active = selected.includes(option);
          return (
            <label className={active ? "choice active" : "choice"} key={option}>
              <input
                checked={active}
                onChange={() =>
                  onChange(active ? selected.filter((item) => item !== option) : [...selected, option])
                }
                type="checkbox"
              />
              <span>{optionLabel(option)}</span>
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}

function icsText(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
}

function icsStamp(date: Date): string {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

/** Build the .ics locally: nothing about the invitation leaves the browser. */
function downloadCalendarFile(event: InvitePayload["event"], host: string) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//EatMe//Dinner RSVP//EN",
    "CALSCALE:GREGORIAN",
    "BEGIN:VEVENT",
    `UID:${crypto.randomUUID()}@eatme.invalid`,
    `DTSTAMP:${icsStamp(new Date())}`,
    `DTSTART:${icsStamp(new Date(event.starts_at))}`,
    `SUMMARY:${icsText(event.title)}`,
    `DESCRIPTION:${icsText(host)}`,
    ...(event.location ? [`LOCATION:${icsText(event.location)}`] : []),
    "END:VEVENT",
    "END:VCALENDAR",
  ];
  const url = URL.createObjectURL(new Blob([lines.join("\r\n")], { type: "text/calendar;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = "eatme-dinner.ics";
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}

export default function GuestFlow({
  api,
  invitation,
  locale,
  token,
  initialStep,
  initialStatus = "idle",
  initialRsvp,
}: {
  api: string;
  invitation: InvitePayload;
  locale: Locale;
  token: string;
  initialStep?: number;
  initialStatus?: "idle" | "saving" | "saved" | "deleted" | "error";
  initialRsvp?: Rsvp;
}) {
  const t = copy[locale];
  const prior = invitation.response;
  const [step, setStep] = useState(initialStep ?? (prior ? SAVED : 0));
  // No answer is preselected: the guest has to choose.
  const [rsvp, setRsvp] = useState<Rsvp | null>(prior?.rsvp ?? initialRsvp ?? null);
  const [style, setStyle] = useState(prior?.eating_style ?? "");
  const [allergies, setAllergies] = useState(prior?.settings.allergies ?? []);
  const [intolerances, setIntolerances] = useState(prior?.settings.intolerances ?? []);
  const [sensitivities, setSensitivities] = useState(prior?.settings.sensitivities ?? []);
  const [avoidances, setAvoidances] = useState(prior?.settings.never_suggest ?? []);
  const [note, setNote] = useState(prior?.note ?? "");
  const [remember, setRemember] = useState(prior?.remember_me ?? false);
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "deleted" | "error">(initialStatus);
  const endpoint = `${api}/guest/invites/${encodeURIComponent(token)}/response`;
  const declined = rsvp === "declined";
  useDocumentLanguage(locale);
  const date = useMemo(
    () =>
      new Intl.DateTimeFormat(locale === "zh-Hans" ? "zh-CN" : locale, {
        dateStyle: "full",
        timeStyle: "short",
        timeZone: invitation.event.timezone,
      }).format(new Date(invitation.event.starts_at)),
    [invitation.event.starts_at, invitation.event.timezone, locale],
  );
  const name = (code: string) => optionName(code, locale);
  const foodName = (id: string) => {
    const food = invitation.questionnaire.avoidances.find((item) => item.id === id);
    return food?.name[locale] ?? food?.name.en ?? food?.slug ?? id;
  };

  const submit = async () => {
    if (!rsvp) return;
    setStatus("saving");
    try {
      const response = await fetch(endpoint, {
        method: "PUT",
        cache: "no-store",
        credentials: "omit",
        referrerPolicy: "no-referrer",
        headers: { "Content-Type": "application/json" },
        // A guest who declines shares no food information.
        body: JSON.stringify({
          rsvp,
          eating_style: declined ? null : style || null,
          allergies: declined ? [] : allergies,
          intolerances: declined ? [] : intolerances,
          sensitivities: declined ? [] : sensitivities,
          avoidances: declined ? [] : avoidances,
          note,
          remember_me: declined ? false : remember,
        }),
      });
      if (!response.ok) throw new Error("save_failed");
      setStatus("saved");
      setStep(SAVED);
    } catch {
      setStatus("error");
    }
  };

  const remove = async () => {
    setStatus("saving");
    try {
      const response = await fetch(endpoint, {
        method: "DELETE",
        cache: "no-store",
        credentials: "omit",
        referrerPolicy: "no-referrer",
      });
      if (!response.ok) throw new Error("delete_failed");
      setStatus("deleted");
      setStep(DELETED);
    } catch {
      setStatus("error");
    }
  };

  const list = (values: string[], label: (value: string) => string) =>
    values.length ? values.map(label).join(", ") : t.none;
  const next = () => setStep((value) => (declined && value === 0 ? 5 : Math.min(value + 1, REVIEW)));
  const back = () => setStep((value) => (declined && value === 5 ? 0 : Math.max(value - 1, 0)));
  const progressSteps = declined ? [0, 5, REVIEW] : [0, 1, 2, 3, 4, 5, REVIEW];
  const progress = (progressSteps.indexOf(step) + 1) / progressSteps.length;

  return (
    <main>
      <header>
        <Wordmark />
        <nav aria-label="Language">
          {locales.map((item) => (
            <a aria-current={item === locale ? "page" : undefined} href={`/${item}/invite/${token}`} key={item} lang={item}>
              {item === "zh-Hans" ? "中文" : item.toUpperCase()}
            </a>
          ))}
        </nav>
      </header>

      <section className="card event">
        <span className="eyebrow">{t.invitation}</span>
        <h1>{invitation.event.title}</h1>
        <dl className="event-grid">
          <div className="wide"><dt>{t.when}</dt><dd>{date}</dd></div>
          <div><dt>{t.invitedBy}</dt><dd>{invitation.event.host_name}</dd></div>
          {invitation.event.location && <div><dt>{t.where}</dt><dd>{invitation.event.location}</dd></div>}
        </dl>
        <button className="pill-link" onClick={() => downloadCalendarFile(invitation.event, `${t.invitedBy}: ${invitation.event.host_name}`)} type="button">
          <svg aria-hidden="true" viewBox="0 0 24 24"><rect height="17" rx="3" width="18" x="3" y="4.5" /><path d="M3 9.5h18M8 2.5v4M16 2.5v4" /></svg>
          {t.addToCalendar}
        </button>
      </section>

      <section className="card form-card">
        {step < SAVED && (
          <div aria-hidden="true" className="progress"><span style={{ width: `${progress * 100}%` }} /></div>
        )}

        {step === 0 && (
          <fieldset>
            <legend>{t.attendQuestion.replace("{name}", invitation.guest.display_name)}</legend>
            <div className="large-choices">
              <button aria-pressed={rsvp === "accepted"} className={rsvp === "accepted" ? "answer selected" : "answer"} onClick={() => setRsvp("accepted")} type="button">{t.attending}</button>
              <button aria-pressed={rsvp === "declined"} className={rsvp === "declined" ? "answer selected" : "answer"} onClick={() => setRsvp("declined")} type="button">{t.notAttending}</button>
            </div>
          </fieldset>
        )}
        {step === 1 && (
          <fieldset>
            <legend>{t.eatingStyle}</legend>
            <div className="choices">
              <label className={!style ? "choice active" : "choice"}>
                <input checked={!style} name="style" onChange={() => setStyle("")} type="radio" />
                <span>{t.none}</span>
              </label>
              {invitation.questionnaire.eating_styles.map((item) => (
                <label className={style === item ? "choice active" : "choice"} key={item}>
                  <input checked={style === item} name="style" onChange={() => setStyle(item)} type="radio" />
                  <span>{name(item)}</span>
                </label>
              ))}
            </div>
          </fieldset>
        )}
        {step === 2 && <ToggleList legend={t.allergies} onChange={setAllergies} optionLabel={name} options={invitation.questionnaire.allergies} selected={allergies} />}
        {step === 3 && <ToggleList legend={t.intolerances} onChange={setIntolerances} optionLabel={name} options={invitation.questionnaire.intolerances} selected={intolerances} />}
        {step === 4 && (
          <>
            <ToggleList legend={t.sensitivities} onChange={setSensitivities} optionLabel={name} options={invitation.questionnaire.sensitivities} selected={sensitivities} />
            {invitation.questionnaire.avoidances.length > 0 && (
              <ToggleList
                legend={t.avoidances}
                onChange={setAvoidances}
                optionLabel={foodName}
                options={invitation.questionnaire.avoidances.map((item) => item.id)}
                selected={avoidances}
              />
            )}
          </>
        )}
        {step === 5 && (
          <>
            <label className="text-label" htmlFor="note">{t.note} <small>{t.optional}</small></label>
            <p className="hint">{t.noteHint}</p>
            <textarea id="note" maxLength={invitation.questionnaire.note_max_length} onChange={(event) => setNote(event.target.value)} rows={5} value={note} />
            {!declined && (
              <label className="remember">
                <input checked={remember} onChange={(event) => setRemember(event.target.checked)} type="checkbox" />
                <span><strong>{t.remember}</strong><small>{t.rememberDetail}</small></span>
              </label>
            )}
          </>
        )}
        {step === REVIEW && (
          <>
            <h2>{t.review}</h2>
            <dl className="review">
              <div><dt>{t.response}</dt><dd>{rsvp === "accepted" ? t.attending : t.notAttending}</dd></div>
              {!declined && (
                <>
                  <div><dt>{t.eatingStyle}</dt><dd>{style ? name(style) : t.none}</dd></div>
                  <div><dt>{t.allergies}</dt><dd>{list(allergies, name)}</dd></div>
                  <div><dt>{t.intolerances}</dt><dd>{list(intolerances, name)}</dd></div>
                  <div><dt>{t.sensitivities}</dt><dd>{list(sensitivities, name)}</dd></div>
                  <div><dt>{t.avoidances}</dt><dd>{list(avoidances, foodName)}</dd></div>
                </>
              )}
              {note && <div><dt>{t.note}</dt><dd>{note}</dd></div>}
            </dl>
          </>
        )}
        {step === SAVED && (
          <div className="result">
            <div aria-hidden="true" className="success-mark">
              <svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
            </div>
            <h2>{t.saved}</h2>
            <div className="result-actions">
              <button className="secondary" onClick={() => { setStatus("idle"); setStep(0); }} type="button">{t.editResponse}</button>
              <button className="danger" disabled={status === "saving"} onClick={remove} type="button">{t.deleteResponse}</button>
            </div>
          </div>
        )}
        {step === DELETED && <div className="result"><h2>{t.deleted}</h2></div>}

        {status === "error" && <p className="error" role="alert">{t.error}</p>}
        {step < SAVED && (
          <div className="actions">
            {step === 0 && !rsvp && <p className="hint inline">{t.chooseAnswer}</p>}
            {step > 0 && <button className="secondary" onClick={back} type="button">{t.back}</button>}
            {step < REVIEW && <button disabled={step === 0 && !rsvp} onClick={next} type="button">{t.continue}</button>}
            {step === REVIEW && <button disabled={status === "saving"} onClick={submit} type="button">{prior ? t.update : t.submit}</button>}
          </div>
        )}
      </section>

      <aside className="privacy">
        <strong>{t.privacy}</strong>
        <p>{t.privacyDetail}</p>
      </aside>
    </main>
  );
}

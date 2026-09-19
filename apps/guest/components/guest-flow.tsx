"use client";

import { useMemo, useState } from "react";
import { copy, locales, type Locale } from "../lib/i18n";

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

export function GuestUnavailable({ locale, problem }: { locale: Locale; problem: InviteProblem }) {
  const t = copy[locale];
  const title = problem === "unavailable" ? t.unavailable : t[problem];
  const detail = problem === "unavailable" ? t.unavailableDetail : t[`${problem}Detail` as keyof typeof t];
  return (
    <main className="centered">
      <div className="brand">EatMe</div>
      <section className="card">
        <span className="eyebrow">{t.invitation}</span>
        <h1>{title}</h1>
        <p>{detail}</p>
      </section>
    </main>
  );
}

function label(value: string): string {
  return value.replaceAll("_", " ").replaceAll("-", " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function ToggleList({
  legend,
  options,
  selected,
  onChange,
  optionLabel = label,
}: {
  legend: string;
  options: string[];
  selected: string[];
  onChange: (values: string[]) => void;
  optionLabel?: (value: string) => string;
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

export default function GuestFlow({
  api,
  invitation,
  locale,
  token,
  initialStep,
  initialStatus = "idle",
}: {
  api: string;
  invitation: InvitePayload;
  locale: Locale;
  token: string;
  initialStep?: number;
  initialStatus?: "idle" | "saving" | "saved" | "deleted" | "error";
}) {
  const t = copy[locale];
  const prior = invitation.response;
  const [step, setStep] = useState(initialStep ?? (prior ? 7 : 0));
  const [rsvp, setRsvp] = useState<"accepted" | "declined">(prior?.rsvp ?? "accepted");
  const [style, setStyle] = useState(prior?.eating_style ?? "");
  const [allergies, setAllergies] = useState(prior?.settings.allergies ?? []);
  const [intolerances, setIntolerances] = useState(prior?.settings.intolerances ?? []);
  const [sensitivities, setSensitivities] = useState(prior?.settings.sensitivities ?? []);
  const [avoidances, setAvoidances] = useState(prior?.settings.never_suggest ?? []);
  const [note, setNote] = useState(prior?.note ?? "");
  const [remember, setRemember] = useState(prior?.remember_me ?? false);
  const [status, setStatus] = useState<"idle" | "saving" | "saved" | "deleted" | "error">(initialStatus);
  const endpoint = `${api}/guest/invites/${encodeURIComponent(token)}/response`;
  const date = useMemo(
    () =>
      new Intl.DateTimeFormat(locale === "zh-Hans" ? "zh-CN" : locale, {
        dateStyle: "full",
        timeStyle: "short",
        timeZone: invitation.event.timezone,
      }).format(new Date(invitation.event.starts_at)),
    [invitation.event.starts_at, invitation.event.timezone, locale],
  );

  const submit = async () => {
    setStatus("saving");
    try {
      const response = await fetch(endpoint, {
        method: "PUT",
        cache: "no-store",
        credentials: "omit",
        referrerPolicy: "no-referrer",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          rsvp,
          eating_style: style || null,
          allergies,
          intolerances,
          sensitivities,
          avoidances,
          note,
          remember_me: remember,
        }),
      });
      if (!response.ok) throw new Error("save_failed");
      setStatus("saved");
      setStep(7);
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
      setStep(8);
    } catch {
      setStatus("error");
    }
  };

  const selected = (values: string[]) => (values.length ? values.map(label).join(", ") : t.none);
  const next = () => setStep((value) => Math.min(value + 1, 6));
  const back = () => setStep((value) => Math.max(value - 1, 0));

  return (
    <main>
      <header>
        <div className="brand">EatMe</div>
        <nav aria-label="Language">
          {locales.map((item) => (
            <a aria-current={item === locale ? "page" : undefined} href={`/${item}/invite/${token}`} key={item}>
              {item === "zh-Hans" ? "中文" : item.toUpperCase()}
            </a>
          ))}
        </nav>
      </header>

      <section className="event card">
        <span className="eyebrow">{t.invitation}</span>
        <h1>{invitation.event.title}</h1>
        <div className="event-grid">
          <p><small>{t.invitedBy}</small>{invitation.event.host_name}</p>
          <p><small>{t.when}</small>{date}</p>
          {invitation.event.location && <p><small>{t.where}</small>{invitation.event.location}</p>}
        </div>
      </section>

      <section className="card form-card">
        {step < 7 && <div className="progress"><span style={{ width: `${((step + 1) / 7) * 100}%` }} /></div>}

        {step === 0 && (
          <>
            <h2>{invitation.guest.display_name}, {t.attending}?</h2>
            <div className="large-choices">
              <button className={rsvp === "accepted" ? "selected" : "secondary"} onClick={() => setRsvp("accepted")}>{t.attending}</button>
              <button className={rsvp === "declined" ? "selected" : "secondary"} onClick={() => setRsvp("declined")}>{t.notAttending}</button>
            </div>
          </>
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
                  <span>{label(item)}</span>
                </label>
              ))}
            </div>
          </fieldset>
        )}
        {step === 2 && <ToggleList legend={t.allergies} onChange={setAllergies} options={invitation.questionnaire.allergies} selected={allergies} />}
        {step === 3 && <ToggleList legend={t.intolerances} onChange={setIntolerances} options={invitation.questionnaire.intolerances} selected={intolerances} />}
        {step === 4 && (
          <>
            <ToggleList legend={t.sensitivities} onChange={setSensitivities} options={invitation.questionnaire.sensitivities} selected={sensitivities} />
            <ToggleList
              legend={t.avoidances}
              onChange={setAvoidances}
              options={invitation.questionnaire.avoidances.map((item) => item.id)}
              selected={avoidances}
              optionLabel={(id) => {
                const food = invitation.questionnaire.avoidances.find((item) => item.id === id);
                return food?.name[locale] ?? food?.name.en ?? food?.slug ?? id;
              }}
            />
          </>
        )}
        {step === 5 && (
          <>
            <label className="text-label" htmlFor="note">{t.note} <small>{t.optional}</small></label>
            <p className="hint">{t.noteHint}</p>
            <textarea id="note" maxLength={invitation.questionnaire.note_max_length} onChange={(event) => setNote(event.target.value)} rows={5} value={note} />
            <label className="remember">
              <input checked={remember} onChange={(event) => setRemember(event.target.checked)} type="checkbox" />
              <span><strong>{t.remember}</strong><small>{t.rememberDetail}</small></span>
            </label>
          </>
        )}
        {step === 6 && (
          <>
            <h2>{t.review}</h2>
            <dl className="review">
              <div><dt>RSVP</dt><dd>{rsvp === "accepted" ? t.yes : t.no}</dd></div>
              <div><dt>{t.eatingStyle}</dt><dd>{style ? label(style) : t.none}</dd></div>
              <div><dt>{t.allergies}</dt><dd>{selected(allergies)}</dd></div>
              <div><dt>{t.intolerances}</dt><dd>{selected(intolerances)}</dd></div>
              <div><dt>{t.sensitivities}</dt><dd>{selected(sensitivities)}</dd></div>
              <div><dt>{t.avoidances}</dt><dd>{avoidances.length || t.none}</dd></div>
              {note && <div><dt>{t.note}</dt><dd>{note}</dd></div>}
            </dl>
          </>
        )}
        {step === 7 && (
          <div className="result">
            <div className="success-mark">✓</div>
            <h2>{t.saved}</h2>
            <button className="secondary" onClick={() => { setStatus("idle"); setStep(0); }}>{t.editResponse}</button>
            <button className="danger" disabled={status === "saving"} onClick={remove}>{t.deleteResponse}</button>
          </div>
        )}
        {step === 8 && <div className="result"><h2>{t.deleted}</h2></div>}

        {status === "error" && <p className="error" role="alert">{t.error}</p>}
        {step < 7 && (
          <div className="actions">
            {step > 0 && <button className="secondary" onClick={back}>{t.back}</button>}
            {step < 6 && <button onClick={next}>{t.continue}</button>}
            {step === 6 && <button disabled={status === "saving"} onClick={submit}>{prior ? t.update : t.submit}</button>}
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

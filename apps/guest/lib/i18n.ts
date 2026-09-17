export const locales = ["en", "it", "es", "fr", "de", "zh-Hans"] as const;
export type Locale = (typeof locales)[number];

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export type Copy = {
  invitation: string;
  invitedBy: string;
  when: string;
  where: string;
  attending: string;
  notAttending: string;
  continue: string;
  back: string;
  submit: string;
  update: string;
  deleteResponse: string;
  editResponse: string;
  eatingStyle: string;
  allergies: string;
  intolerances: string;
  sensitivities: string;
  avoidances: string;
  note: string;
  noteHint: string;
  none: string;
  optional: string;
  review: string;
  remember: string;
  rememberDetail: string;
  saved: string;
  deleted: string;
  unavailable: string;
  unavailableDetail: string;
  privacy: string;
  privacyDetail: string;
  error: string;
  yes: string;
  no: string;
};

export const copy: Record<Locale, Copy> = {
  en: {
    invitation: "Dinner invitation",
    invitedBy: "Invited by",
    when: "When",
    where: "Where",
    attending: "I’ll be there",
    notAttending: "I can’t attend",
    continue: "Continue",
    back: "Back",
    submit: "Send response",
    update: "Update response",
    deleteResponse: "Delete my response",
    editResponse: "Edit my response",
    eatingStyle: "Eating style",
    allergies: "Allergies",
    intolerances: "Intolerances",
    sensitivities: "Sensitivities",
    avoidances: "Foods to avoid",
    note: "Note for the host",
    noteHint: "Only add information the host needs to plan this dinner.",
    none: "None",
    optional: "Optional",
    review: "Review",
    remember: "Remember my preferences",
    rememberDetail: "Save these choices for future dinners with this household. You can opt out now or delete your response later.",
    saved: "Your response is saved.",
    deleted: "Your response was deleted.",
    unavailable: "This invitation is unavailable",
    unavailableDetail: "It may have expired, been replaced, or the dinner may have been cancelled. Ask the host for a new link.",
    privacy: "Your privacy",
    privacyDetail: "Your answers are used only to plan this dinner unless you explicitly ask the household to remember them.",
    error: "We couldn’t save that. Check the link and try again.",
    yes: "Yes",
    no: "No",
  },
  it: {
    invitation: "Invito a cena", invitedBy: "Invito di", when: "Quando", where: "Dove",
    attending: "Ci sarò", notAttending: "Non posso partecipare", continue: "Continua", back: "Indietro",
    submit: "Invia risposta", update: "Aggiorna risposta", deleteResponse: "Elimina la mia risposta",
    editResponse: "Modifica la risposta", eatingStyle: "Stile alimentare", allergies: "Allergie",
    intolerances: "Intolleranze", sensitivities: "Sensibilità", avoidances: "Alimenti da evitare",
    note: "Nota per chi ospita", noteHint: "Aggiungi solo ciò che serve per organizzare questa cena.",
    none: "Nessuna", optional: "Facoltativo", review: "Riepilogo", remember: "Ricorda le mie preferenze",
    rememberDetail: "Salva queste scelte per le prossime cene con questo nucleo. Puoi rifiutare ora o eliminare la risposta in seguito.",
    saved: "La tua risposta è stata salvata.", deleted: "La tua risposta è stata eliminata.",
    unavailable: "Questo invito non è disponibile",
    unavailableDetail: "Potrebbe essere scaduto, sostituito oppure la cena è stata annullata. Chiedi un nuovo link.",
    privacy: "La tua privacy",
    privacyDetail: "Le risposte servono solo per organizzare questa cena, salvo tua richiesta esplicita di ricordarle.",
    error: "Non è stato possibile salvare. Controlla il link e riprova.", yes: "Sì", no: "No",
  },
  es: {
    invitation: "Invitación a cenar", invitedBy: "Invitación de", when: "Cuándo", where: "Dónde",
    attending: "Asistiré", notAttending: "No puedo asistir", continue: "Continuar", back: "Atrás",
    submit: "Enviar respuesta", update: "Actualizar respuesta", deleteResponse: "Eliminar mi respuesta",
    editResponse: "Editar mi respuesta", eatingStyle: "Estilo de alimentación", allergies: "Alergias",
    intolerances: "Intolerancias", sensitivities: "Sensibilidades", avoidances: "Alimentos a evitar",
    note: "Nota para quien invita", noteHint: "Añade solo lo necesario para organizar esta cena.",
    none: "Ninguna", optional: "Opcional", review: "Revisar", remember: "Recordar mis preferencias",
    rememberDetail: "Guarda estas opciones para futuras cenas con este hogar. Puedes rechazarlo o eliminar tu respuesta después.",
    saved: "Tu respuesta se ha guardado.", deleted: "Tu respuesta se ha eliminado.",
    unavailable: "Esta invitación no está disponible",
    unavailableDetail: "Puede haber caducado, sido reemplazada o la cena puede haberse cancelado. Pide un enlace nuevo.",
    privacy: "Tu privacidad", privacyDetail: "Tus respuestas solo se usan para organizar esta cena, salvo que pidas guardarlas.",
    error: "No pudimos guardar la respuesta. Comprueba el enlace e inténtalo de nuevo.", yes: "Sí", no: "No",
  },
  fr: {
    invitation: "Invitation à dîner", invitedBy: "Invitation de", when: "Quand", where: "Où",
    attending: "Je serai là", notAttending: "Je ne peux pas venir", continue: "Continuer", back: "Retour",
    submit: "Envoyer la réponse", update: "Mettre à jour", deleteResponse: "Supprimer ma réponse",
    editResponse: "Modifier ma réponse", eatingStyle: "Style alimentaire", allergies: "Allergies",
    intolerances: "Intolérances", sensitivities: "Sensibilités", avoidances: "Aliments à éviter",
    note: "Note pour l’hôte", noteHint: "Ajoutez uniquement les informations utiles pour ce dîner.",
    none: "Aucune", optional: "Facultatif", review: "Vérifier", remember: "Mémoriser mes préférences",
    rememberDetail: "Enregistrez ces choix pour de futurs dîners avec ce foyer. Vous pouvez refuser ou supprimer votre réponse.",
    saved: "Votre réponse est enregistrée.", deleted: "Votre réponse a été supprimée.",
    unavailable: "Cette invitation n’est pas disponible",
    unavailableDetail: "Elle a peut-être expiré, été remplacée ou le dîner a été annulé. Demandez un nouveau lien.",
    privacy: "Votre vie privée", privacyDetail: "Vos réponses servent uniquement à préparer ce dîner, sauf demande explicite de mémorisation.",
    error: "Impossible d’enregistrer. Vérifiez le lien et réessayez.", yes: "Oui", no: "Non",
  },
  de: {
    invitation: "Einladung zum Abendessen", invitedBy: "Eingeladen von", when: "Wann", where: "Wo",
    attending: "Ich bin dabei", notAttending: "Ich kann nicht teilnehmen", continue: "Weiter", back: "Zurück",
    submit: "Antwort senden", update: "Antwort aktualisieren", deleteResponse: "Meine Antwort löschen",
    editResponse: "Antwort bearbeiten", eatingStyle: "Ernährungsstil", allergies: "Allergien",
    intolerances: "Unverträglichkeiten", sensitivities: "Empfindlichkeiten", avoidances: "Zu vermeidende Lebensmittel",
    note: "Notiz für den Gastgeber", noteHint: "Nur Informationen angeben, die für dieses Essen nötig sind.",
    none: "Keine", optional: "Optional", review: "Prüfen", remember: "Meine Vorlieben merken",
    rememberDetail: "Diese Auswahl für künftige Essen mit diesem Haushalt speichern. Du kannst ablehnen oder später löschen.",
    saved: "Deine Antwort wurde gespeichert.", deleted: "Deine Antwort wurde gelöscht.",
    unavailable: "Diese Einladung ist nicht verfügbar",
    unavailableDetail: "Sie ist möglicherweise abgelaufen, ersetzt oder das Essen wurde abgesagt. Bitte um einen neuen Link.",
    privacy: "Deine Privatsphäre", privacyDetail: "Deine Antworten werden nur für dieses Essen genutzt, sofern du das Speichern nicht erlaubst.",
    error: "Die Antwort konnte nicht gespeichert werden. Prüfe den Link und versuche es erneut.", yes: "Ja", no: "Nein",
  },
  "zh-Hans": {
    invitation: "晚餐邀请", invitedBy: "邀请人", when: "时间", where: "地点",
    attending: "我会参加", notAttending: "我无法参加", continue: "继续", back: "返回",
    submit: "提交回复", update: "更新回复", deleteResponse: "删除我的回复", editResponse: "编辑回复",
    eatingStyle: "饮食方式", allergies: "过敏", intolerances: "不耐受", sensitivities: "敏感项",
    avoidances: "需要避免的食物", note: "给主人的备注", noteHint: "仅填写筹备本次晚餐所需的信息。",
    none: "无", optional: "可选", review: "确认", remember: "记住我的偏好",
    rememberDetail: "为今后与此家庭的晚餐保存这些选择。你现在可拒绝，也可稍后删除回复。",
    saved: "你的回复已保存。", deleted: "你的回复已删除。", unavailable: "此邀请不可用",
    unavailableDetail: "邀请可能已过期、被替换，或晚餐已取消。请向主人索取新链接。",
    privacy: "你的隐私", privacyDetail: "除非你明确同意保存，否则回答只用于筹备本次晚餐。",
    error: "无法保存。请检查链接后重试。", yes: "是", no: "否",
  },
};

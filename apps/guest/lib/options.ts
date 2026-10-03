import type { Locale } from "./i18n";

// Localized names for the questionnaire codes sent by the API
// (services/api/eatme/catalog.py and dinners.EATING_STYLES). English and
// Italian match the mobile app's allergen_/intolerance_/sensitivity_ strings.
type Names = Record<Locale, string>;

const names: Record<string, Names> = {
  // Eating styles
  omnivore: { en: "Omnivore", it: "Onnivoro", es: "Omnívoro", fr: "Omnivore", de: "Allesesser", "zh-Hans": "杂食" },
  balanced: { en: "Balanced", it: "Equilibrato", es: "Equilibrado", fr: "Équilibré", de: "Ausgewogen", "zh-Hans": "均衡饮食" },
  mediterranean: { en: "Mediterranean", it: "Mediterraneo", es: "Mediterráneo", fr: "Méditerranéen", de: "Mediterran", "zh-Hans": "地中海饮食" },
  vegetarian: { en: "Vegetarian", it: "Vegetariano", es: "Vegetariano", fr: "Végétarien", de: "Vegetarisch", "zh-Hans": "素食" },
  vegan: { en: "Vegan", it: "Vegano", es: "Vegano", fr: "Végan", de: "Vegan", "zh-Hans": "纯素" },
  pescatarian: { en: "Pescatarian", it: "Pescetariano", es: "Pescetariano", fr: "Pescétarien", de: "Pescetarisch", "zh-Hans": "鱼素" },
  flexitarian: { en: "Flexitarian", it: "Flexitariano", es: "Flexitariano", fr: "Flexitarien", de: "Flexitarisch", "zh-Hans": "弹性素食" },
  "plant-forward": { en: "Mostly plant-based", it: "Prevalentemente vegetale", es: "Principalmente vegetal", fr: "Surtout végétal", de: "Überwiegend pflanzlich", "zh-Hans": "以植物为主" },
  "gluten-free": { en: "Gluten-free", it: "Senza glutine", es: "Sin gluten", fr: "Sans gluten", de: "Glutenfrei", "zh-Hans": "无麸质" },
  // Allergens
  gluten: { en: "Gluten", it: "Glutine", es: "Gluten", fr: "Gluten", de: "Gluten", "zh-Hans": "麸质" },
  crustaceans: { en: "Crustaceans", it: "Crostacei", es: "Crustáceos", fr: "Crustacés", de: "Krebstiere", "zh-Hans": "甲壳类" },
  eggs: { en: "Eggs", it: "Uova", es: "Huevos", fr: "Œufs", de: "Eier", "zh-Hans": "蛋类" },
  fish: { en: "Fish", it: "Pesce", es: "Pescado", fr: "Poisson", de: "Fisch", "zh-Hans": "鱼类" },
  peanut: { en: "Peanuts", it: "Arachidi", es: "Cacahuetes", fr: "Arachides", de: "Erdnüsse", "zh-Hans": "花生" },
  soy: { en: "Soy", it: "Soia", es: "Soja", fr: "Soja", de: "Soja", "zh-Hans": "大豆" },
  milk: { en: "Milk", it: "Latte", es: "Leche", fr: "Lait", de: "Milch", "zh-Hans": "牛奶" },
  nuts: { en: "Tree nuts", it: "Frutta a guscio", es: "Frutos de cáscara", fr: "Fruits à coque", de: "Schalenfrüchte", "zh-Hans": "坚果" },
  wheat: { en: "Wheat", it: "Frumento", es: "Trigo", fr: "Blé", de: "Weizen", "zh-Hans": "小麦" },
  celery: { en: "Celery", it: "Sedano", es: "Apio", fr: "Céleri", de: "Sellerie", "zh-Hans": "芹菜" },
  mustard: { en: "Mustard", it: "Senape", es: "Mostaza", fr: "Moutarde", de: "Senf", "zh-Hans": "芥末" },
  sesame: { en: "Sesame", it: "Sesamo", es: "Sésamo", fr: "Sésame", de: "Sesam", "zh-Hans": "芝麻" },
  sulphites: { en: "Sulphites", it: "Solfiti", es: "Sulfitos", fr: "Sulfites", de: "Sulfite", "zh-Hans": "亚硫酸盐" },
  lupin: { en: "Lupin", it: "Lupini", es: "Altramuces", fr: "Lupin", de: "Lupinen", "zh-Hans": "羽扇豆" },
  molluscs: { en: "Molluscs", it: "Molluschi", es: "Moluscos", fr: "Mollusques", de: "Weichtiere", "zh-Hans": "软体动物" },
  almond: { en: "Almond", it: "Mandorla", es: "Almendra", fr: "Amande", de: "Mandel", "zh-Hans": "杏仁" },
  hazelnut: { en: "Hazelnut", it: "Nocciola", es: "Avellana", fr: "Noisette", de: "Haselnuss", "zh-Hans": "榛子" },
  walnut: { en: "Walnut", it: "Noce", es: "Nuez", fr: "Noix", de: "Walnuss", "zh-Hans": "核桃" },
  cashew: { en: "Cashew", it: "Anacardo", es: "Anacardo", fr: "Noix de cajou", de: "Cashewnuss", "zh-Hans": "腰果" },
  pecan: { en: "Pecan", it: "Noce pecan", es: "Pecana", fr: "Noix de pécan", de: "Pekannuss", "zh-Hans": "碧根果" },
  brazil_nut: { en: "Brazil nut", it: "Noce del Brasile", es: "Nuez de Brasil", fr: "Noix du Brésil", de: "Paranuss", "zh-Hans": "巴西坚果" },
  pistachio: { en: "Pistachio", it: "Pistacchio", es: "Pistacho", fr: "Pistache", de: "Pistazie", "zh-Hans": "开心果" },
  macadamia: { en: "Macadamia", it: "Macadamia", es: "Macadamia", fr: "Macadamia", de: "Macadamia", "zh-Hans": "夏威夷果" },
  // Intolerances
  lactose: { en: "Lactose", it: "Lattosio", es: "Lactosa", fr: "Lactose", de: "Laktose", "zh-Hans": "乳糖" },
  fructose: { en: "Fructose", it: "Fruttosio", es: "Fructosa", fr: "Fructose", de: "Fruktose", "zh-Hans": "果糖" },
  sorbitol: { en: "Sorbitol", it: "Sorbitolo", es: "Sorbitol", fr: "Sorbitol", de: "Sorbit", "zh-Hans": "山梨糖醇" },
  mannitol: { en: "Mannitol", it: "Mannitolo", es: "Manitol", fr: "Mannitol", de: "Mannit", "zh-Hans": "甘露醇" },
  xylitol: { en: "Xylitol", it: "Xilitolo", es: "Xilitol", fr: "Xylitol", de: "Xylit", "zh-Hans": "木糖醇" },
  maltitol: { en: "Maltitol / polyols", it: "Maltitolo / polioli", es: "Maltitol / polialcoholes", fr: "Maltitol / polyols", de: "Maltit / Polyole", "zh-Hans": "麦芽糖醇 / 多元醇" },
  fructans: { en: "Fructans", it: "Fruttani", es: "Fructanos", fr: "Fructanes", de: "Fruktane", "zh-Hans": "果聚糖" },
  gos: { en: "GOS", it: "GOS", es: "GOS", fr: "GOS", de: "GOS", "zh-Hans": "低聚半乳糖" },
  // Sensitivities
  caffeine: { en: "Caffeine", it: "Caffeina", es: "Cafeína", fr: "Caféine", de: "Koffein", "zh-Hans": "咖啡因" },
  alcohol: { en: "Alcohol", it: "Alcol", es: "Alcohol", fr: "Alcool", de: "Alkohol", "zh-Hans": "酒精" },
  spicy_food: { en: "Spicy food", it: "Cibi piccanti", es: "Comida picante", fr: "Plats épicés", de: "Scharfes Essen", "zh-Hans": "辛辣食物" },
  histamine: { en: "Histamine", it: "Istamina", es: "Histamina", fr: "Histamine", de: "Histamin", "zh-Hans": "组胺" },
};

/** Localized name for a questionnaire code; unknown codes stay readable. */
export function optionName(code: string, locale: Locale): string {
  const entry = names[code];
  if (entry) return entry[locale] ?? entry.en;
  const words = code.replaceAll("_", " ").replaceAll("-", " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

export const knownOptionCodes = Object.keys(names);

// Decorative emoji shown before an option (aria-hidden). Codes without an
// unambiguous food emoji simply have none.
const emoji: Record<string, string> = {
  omnivore: "🍗", balanced: "⚖️", mediterranean: "🫒", vegetarian: "🥕", vegan: "🌱",
  pescatarian: "🐟", flexitarian: "🥗", "plant-forward": "🥦", "gluten-free": "🌾",
  gluten: "🌾", wheat: "🌾", crustaceans: "🦐", eggs: "🥚", fish: "🐟", peanut: "🥜", soy: "🫘",
  milk: "🥛", nuts: "🌰", almond: "🌰", hazelnut: "🌰", walnut: "🌰", cashew: "🌰", pecan: "🌰",
  brazil_nut: "🌰", pistachio: "🌰", macadamia: "🌰", celery: "🥬", molluscs: "🦑", sulphites: "🍷",
  lactose: "🥛", fructose: "🍎", sorbitol: "🍬", mannitol: "🍬", xylitol: "🍬", maltitol: "🍬",
  fructans: "🧅", gos: "🫘",
  caffeine: "☕", alcohol: "🍷", spicy_food: "🌶️", histamine: "🧀",
};

export function optionEmoji(code: string): string | undefined {
  return emoji[code];
}

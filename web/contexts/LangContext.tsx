"use client";
import { createContext, useContext, useEffect, useState, useCallback } from "react";
import { Locale, TranslationKey, translations, detectLocale } from "@/lib/translations";

type LangCtx = {
  locale: Locale;
  setLocale: (l: Locale) => void;
  t: (key: TranslationKey) => string;
};

const LangContext = createContext<LangCtx>({
  locale: "en",
  setLocale: () => {},
  t: (key) => key,
});

export function LangProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en");

  useEffect(() => {
    setLocaleState(detectLocale());
  }, []);

  const setLocale = useCallback((l: Locale) => {
    localStorage.setItem("typerly_locale", l);
    setLocaleState(l);
  }, []);

  const t = useCallback(
    (key: TranslationKey) => translations[locale]?.[key] ?? translations.en[key] ?? key,
    [locale],
  );

  return <LangContext.Provider value={{ locale, setLocale, t }}>{children}</LangContext.Provider>;
}

export function useLang() {
  return useContext(LangContext);
}

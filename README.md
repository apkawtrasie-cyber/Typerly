# Typerly

Aplikacja PWA do typowania wyników sportowych. Obstawiasz wyniki meczów, zdobywasz punkty i rywalizujesz z innymi w globalnym rankingu oraz prywatnych ligach i turniejach.

🌐 **[typerly.andrzejmich.ch](https://typerly.andrzejmich.ch)**

---

## Co robi

- **Typy sportowe** — obstawiasz wyniki meczów piłki nożnej, siatkówki, piłki ręcznej i wyścigów F1
- **Punktacja 3/2/1/0** — 3 pkt za dokładny wynik, 2 za różnicę bramek (lub ±3 w piłce ręcznej), 1 za dobrego zwycięzcę, 0 za pudło
- **Ranking globalny** — wszyscy gracze, podium top 3
- **Ligi prywatne** — tworzysz ligę i zapraszasz znajomych kodem
- **Turnieje** — drabinka pucharowa z wyborem par (drag & drop)
- **Czat** — grupy z realtime wiadomościami, czaty do meczów i lig
- **Wielojęzyczność** — PL, EN, DE, FR, ES, IT

---

## Dyscypliny

| Dyscyplina | Źródło danych | Jak typujesz |
|---|---|---|
| ⚽ Piłka nożna | football-data.org + api-sports.io | Wpisujesz wynik (np. `2:1`) |
| 🏐 Siatkówka | api-sports.io | Wpisujesz sety — max `3:0`, `3:1`, `3:2` |
| 🤾 Piłka ręczna | api-sports.io | Wpisujesz bramki z tolerancją ±3 na 2 pkt |
| 🏎️ Formula 1 | ESPN (publiczne API) | Klikasz kierowcę który wygra wyścig |

---

## Stos technologiczny

```
web/        Next.js 14 (App Router) + Tailwind CSS — PWA
native/     Flutter (Android, com.typerly.typerly)
backend     Supabase (PostgreSQL + Auth + Realtime + Edge Functions)
```

### Kluczowe zależności

- `next`, `react` — frontend
- `@supabase/supabase-js` — klient bazy danych i auth
- `lucide-react` — ikony
- `@dnd-kit/*` — drag & drop w turniejach
- `sharp` — generowanie obrazu OG

---

## Algorytm punktacji

```
predictedHome == actualHome && predictedAway == actualAway  →  3 pkt
(piłka ręczna) |predHome - actHome| ≤ 3 && |predAway - actAway| ≤ 3  →  2 pkt
(inne) (predHome - predAway) == (actHome - actAway)  →  2 pkt
sign(predHome - predAway) == sign(actHome - actAway)  →  1 pkt
reszta  →  0 pkt
```

Logika po stronie klienta: `web/lib/scorer.ts`
Logika SQL: `native/supabase/migrations/014_handball_scoring.sql`

---

## Struktura projektu

```
web/
├── app/
│   ├── (app)/
│   │   ├── home/          # Strona główna — karuzela, filtr dyscyplin
│   │   ├── matches/       # Lista meczów + [id] szczegóły i typowanie
│   │   ├── f1/            # Strona F1 + [raceId] typowanie wyścigu
│   │   ├── ranking/       # Ranking globalny + moje typy
│   │   ├── leagues/       # Ligi + [id]
│   │   ├── tournaments/   # Turnieje [id]
│   │   ├── chat/          # Czat grupowy + [id]
│   │   └── profile/       # Profil, odznaki, język, konto
│   ├── login/
│   ├── register/
│   └── join/              # Dołącz przez kod
├── components/
│   ├── SportMatchesPage   # Zakładki Nadchodzące/Na żywo/Ostatnie/Tabela
│   └── SportInfoModal     # Modal z zasadami typowania dla każdej dyscypliny
├── lib/
│   ├── scorer.ts          # Obliczanie punktów (client-side)
│   ├── supabase.ts        # Typy i klient Supabase
│   └── translations.ts    # Słownik 6 języków (TranslationKey union + locale objects)
├── contexts/
│   └── LangContext.tsx    # useLang() hook — t(key), locale
└── public/
    ├── og-image.png       # Obraz Open Graph (1200×630)
    └── manifest.json      # PWA manifest

native/
├── lib/                   # Flutter — strony natywne
└── supabase/
    ├── functions/         # Edge Functions (Deno) — sync-ball-sports
    └── migrations/        # SQL migracje (001–014)
```

---

## Ustawienie lokalne

```bash
cd web
npm install
cp .env.local.example .env.local   # uzupełnij NEXT_PUBLIC_SUPABASE_URL i ANON_KEY
npm run dev
```

### Zmienne środowiskowe

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

Klucz `API_FOOTBALL_KEY` (api-sports.io) przechowywany tylko jako sekret Supabase — nigdy w repozytorium.

---

## Baza danych (główne tabele)

| Tabela | Opis |
|---|---|
| `profiles` | Użytkownicy — nick, punkty, streak, is_premium |
| `matches` | Mecze — sport_type, home/away teams, scores, status |
| `predictions` | Typy użytkowników — predicted_home/away, points |
| `f1_predictions` | Typy F1 — race_id, predicted_driver |
| `leagues` | Ligi — invite_code, prize_description |
| `tournaments` | Turnieje — bracket JSON |
| `chat_rooms` / `chat_messages` | Czat realtime |

---

## Monetyzacja

- **Google AdSense** (`ca-pub-5244367621175515`) — reklamy dla zwykłych użytkowników
- **Premium** (`is_premium` w tabeli `profiles`) — ukrywa reklamy; mechanizm płatności planowany

---

## Wdrożenie

- **Frontend:** Vercel (auto-deploy z `main`)
- **Backend:** Supabase (hosted)
- **Cron:** pg_cron + pg_net do synchronizacji wyników co kilka godzin

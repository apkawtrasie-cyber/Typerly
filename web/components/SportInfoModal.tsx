"use client";
import { X } from "lucide-react";
import { useLang } from "@/contexts/LangContext";
import type { Locale } from "@/lib/translations";

type Rule = { icon: string; text: string };
type Example = { label: string; score: string; note: string };
type SportData = { emoji: string; title: string; howTo: string; scoring: string; rules: Rule[]; example: Example };
type LangData = Record<string, SportData>;

const DATA: Record<Locale, LangData> = {
  pl: {
    football: {
      emoji: "⚽", title: "Piłka nożna",
      howTo: "Wpisz ile goli zdobędzie każda drużyna po 90 minutach gry (bez dogrywki i karnych).",
      scoring: "Wynik dokładny = 3 pkt · Dobry typ (kto wygra/remis) = 1 pkt · Pudło = 0 pkt",
      rules: [
        { icon: "⏱️", text: "Mecz trwa 2 × 45 minut = 90 minut" },
        { icon: "🚫", text: "Nie liczymy dogrywki ani rzutów karnych" },
        { icon: "🎯", text: "Dokładny wynik (np. 2:1) = 3 punkty" },
        { icon: "✅", text: "Dobry typ (np. wygrana, remis) ale zły wynik = 1 punkt" },
        { icon: "❌", text: "Zły typ = 0 punktów" },
      ],
      example: { label: "Wpisujesz: 2 : 1", score: "2 : 1", note: "Typujesz że gospodarz wygrywa 2 golami do 1" },
    },
    volleyball: {
      emoji: "🏐", title: "Siatkówka",
      howTo: "Wpisz ile setów wygra każda drużyna. Mecz trwa do 3 wygranych setów — maksymalnie 5 setów.",
      scoring: "Dokładny wynik setów = 3 pkt · Dobry zwycięzca = 1 pkt · Pudło = 0 pkt",
      rules: [
        { icon: "🔢", text: "Mecz = do 3 wygranych setów (best of 5)" },
        { icon: "✅", text: "Możliwe wyniki: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "NIE MA remisu — ktoś zawsze wygrywa" },
        { icon: "🎯", text: "Dokładny wynik setów (np. 3:1) = 3 punkty" },
        { icon: "✅", text: "Dobry zwycięzca ale zły wynik = 1 punkt" },
      ],
      example: { label: "Wpisujesz: 3 : 1", score: "3 : 1", note: "Typujesz że gospodarz wygrywa 3 sety do 1 (np. sety: 25:20, 20:25, 25:22, 25:18)" },
    },
    handball: {
      emoji: "🤾", title: "Piłka ręczna",
      howTo: "Wpisz ile bramek zdobędzie każda drużyna po 60 minutach. Typowe wyniki to 25–40 bramek na drużynę. Nie musisz trafić dokładnie — liczy się też bliskość (±3 bramki)!",
      scoring: "Dokładny wynik = 3 pkt · Oba wyniki ±3 bramki = 2 pkt · Dobry zwycięzca = 1 pkt · Pudło = 0 pkt",
      rules: [
        { icon: "⏱️", text: "Mecz trwa 2 × 30 minut = 60 minut" },
        { icon: "🥅", text: "Typowe wyniki: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Dokładny wynik = 3 pkt (np. typujesz 28:24 → pada 28:24)" },
        { icon: "⭐", text: "Oba wyniki ±3 bramki = 2 pkt (np. typujesz 28:24 → pada 30:26)" },
        { icon: "✅", text: "Dobry zwycięzca, ale za duże odchylenie = 1 pkt" },
        { icon: "❌", text: "Zły zwycięzca = 0 pkt" },
      ],
      example: { label: "Typujesz 28 : 24 → wynik 30 : 26", score: "30 : 26", note: "Różnica: +2 i +2 bramki → oba ±3 → 2 pkt ⭐\nTrafisz 28:24 dokładnie → 3 pkt 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Formuła 1",
      howTo: "Wybierz kierowcę który Twoim zdaniem wygra wyścig Grand Prix. Jeden wybór na wyścig.",
      scoring: "Trafiony zwycięzca = 3 pkt · Błędny = 0 pkt",
      rules: [
        { icon: "📋", text: "Kliknij wyścig z listy → pojawi się lista wszystkich kierowców" },
        { icon: "👆", text: "Kliknij nazwę kierowcy → podświetli się złotym kolorem" },
        { icon: "🔒", text: "Kliknij 'Typuję: [imię]' → typ zapisany, nie można zmienić" },
        { icon: "🏁", text: "Po wyścigu sprawdź czy Twój kierowca wygrał" },
        { icon: "🎯", text: "Trafiony zwycięzca = 3 punkty" },
      ],
      example: { label: "Przykład", score: "🥇 M. Verstappen", note: "Wybierasz kierowcę przed startem wyścigu" },
    },
  },
  en: {
    football: {
      emoji: "⚽", title: "Football",
      howTo: "Enter the number of goals for each team after 90 minutes (no extra time or penalties).",
      scoring: "Exact score = 3 pts · Correct outcome = 1 pt · Miss = 0 pts",
      rules: [
        { icon: "⏱️", text: "Match = 2 × 45 minutes = 90 minutes" },
        { icon: "🚫", text: "Extra time and penalties do not count" },
        { icon: "🎯", text: "Exact score (e.g. 2:1) = 3 points" },
        { icon: "✅", text: "Correct outcome (win/draw) but wrong score = 1 point" },
        { icon: "❌", text: "Wrong outcome = 0 points" },
      ],
      example: { label: "You enter: 2 : 1", score: "2 : 1", note: "You predict the home team wins 2 goals to 1" },
    },
    volleyball: {
      emoji: "🏐", title: "Volleyball",
      howTo: "Enter how many sets each team wins. A match goes to 3 sets — maximum 5 sets total.",
      scoring: "Exact set score = 3 pts · Correct winner = 1 pt · Miss = 0 pts",
      rules: [
        { icon: "🔢", text: "Match = first to 3 sets (best of 5)" },
        { icon: "✅", text: "Possible results: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "NO draws — someone always wins" },
        { icon: "🎯", text: "Exact set score (e.g. 3:1) = 3 points" },
        { icon: "✅", text: "Correct winner but wrong score = 1 point" },
      ],
      example: { label: "You enter: 3 : 1", score: "3 : 1", note: "You predict home wins 3 sets to 1 (e.g. 25:20, 20:25, 25:22, 25:18)" },
    },
    handball: {
      emoji: "🤾", title: "Handball",
      howTo: "Enter the number of goals each team scores in 60 minutes. Typical scores are 25–40 goals per team. You don't need to be exact — being close (±3 goals) also earns points!",
      scoring: "Exact score = 3 pts · Both within ±3 goals = 2 pts · Correct winner = 1 pt · Miss = 0 pts",
      rules: [
        { icon: "⏱️", text: "Match = 2 × 30 minutes = 60 minutes" },
        { icon: "🥅", text: "Typical scores: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Exact score = 3 pts (e.g. predict 28:24 → result 28:24)" },
        { icon: "⭐", text: "Both within ±3 goals = 2 pts (e.g. predict 28:24 → result 30:26)" },
        { icon: "✅", text: "Correct winner but too far off = 1 pt" },
        { icon: "❌", text: "Wrong winner = 0 pts" },
      ],
      example: { label: "Predict 28:24 → result 30:26", score: "30 : 26", note: "Difference: +2 and +2 goals → both ±3 → 2 pts ⭐\nPredict 28:24 exactly → 3 pts 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Formula 1",
      howTo: "Pick the driver you think will win the Grand Prix race. One pick per race.",
      scoring: "Correct winner = 3 pts · Wrong = 0 pts",
      rules: [
        { icon: "📋", text: "Tap a race from the list → you'll see all drivers" },
        { icon: "👆", text: "Tap a driver's name → highlights in gold" },
        { icon: "🔒", text: "Tap 'Pick: [name]' → prediction locked, cannot change" },
        { icon: "🏁", text: "After the race, check if your driver won" },
        { icon: "🎯", text: "Correct winner = 3 points" },
      ],
      example: { label: "Example", score: "🥇 M. Verstappen", note: "Pick your driver before the race starts" },
    },
  },
  de: {
    football: {
      emoji: "⚽", title: "Fußball",
      howTo: "Gib die Tore jeder Mannschaft nach 90 Minuten ein (keine Verlängerung oder Elfmeterschießen).",
      scoring: "Genaues Ergebnis = 3 Pkt · Richtiger Ausgang = 1 Pkt · Daneben = 0 Pkt",
      rules: [
        { icon: "⏱️", text: "Spiel = 2 × 45 Minuten = 90 Minuten" },
        { icon: "🚫", text: "Verlängerung und Elfmeterschießen zählen nicht" },
        { icon: "🎯", text: "Genaues Ergebnis (z.B. 2:1) = 3 Punkte" },
        { icon: "✅", text: "Richtiger Ausgang, falsches Ergebnis = 1 Punkt" },
        { icon: "❌", text: "Falscher Ausgang = 0 Punkte" },
      ],
      example: { label: "Du gibst ein: 2 : 1", score: "2 : 1", note: "Du tippst Heimsieg 2:1" },
    },
    volleyball: {
      emoji: "🏐", title: "Volleyball",
      howTo: "Gib an, wie viele Sätze jede Mannschaft gewinnt. Bis zu 3 gewonnene Sätze — max. 5 Sätze.",
      scoring: "Genaues Satzergebnis = 3 Pkt · Richtiger Gewinner = 1 Pkt · Daneben = 0 Pkt",
      rules: [
        { icon: "🔢", text: "Spiel = erste Mannschaft mit 3 Sätzen (best of 5)" },
        { icon: "✅", text: "Mögliche Ergebnisse: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "KEIN Unentschieden — immer ein Sieger" },
        { icon: "🎯", text: "Genaues Satzergebnis = 3 Punkte" },
        { icon: "✅", text: "Richtiger Gewinner, falsches Ergebnis = 1 Punkt" },
      ],
      example: { label: "Du gibst ein: 3 : 1", score: "3 : 1", note: "Du tippst Heimsieg 3 Sätze zu 1" },
    },
    handball: {
      emoji: "🤾", title: "Handball",
      howTo: "Gib die Tore jeder Mannschaft in 60 Minuten ein. Typische Ergebnisse: 25–40 Tore pro Team. Nicht exakt nötig — ±3 Tore zählt auch!",
      scoring: "Genaues Ergebnis = 3 Pkt · Beide ±3 Tore = 2 Pkt · Richtiger Sieger = 1 Pkt · Daneben = 0 Pkt",
      rules: [
        { icon: "⏱️", text: "Spiel = 2 × 30 Minuten = 60 Minuten" },
        { icon: "🥅", text: "Typische Ergebnisse: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Genaues Ergebnis = 3 Pkt (z.B. Tipp 28:24 → Ergebnis 28:24)" },
        { icon: "⭐", text: "Beide ±3 Tore = 2 Pkt (z.B. Tipp 28:24 → Ergebnis 30:26)" },
        { icon: "✅", text: "Richtiger Sieger aber zu weit weg = 1 Pkt" },
        { icon: "❌", text: "Falscher Sieger = 0 Pkt" },
      ],
      example: { label: "Tipp 28:24 → Ergebnis 30:26", score: "30 : 26", note: "Abstand: +2 und +2 Tore → beide ±3 → 2 Pkt ⭐\nTipp 28:24 exakt → 3 Pkt 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Formel 1",
      howTo: "Wähle den Fahrer, der deiner Meinung nach den Grand Prix gewinnen wird. Ein Tipp pro Rennen.",
      scoring: "Richtiger Gewinner = 3 Pkt · Falsch = 0 Pkt",
      rules: [
        { icon: "📋", text: "Rennen antippen → Liste aller Fahrer erscheint" },
        { icon: "👆", text: "Fahrernamen antippen → gold markiert" },
        { icon: "🔒", text: "'Tippe: [Name]' antippen → gespeichert, nicht änderbar" },
        { icon: "🏁", text: "Nach dem Rennen prüfen ob dein Fahrer gewonnen hat" },
        { icon: "🎯", text: "Richtiger Gewinner = 3 Punkte" },
      ],
      example: { label: "Beispiel", score: "🥇 M. Verstappen", note: "Fahrer vor dem Rennstart wählen" },
    },
  },
  fr: {
    football: {
      emoji: "⚽", title: "Football",
      howTo: "Entre le nombre de buts de chaque équipe après 90 minutes (sans prolongations ni tirs au but).",
      scoring: "Score exact = 3 pts · Bon résultat = 1 pt · Raté = 0 pt",
      rules: [
        { icon: "⏱️", text: "Match = 2 × 45 minutes = 90 minutes" },
        { icon: "🚫", text: "Les prolongations et tirs au but ne comptent pas" },
        { icon: "🎯", text: "Score exact (ex. 2:1) = 3 points" },
        { icon: "✅", text: "Bon résultat (victoire/nul), mauvais score = 1 point" },
        { icon: "❌", text: "Mauvais résultat = 0 point" },
      ],
      example: { label: "Tu entres: 2 : 1", score: "2 : 1", note: "Tu pronostiques une victoire à domicile 2:1" },
    },
    volleyball: {
      emoji: "🏐", title: "Volleyball",
      howTo: "Entre le nombre de sets gagnés par chaque équipe. Un match se joue en 3 sets gagnants — max. 5 sets.",
      scoring: "Score exact en sets = 3 pts · Bon gagnant = 1 pt · Raté = 0 pt",
      rules: [
        { icon: "🔢", text: "Match = premier à 3 sets (best of 5)" },
        { icon: "✅", text: "Résultats possibles: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "PAS de match nul — toujours un gagnant" },
        { icon: "🎯", text: "Score exact en sets = 3 points" },
        { icon: "✅", text: "Bon gagnant, mauvais score = 1 point" },
      ],
      example: { label: "Tu entres: 3 : 1", score: "3 : 1", note: "Tu pronostiques une victoire à domicile 3 sets à 1" },
    },
    handball: {
      emoji: "🤾", title: "Handball",
      howTo: "Entre le nombre de buts de chaque équipe en 60 minutes. Scores typiques: 25–40 buts par équipe. Pas besoin d'être exact — ±3 buts rapporte aussi des points!",
      scoring: "Score exact = 3 pts · Les deux ±3 buts = 2 pts · Bon gagnant = 1 pt · Raté = 0 pt",
      rules: [
        { icon: "⏱️", text: "Match = 2 × 30 minutes = 60 minutes" },
        { icon: "🥅", text: "Scores typiques: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Score exact = 3 pts (ex. pronostic 28:24 → résultat 28:24)" },
        { icon: "⭐", text: "Les deux ±3 buts = 2 pts (ex. pronostic 28:24 → résultat 30:26)" },
        { icon: "✅", text: "Bon gagnant mais trop loin = 1 pt" },
        { icon: "❌", text: "Mauvais gagnant = 0 pt" },
      ],
      example: { label: "Pronostic 28:24 → résultat 30:26", score: "30 : 26", note: "Écart: +2 et +2 buts → les deux ±3 → 2 pts ⭐\nPronostic 28:24 exact → 3 pts 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Formule 1",
      howTo: "Choisis le pilote qui va gagner le Grand Prix selon toi. Un choix par course.",
      scoring: "Bon gagnant = 3 pts · Mauvais = 0 pt",
      rules: [
        { icon: "📋", text: "Appuie sur une course → liste des pilotes" },
        { icon: "👆", text: "Appuie sur un pilote → surligné en or" },
        { icon: "🔒", text: "'Pronostique: [nom]' → sauvegardé, non modifiable" },
        { icon: "🏁", text: "Après la course, vérifie si ton pilote a gagné" },
        { icon: "🎯", text: "Bon gagnant = 3 points" },
      ],
      example: { label: "Exemple", score: "🥇 M. Verstappen", note: "Choisis avant le départ de la course" },
    },
  },
  es: {
    football: {
      emoji: "⚽", title: "Fútbol",
      howTo: "Introduce los goles de cada equipo tras 90 minutos (sin prórroga ni penaltis).",
      scoring: "Resultado exacto = 3 pts · Resultado correcto = 1 pt · Fallo = 0 pts",
      rules: [
        { icon: "⏱️", text: "Partido = 2 × 45 minutos = 90 minutos" },
        { icon: "🚫", text: "La prórroga y penaltis no cuentan" },
        { icon: "🎯", text: "Resultado exacto (ej. 2:1) = 3 puntos" },
        { icon: "✅", text: "Resultado correcto, marcador incorrecto = 1 punto" },
        { icon: "❌", text: "Resultado incorrecto = 0 puntos" },
      ],
      example: { label: "Introduces: 2 : 1", score: "2 : 1", note: "Predices victoria local por 2 a 1" },
    },
    volleyball: {
      emoji: "🏐", title: "Voleibol",
      howTo: "Introduce los sets ganados por cada equipo. Se juega al mejor de 5 sets — primero en ganar 3.",
      scoring: "Sets exactos = 3 pts · Ganador correcto = 1 pt · Fallo = 0 pts",
      rules: [
        { icon: "🔢", text: "Partido = primero en ganar 3 sets (mejor de 5)" },
        { icon: "✅", text: "Resultados posibles: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "SIN empates — siempre hay un ganador" },
        { icon: "🎯", text: "Sets exactos (ej. 3:1) = 3 puntos" },
        { icon: "✅", text: "Ganador correcto, sets incorrectos = 1 punto" },
      ],
      example: { label: "Introduces: 3 : 1", score: "3 : 1", note: "Predices victoria local 3 sets a 1" },
    },
    handball: {
      emoji: "🤾", title: "Balonmano",
      howTo: "Introduce los goles de cada equipo en 60 minutos. Marcadores típicos: 25–40 goles por equipo. ¡No hace falta ser exacto — ±3 goles también puntúa!",
      scoring: "Resultado exacto = 3 pts · Ambos ±3 goles = 2 pts · Ganador correcto = 1 pt · Fallo = 0 pts",
      rules: [
        { icon: "⏱️", text: "Partido = 2 × 30 minutos = 60 minutos" },
        { icon: "🥅", text: "Marcadores típicos: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Resultado exacto = 3 pts (ej. pronostico 28:24 → resultado 28:24)" },
        { icon: "⭐", text: "Ambos ±3 goles = 2 pts (ej. pronostico 28:24 → resultado 30:26)" },
        { icon: "✅", text: "Ganador correcto pero muy alejado = 1 pt" },
        { icon: "❌", text: "Ganador incorrecto = 0 pts" },
      ],
      example: { label: "Pronostico 28:24 → resultado 30:26", score: "30 : 26", note: "Diferencia: +2 y +2 goles → ambos ±3 → 2 pts ⭐\nPronostico 28:24 exacto → 3 pts 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Fórmula 1",
      howTo: "Elige el piloto que crees que ganará el Gran Premio. Una selección por carrera.",
      scoring: "Ganador correcto = 3 pts · Incorrecto = 0 pts",
      rules: [
        { icon: "📋", text: "Toca una carrera → aparece la lista de pilotos" },
        { icon: "👆", text: "Toca el nombre del piloto → resaltado en dorado" },
        { icon: "🔒", text: "'Pronostico: [nombre]' → guardado, no se puede cambiar" },
        { icon: "🏁", text: "Tras la carrera, comprueba si tu piloto ganó" },
        { icon: "🎯", text: "Ganador correcto = 3 puntos" },
      ],
      example: { label: "Ejemplo", score: "🥇 M. Verstappen", note: "Elige antes de que empiece la carrera" },
    },
  },
  it: {
    football: {
      emoji: "⚽", title: "Calcio",
      howTo: "Inserisci i gol di ogni squadra dopo 90 minuti (senza tempi supplementari o rigori).",
      scoring: "Risultato esatto = 3 pti · Esito corretto = 1 pt · Errore = 0 pti",
      rules: [
        { icon: "⏱️", text: "Partita = 2 × 45 minuti = 90 minuti" },
        { icon: "🚫", text: "Tempi supplementari e rigori non contano" },
        { icon: "🎯", text: "Risultato esatto (es. 2:1) = 3 punti" },
        { icon: "✅", text: "Esito corretto, risultato sbagliato = 1 punto" },
        { icon: "❌", text: "Esito sbagliato = 0 punti" },
      ],
      example: { label: "Inserisci: 2 : 1", score: "2 : 1", note: "Pronostichi vittoria casalinga 2:1" },
    },
    volleyball: {
      emoji: "🏐", title: "Pallavolo",
      howTo: "Inserisci quanti set vince ogni squadra. Si gioca al meglio di 5 set — primo a 3 set vince.",
      scoring: "Set esatti = 3 pti · Vincitore corretto = 1 pt · Errore = 0 pti",
      rules: [
        { icon: "🔢", text: "Partita = primo a 3 set (best of 5)" },
        { icon: "✅", text: "Risultati possibili: 3:0 · 3:1 · 3:2 · 2:3 · 1:3 · 0:3" },
        { icon: "🚫", text: "NESSUN pareggio — c'è sempre un vincitore" },
        { icon: "🎯", text: "Set esatti (es. 3:1) = 3 punti" },
        { icon: "✅", text: "Vincitore corretto, set sbagliati = 1 punto" },
      ],
      example: { label: "Inserisci: 3 : 1", score: "3 : 1", note: "Pronostichi vittoria casalinga 3 set a 1" },
    },
    handball: {
      emoji: "🤾", title: "Pallamano",
      howTo: "Inserisci i gol di ogni squadra in 60 minuti. Risultati tipici: 25–40 gol per squadra. Non serve essere esatti — ±3 gol vale comunque punti!",
      scoring: "Risultato esatto = 3 pti · Entrambi ±3 gol = 2 pti · Vincitore corretto = 1 pt · Errore = 0 pti",
      rules: [
        { icon: "⏱️", text: "Partita = 2 × 30 minuti = 60 minuti" },
        { icon: "🥅", text: "Risultati tipici: 28:24 · 31:27 · 35:30 · 38:32" },
        { icon: "🎯", text: "Risultato esatto = 3 pti (es. pronostico 28:24 → risultato 28:24)" },
        { icon: "⭐", text: "Entrambi ±3 gol = 2 pti (es. pronostico 28:24 → risultato 30:26)" },
        { icon: "✅", text: "Vincitore corretto ma troppo lontano = 1 pt" },
        { icon: "❌", text: "Vincitore sbagliato = 0 pti" },
      ],
      example: { label: "Pronostico 28:24 → risultato 30:26", score: "30 : 26", note: "Scarto: +2 e +2 gol → entrambi ±3 → 2 pti ⭐\nPronostico 28:24 esatto → 3 pti 🎯" },
    },
    f1: {
      emoji: "🏎️", title: "Formula 1",
      howTo: "Scegli il pilota che pensi vincerà il Gran Premio. Una scelta per gara.",
      scoring: "Vincitore corretto = 3 pti · Sbagliato = 0 pti",
      rules: [
        { icon: "📋", text: "Tocca una gara → appare la lista dei piloti" },
        { icon: "👆", text: "Tocca il nome del pilota → evidenziato in oro" },
        { icon: "🔒", text: "'Pronostico: [nome]' → salvato, non modificabile" },
        { icon: "🏁", text: "Dopo la gara, controlla se il tuo pilota ha vinto" },
        { icon: "🎯", text: "Vincitore corretto = 3 punti" },
      ],
      example: { label: "Esempio", score: "🥇 M. Verstappen", note: "Scegli prima dell'inizio della gara" },
    },
  },
};

interface Props { sport: string; onClose: () => void; }

export default function SportInfoModal({ sport, onClose }: Props) {
  const { locale } = useLang();
  const langData = DATA[locale] ?? DATA.pl;
  const info = langData[sport] ?? langData.football;

  return (
    <div onClick={onClose} className="fixed inset-0 z-[80] bg-black/75 backdrop-blur-sm flex items-end fade-in">
      <div onClick={e => e.stopPropagation()}
        className="w-full bg-[#181818] border-t border-white/10 rounded-t-3xl pb-safe slide-up max-h-[90vh] overflow-y-auto">
        <div className="flex justify-center pt-3 pb-1">
          <span className="w-10 h-1 rounded-full bg-white/20" />
        </div>

        <div className="px-5 pt-2 pb-8">
          {/* Nagłówek */}
          <div className="flex items-center justify-between mb-5">
            <div className="flex items-center gap-3">
              <span className="text-4xl leading-none">{info.emoji}</span>
              <div>
                <h2 className="text-white font-black text-xl">{info.title}</h2>
                <p className="text-white/40 text-xs mt-0.5">Jak typować?</p>
              </div>
            </div>
            <button onClick={onClose} className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center active:scale-90 transition">
              <X size={16} className="text-white/50" />
            </button>
          </div>

          {/* Opis */}
          <div className="bg-[#F5C400]/[0.10] border border-[#F5C400]/25 rounded-2xl px-4 py-3.5 mb-4">
            <p className="text-white text-sm leading-relaxed font-medium">{info.howTo}</p>
          </div>

          {/* Punktacja */}
          <div className="bg-white/[0.04] border border-white/[0.10] rounded-2xl px-4 py-3 mb-4">
            <p className="text-[#F5C400] text-xs font-black uppercase tracking-widest mb-1">Punktacja</p>
            <p className="text-white/70 text-sm">{info.scoring}</p>
          </div>

          {/* Zasady */}
          <div className="flex flex-col gap-2 mb-4">
            {info.rules.map((r, i) => (
              <div key={i} className="flex items-start gap-3 bg-[#1e1e1e] border border-white/[0.10] rounded-xl px-3 py-2.5">
                <span className="text-lg leading-none flex-shrink-0 mt-0.5">{r.icon}</span>
                <p className="text-white/80 text-sm leading-snug">{r.text}</p>
              </div>
            ))}
          </div>

          {/* Przykład */}
          <div className="bg-[#1e1e1e] border border-white/[0.10] rounded-2xl p-4">
            <p className="text-white/30 text-[10px] font-black uppercase tracking-widest mb-3">{info.example.label}</p>
            <p className="text-[#F5C400] font-black text-2xl text-center tabular-nums mb-2">{info.example.score}</p>
            <p className="text-white/50 text-xs text-center leading-snug">{info.example.note}</p>
          </div>
        </div>
      </div>
    </div>
  );
}

"use client";
import { X, ChevronDown } from "lucide-react";
import { useLang } from "@/contexts/LangContext";
import { Locale } from "@/lib/translations";

type RuleSection = {
  emoji: string;
  title: string;
  rounds: { label: string; desc: string }[];
  alt?: string;
};

type RulesContent = {
  heading: string;
  intro: string;
  byeExplain: string;
  sections: RuleSection[];
};

const RULES: Record<Locale, RulesContent> = {
  pl: {
    heading: "Jak działa drabinka?",
    intro: "Typerly automatycznie dobiera format turnieju do liczby drużyn. Poniżej znajdziesz dokładne zasady dla każdej liczby uczestników.",
    byeExplain: "Wolny los (BYE) — drużyna automatycznie awansuje do następnej rundy bez grania meczu.",
    sections: [
      {
        emoji: "🏆",
        title: "6 drużyn — Puchar z wolnymi losami",
        rounds: [
          { label: "Runda 1 (Wstępna)", desc: "4 drużyny grają 2 mecze eliminacyjne. 2 drużyny z wolnym losem czekają na półfinał." },
          { label: "Półfinały", desc: "Zwycięzcy rundy 1 grają z drużynami, które miały wolny los (2 mecze)." },
          { label: "Finał", desc: "Zwycięzcy półfinałów grają o puchar." },
        ],
        alt: "Chcesz, żeby każdy grał z każdym? Wybierz format ligowy — każda drużyna rozgrywa 5 meczów (15 łącznie).",
      },
      {
        emoji: "⭐",
        title: "5 drużyn — Puchar z wolnymi losami",
        rounds: [
          { label: "Runda 1 (Eliminacje)", desc: "2 drużyny grają 1 mecz. 3 drużyny z wolnym losem czekają na półfinał." },
          { label: "Półfinały", desc: "Zwycięzca eliminacji dołącza do trójki z wolnym losem — 2 mecze półfinałowe." },
          { label: "Finał", desc: "Zwycięzcy półfinałów walczą o tytuł." },
        ],
        alt: "Rekomendacja: przy 5 drużynach format ligowy (4 mecze na drużynę, 10 łącznie) daje każdemu więcej grania.",
      },
      {
        emoji: "👑",
        title: "4 drużyny — Format klasyczny",
        rounds: [
          { label: "Półfinały", desc: "Para 1 (A vs B) i Para 2 (C vs D) — 2 mecze." },
          { label: "Finał", desc: "Zwycięzcy półfinałów grają o 1. miejsce. Opcjonalnie: mecz o 3. miejsce." },
        ],
        alt: "Idealny format — symetryczny, bez wolnych losów, szybki i sprawiedliwy.",
      },
      {
        emoji: "🥉",
        title: "3 drużyny — Trójmecz (liga)",
        rounds: [
          { label: "Każdy z każdym", desc: "A vs B, B vs C, C vs A — 3 mecze. Wygrywa drużyna z największą liczbą punktów." },
          { label: "Opcjonalny Wielki Finał", desc: "Dwie czołowe drużyny mogą zagrać dodatkowy finał po fazie grupowej." },
        ],
        alt: "Format pucharowy przy 3 drużynach nie ma sensu — jedna musiałaby czekać od razu w finale.",
      },
      {
        emoji: "⚔️",
        title: "2 drużyny — Pojedynek",
        rounds: [
          { label: "Opcja 1: Jeden mecz", desc: "Kto wygrywa, bierze puchar." },
          { label: "Opcja 2: Best of 3", desc: "Grają do 2 zwycięstw (max 3 mecze)." },
          { label: "Opcja 3: Mecz i rewanż", desc: "2 mecze, decyduje bilans bramek — jak w pucharach UEFA." },
        ],
      },
    ],
  },
  en: {
    heading: "How does the bracket work?",
    intro: "Typerly automatically selects the tournament format based on the number of teams. Below you'll find the exact rules for each number of participants.",
    byeExplain: "BYE — a team automatically advances to the next round without playing a match.",
    sections: [
      {
        emoji: "🏆",
        title: "6 teams — Knockout with byes",
        rounds: [
          { label: "Round 1 (Preliminary)", desc: "4 teams play 2 elimination matches. 2 teams with a bye wait for the semi-finals." },
          { label: "Semi-finals", desc: "Round 1 winners play the teams that had byes (2 matches)." },
          { label: "Final", desc: "Semi-final winners compete for the trophy." },
        ],
        alt: "Want everyone to play each other? Choose the league format — each team plays 5 matches (15 total).",
      },
      {
        emoji: "⭐",
        title: "5 teams — Knockout with byes",
        rounds: [
          { label: "Round 1 (Elimination)", desc: "2 teams play 1 match. 3 teams with a bye wait for the semi-finals." },
          { label: "Semi-finals", desc: "The elimination winner joins the three bye teams — 2 semi-final matches." },
          { label: "Final", desc: "Semi-final winners battle for the title." },
        ],
        alt: "Recommendation: with 5 teams, the league format (4 matches per team, 10 total) gives everyone more playing time.",
      },
      {
        emoji: "👑",
        title: "4 teams — Classic knockout",
        rounds: [
          { label: "Semi-finals", desc: "Pair 1 (A vs B) and Pair 2 (C vs D) — 2 matches." },
          { label: "Final", desc: "Semi-final winners play for 1st place. Optional: 3rd place match." },
        ],
        alt: "The ideal format — symmetric, no byes, fast and fair.",
      },
      {
        emoji: "🥉",
        title: "3 teams — Round robin",
        rounds: [
          { label: "Round robin", desc: "A vs B, B vs C, C vs A — 3 matches. The team with the most points wins." },
          { label: "Optional Grand Final", desc: "The top two teams can play an extra final after the group stage." },
        ],
        alt: "A knockout format with 3 teams doesn't make sense — one team would have to wait in the final right away.",
      },
      {
        emoji: "⚔️",
        title: "2 teams — Head-to-head",
        rounds: [
          { label: "Option 1: Single match", desc: "Winner takes the trophy." },
          { label: "Option 2: Best of 3", desc: "Play until one team wins 2 matches (max 3 matches)." },
          { label: "Option 3: Home & away", desc: "2 matches, aggregate score decides — like in UEFA cups." },
        ],
      },
    ],
  },
  de: {
    heading: "Wie funktioniert die Turnierbracket?",
    intro: "Typerly wählt automatisch das Turnierformat basierend auf der Teamanzahl. Nachfolgend findest du die genauen Regeln für jede Teilnehmerzahl.",
    byeExplain: "Freilos (BYE) — ein Team rückt automatisch in die nächste Runde vor, ohne ein Spiel zu spielen.",
    sections: [
      {
        emoji: "🏆",
        title: "6 Teams — K.o.-System mit Freilosen",
        rounds: [
          { label: "Runde 1 (Vorrunde)", desc: "4 Teams spielen 2 Ausscheidungsspiele. 2 Teams mit Freilos warten auf das Halbfinale." },
          { label: "Halbfinale", desc: "Sieger der Runde 1 spielen gegen die Teams mit Freilos (2 Spiele)." },
          { label: "Finale", desc: "Die Halbfinalsieger spielen um den Pokal." },
        ],
        alt: "Soll jeder gegen jeden spielen? Wähle das Ligaformat — jedes Team spielt 5 Spiele (15 insgesamt).",
      },
      {
        emoji: "⭐",
        title: "5 Teams — K.o.-System mit Freilosen",
        rounds: [
          { label: "Runde 1 (Qualifikation)", desc: "2 Teams spielen 1 Spiel. 3 Teams mit Freilos warten auf das Halbfinale." },
          { label: "Halbfinale", desc: "Der Qualifikationssieger schließt sich den drei Freilos-Teams an — 2 Halbfinalspiele." },
          { label: "Finale", desc: "Die Halbfinalsieger kämpfen um den Titel." },
        ],
        alt: "Empfehlung: Bei 5 Teams gibt das Ligaformat (4 Spiele pro Team, 10 insgesamt) jedem mehr Spielzeit.",
      },
      {
        emoji: "👑",
        title: "4 Teams — Klassisches K.o.",
        rounds: [
          { label: "Halbfinale", desc: "Paar 1 (A vs B) und Paar 2 (C vs D) — 2 Spiele." },
          { label: "Finale", desc: "Halbfinalsieger spielen um Platz 1. Optional: Spiel um Platz 3." },
        ],
        alt: "Das ideale Format — symmetrisch, ohne Freilose, schnell und fair.",
      },
      {
        emoji: "🥉",
        title: "3 Teams — Jeder gegen jeden",
        rounds: [
          { label: "Jeder gegen jeden", desc: "A vs B, B vs C, C vs A — 3 Spiele. Das Team mit den meisten Punkten gewinnt." },
          { label: "Optionales Großfinale", desc: "Die beiden besten Teams können nach der Gruppenphase ein Extra-Finale spielen." },
        ],
        alt: "Ein K.o.-Format mit 3 Teams macht keinen Sinn — ein Team müsste sofort im Finale warten.",
      },
      {
        emoji: "⚔️",
        title: "2 Teams — Duell",
        rounds: [
          { label: "Option 1: Einzelspiel", desc: "Der Sieger gewinnt den Pokal." },
          { label: "Option 2: Best of 3", desc: "Spielen bis ein Team 2 Siege hat (max. 3 Spiele)." },
          { label: "Option 3: Hin- und Rückspiel", desc: "2 Spiele, Gesamttore entscheiden — wie im UEFA-Pokal." },
        ],
      },
    ],
  },
  fr: {
    heading: "Comment fonctionne le tableau ?",
    intro: "Typerly sélectionne automatiquement le format du tournoi en fonction du nombre d'équipes. Vous trouverez ci-dessous les règles exactes pour chaque nombre de participants.",
    byeExplain: "Exempt (BYE) — une équipe passe automatiquement au tour suivant sans jouer de match.",
    sections: [
      {
        emoji: "🏆",
        title: "6 équipes — Élimination directe avec exempts",
        rounds: [
          { label: "Tour 1 (Préliminaire)", desc: "4 équipes jouent 2 matchs d'élimination. 2 équipes avec exempt attendent les demi-finales." },
          { label: "Demi-finales", desc: "Les vainqueurs du tour 1 affrontent les équipes exemptées (2 matchs)." },
          { label: "Finale", desc: "Les vainqueurs des demi-finales s'affrontent pour le trophée." },
        ],
        alt: "Vous voulez que tout le monde joue contre tout le monde ? Choisissez le format ligue — chaque équipe joue 5 matchs (15 au total).",
      },
      {
        emoji: "⭐",
        title: "5 équipes — Élimination directe avec exempts",
        rounds: [
          { label: "Tour 1 (Qualification)", desc: "2 équipes jouent 1 match. 3 équipes avec exempt attendent les demi-finales." },
          { label: "Demi-finales", desc: "Le vainqueur de la qualification rejoint les trois équipes exemptées — 2 demi-finales." },
          { label: "Finale", desc: "Les vainqueurs des demi-finales se battent pour le titre." },
        ],
        alt: "Recommandation : avec 5 équipes, le format ligue (4 matchs par équipe, 10 au total) offre plus de jeu à tous.",
      },
      {
        emoji: "👑",
        title: "4 équipes — Classique",
        rounds: [
          { label: "Demi-finales", desc: "Paire 1 (A vs B) et Paire 2 (C vs D) — 2 matchs." },
          { label: "Finale", desc: "Les vainqueurs des demi-finales jouent pour la 1re place. En option : match pour la 3e place." },
        ],
        alt: "Le format idéal — symétrique, sans exempts, rapide et équitable.",
      },
      {
        emoji: "🥉",
        title: "3 équipes — Poule",
        rounds: [
          { label: "Tous contre tous", desc: "A vs B, B vs C, C vs A — 3 matchs. L'équipe avec le plus de points gagne." },
          { label: "Grande Finale optionnelle", desc: "Les deux meilleures équipes peuvent jouer une finale supplémentaire après la phase de groupes." },
        ],
        alt: "Un format à élimination directe avec 3 équipes n'a pas de sens — une équipe devrait attendre directement en finale.",
      },
      {
        emoji: "⚔️",
        title: "2 équipes — Face à face",
        rounds: [
          { label: "Option 1 : Match unique", desc: "Le vainqueur remporte le trophée." },
          { label: "Option 2 : Meilleur des 3", desc: "On joue jusqu'à ce qu'une équipe ait 2 victoires (max 3 matchs)." },
          { label: "Option 3 : Aller-retour", desc: "2 matchs, le score cumulé décide — comme en Coupe UEFA." },
        ],
      },
    ],
  },
  es: {
    heading: "¿Cómo funciona el cuadro?",
    intro: "Typerly selecciona automáticamente el formato del torneo según el número de equipos. A continuación encontrarás las reglas exactas para cada número de participantes.",
    byeExplain: "Bye — un equipo avanza automáticamente a la siguiente ronda sin jugar un partido.",
    sections: [
      {
        emoji: "🏆",
        title: "6 equipos — Eliminatoria con byes",
        rounds: [
          { label: "Ronda 1 (Preliminar)", desc: "4 equipos juegan 2 partidos de eliminación. 2 equipos con bye esperan las semifinales." },
          { label: "Semifinales", desc: "Los ganadores de la ronda 1 juegan contra los equipos con bye (2 partidos)." },
          { label: "Final", desc: "Los ganadores de las semifinales compiten por el trofeo." },
        ],
        alt: "¿Quieres que todos jueguen contra todos? Elige el formato de liga — cada equipo juega 5 partidos (15 en total).",
      },
      {
        emoji: "⭐",
        title: "5 equipos — Eliminatoria con byes",
        rounds: [
          { label: "Ronda 1 (Clasificación)", desc: "2 equipos juegan 1 partido. 3 equipos con bye esperan las semifinales." },
          { label: "Semifinales", desc: "El ganador de la clasificación se une a los tres equipos con bye — 2 semifinales." },
          { label: "Final", desc: "Los ganadores de las semifinales luchan por el título." },
        ],
        alt: "Recomendación: con 5 equipos, el formato de liga (4 partidos por equipo, 10 en total) da más juego a todos.",
      },
      {
        emoji: "👑",
        title: "4 equipos — Formato clásico",
        rounds: [
          { label: "Semifinales", desc: "Par 1 (A vs B) y Par 2 (C vs D) — 2 partidos." },
          { label: "Final", desc: "Los ganadores de las semifinales juegan por el 1.er lugar. Opcional: partido por el 3.er lugar." },
        ],
        alt: "El formato ideal — simétrico, sin byes, rápido y justo.",
      },
      {
        emoji: "🥉",
        title: "3 equipos — Todos contra todos",
        rounds: [
          { label: "Todos contra todos", desc: "A vs B, B vs C, C vs A — 3 partidos. El equipo con más puntos gana." },
          { label: "Gran Final opcional", desc: "Los dos mejores equipos pueden jugar una final extra tras la fase de grupos." },
        ],
        alt: "Un formato eliminatorio con 3 equipos no tiene sentido — un equipo tendría que esperar directamente en la final.",
      },
      {
        emoji: "⚔️",
        title: "2 equipos — Duelo",
        rounds: [
          { label: "Opción 1: Partido único", desc: "El ganador se lleva el trofeo." },
          { label: "Opción 2: Al mejor de 3", desc: "Se juega hasta que un equipo gane 2 veces (máx. 3 partidos)." },
          { label: "Opción 3: Ida y vuelta", desc: "2 partidos, el marcador global decide — como en las copas de la UEFA." },
        ],
      },
    ],
  },
  it: {
    heading: "Come funziona il tabellone?",
    intro: "Typerly seleziona automaticamente il formato del torneo in base al numero di squadre. Di seguito troverai le regole esatte per ogni numero di partecipanti.",
    byeExplain: "Bye — una squadra avanza automaticamente al turno successivo senza giocare una partita.",
    sections: [
      {
        emoji: "🏆",
        title: "6 squadre — Eliminazione diretta con bye",
        rounds: [
          { label: "Turno 1 (Preliminare)", desc: "4 squadre giocano 2 partite di eliminazione. 2 squadre con bye attendono le semifinali." },
          { label: "Semifinali", desc: "I vincitori del turno 1 sfidano le squadre con bye (2 partite)." },
          { label: "Finale", desc: "I vincitori delle semifinali si contendono il trofeo." },
        ],
        alt: "Vuoi che tutti giochino contro tutti? Scegli il formato lega — ogni squadra gioca 5 partite (15 in totale).",
      },
      {
        emoji: "⭐",
        title: "5 squadre — Eliminazione diretta con bye",
        rounds: [
          { label: "Turno 1 (Qualificazione)", desc: "2 squadre giocano 1 partita. 3 squadre con bye attendono le semifinali." },
          { label: "Semifinali", desc: "Il vincitore della qualificazione si unisce alle tre squadre con bye — 2 semifinali." },
          { label: "Finale", desc: "I vincitori delle semifinali lottano per il titolo." },
        ],
        alt: "Raccomandazione: con 5 squadre, il formato lega (4 partite per squadra, 10 in totale) dà a tutti più gioco.",
      },
      {
        emoji: "👑",
        title: "4 squadre — Formato classico",
        rounds: [
          { label: "Semifinali", desc: "Coppia 1 (A vs B) e Coppia 2 (C vs D) — 2 partite." },
          { label: "Finale", desc: "I vincitori delle semifinali giocano per il 1° posto. Opzionale: partita per il 3° posto." },
        ],
        alt: "Il formato ideale — simmetrico, senza bye, veloce e giusto.",
      },
      {
        emoji: "🥉",
        title: "3 squadre — Tutti contro tutti",
        rounds: [
          { label: "Tutti contro tutti", desc: "A vs B, B vs C, C vs A — 3 partite. La squadra con più punti vince." },
          { label: "Grande Finale opzionale", desc: "Le due migliori squadre possono giocare una finale extra dopo la fase a gironi." },
        ],
        alt: "Un formato a eliminazione diretta con 3 squadre non ha senso — una squadra dovrebbe aspettare direttamente in finale.",
      },
      {
        emoji: "⚔️",
        title: "2 squadre — Duello",
        rounds: [
          { label: "Opzione 1: Partita singola", desc: "Il vincitore porta via il trofeo." },
          { label: "Opzione 2: Al meglio dei 3", desc: "Si gioca finché una squadra vince 2 volte (max 3 partite)." },
          { label: "Opzione 3: Andata e ritorno", desc: "2 partite, il punteggio aggregato decide — come nelle coppe UEFA." },
        ],
      },
    ],
  },
};

type Props = {
  open: boolean;
  onClose: () => void;
};

export default function TournamentRulesModal({ open, onClose }: Props) {
  const { t, locale } = useLang();

  if (!open) return null;

  const content = RULES[locale] ?? RULES.en;

  return (
    <div
      className="fixed inset-0 z-[200] flex flex-col"
      style={{ background: "rgba(0,0,0,0.95)", backdropFilter: "blur(8px)" }}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-5 pt-safe pt-5 pb-4 border-b border-white/[0.08] flex-shrink-0">
        <h2 className="text-white font-black text-lg font-archivo">{t("rules.title")}</h2>
        <button
          onClick={onClose}
          className="w-9 h-9 rounded-full bg-white/10 flex items-center justify-center text-white/60 active:scale-90 transition"
        >
          <X size={18} />
        </button>
      </div>

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto px-5 py-5 pb-safe">
        {/* Heading + intro */}
        <h3 className="text-[#F5C400] font-black text-xl mb-2">{content.heading}</h3>
        <p className="text-white/60 text-sm leading-relaxed mb-4">{content.intro}</p>

        {/* BYE explanation */}
        <div className="rounded-xl px-4 py-3 mb-6 bg-[#F5C400]/10 border border-[#F5C400]/20">
          <p className="text-[#F5C400] text-xs font-bold">{content.byeExplain}</p>
        </div>

        {/* Sections */}
        <div className="flex flex-col gap-5">
          {content.sections.map((section) => (
            <div
              key={section.title}
              className="rounded-2xl border border-white/[0.08] bg-white/[0.03] overflow-hidden"
            >
              {/* Section header */}
              <div className="px-4 py-3 border-b border-white/[0.06] flex items-center gap-2">
                <span className="text-xl">{section.emoji}</span>
                <span className="text-white font-black text-sm">{section.title}</span>
              </div>

              {/* Rounds */}
              <div className="px-4 py-3 flex flex-col gap-3">
                {section.rounds.map((round, i) => (
                  <div key={i} className="flex gap-3">
                    <div className="w-5 h-5 rounded-full bg-[#F5C400]/20 border border-[#F5C400]/40 flex items-center justify-center flex-shrink-0 mt-0.5">
                      <span className="text-[#F5C400] text-[9px] font-black">{i + 1}</span>
                    </div>
                    <div>
                      <p className="text-white text-xs font-bold mb-0.5">{round.label}</p>
                      <p className="text-white/50 text-xs leading-relaxed">{round.desc}</p>
                    </div>
                  </div>
                ))}
              </div>

              {/* Alternative tip */}
              {section.alt && (
                <div className="px-4 pb-3">
                  <div className="rounded-lg px-3 py-2 bg-white/[0.04] border border-white/[0.06]">
                    <p className="text-white/40 text-[11px] leading-relaxed">💡 {section.alt}</p>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Scroll hint + close button */}
        <div className="mt-6 flex flex-col items-center gap-3">
          <div className="flex items-center gap-1.5 text-white/20">
            <ChevronDown size={14} />
            <span className="text-[11px]">{t("rules.scroll_hint")}</span>
          </div>
          <button
            onClick={onClose}
            className="w-full bg-[#F5C400] text-black font-black py-4 rounded-2xl active:scale-95 transition text-base"
          >
            {t("rules.close")}
          </button>
        </div>
      </div>
    </div>
  );
}

"use client";
import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";

export default function TermsPage() {
  const router = useRouter();
  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => router.back()}
          className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-xl font-archivo">Regulamin</h1>
      </div>

      <div className="flex flex-col gap-6 text-white/70 text-sm leading-relaxed">

        <section>
          <p className="text-white/30 text-xs mb-4">Ostatnia aktualizacja: czerwiec 2025 · Wersja Beta</p>

          {/* Kluczowa informacja — nie jest grą hazardową */}
          <div className="bg-[#F5C400]/[0.08] border border-[#F5C400]/25 rounded-2xl p-4 mb-2">
            <p className="text-[#F5C400] font-black text-sm mb-1">⚠️ Ważna informacja</p>
            <p className="text-white/70 text-sm">
              Typerly jest <strong className="text-white">grą towarzyską</strong> opartą na wiedzy i analizie sportowej.
              Aplikacja <strong className="text-white">nie jest grą hazardową</strong> — nie pobiera wpisowego
              w prawdziwych pieniądzach, nie wypłaca wygranych w pieniądzach ani żadnych aktywach finansowych.
              Nagrody mają wyłącznie charakter wirtualny (punkty, odznaki, rankingi).
              Aplikacja <strong className="text-white">nie podlega przepisom o grach hazardowych</strong>.
            </p>
          </div>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">1. Definicje</h2>
          <ul className="flex flex-col gap-1 text-white/60 text-sm">
            <li><strong className="text-white/80">Typerly</strong> — aplikacja webowa i mobilna dostępna pod adresem typerly.andrzejmich.ch</li>
            <li><strong className="text-white/80">Użytkownik</strong> — osoba korzystająca z aplikacji po rejestracji konta</li>
            <li><strong className="text-white/80">Typ</strong> — prognoza wyniku meczu lub wyścigu dokonana przez Użytkownika</li>
            <li><strong className="text-white/80">Punkty</strong> — wirtualna waluta naliczana za trafione typy, bez wartości pieniężnej</li>
            <li><strong className="text-white/80">Administrator</strong> — Andrzej Mich, Unterwiesstrasse 41, 8630 Rüti ZH, Szwajcaria</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">2. Zasady korzystania</h2>
          <ul className="flex flex-col gap-1 text-white/60 text-sm">
            <li>• Konto mogą zakładać osoby, które ukończyły 13 lat</li>
            <li>• Każdy użytkownik może posiadać tylko jedno konto</li>
            <li>• Zabronione jest używanie botów, skryptów i automatyzacji</li>
            <li>• Zabronione jest podawanie fałszywych danych przy rejestracji</li>
            <li>• Zabronione jest obraźliwe lub wulgarne zachowanie w czacie</li>
            <li>• Zabronione jest celowe manipulowanie rankingami</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">3. Typowanie — zasady</h2>
          <ul className="flex flex-col gap-1 text-white/60 text-sm">
            <li>• Typ można złożyć wyłącznie przed rozpoczęciem meczu lub wyścigu</li>
            <li>• Typy są ostateczne — nie można ich anulować ani zmienić (z wyjątkiem F1)</li>
            <li>• Punkty naliczane są automatycznie po zakończeniu wydarzenia</li>
            <li>• Administrator zastrzega prawo do korekty wyników w przypadku błędów technicznych</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">4. Brak elementów hazardowych</h2>
          <p>
            Typerly jest wyłącznie grą towarzyską i prognozującą. Potwierdzamy, że:
          </p>
          <ul className="flex flex-col gap-1 mt-2 text-white/60 text-sm">
            <li>✅ Nie pobieramy opłat za składanie typów</li>
            <li>✅ Nie wypłacamy nagród pieniężnych ani rzeczowych o wartości finansowej</li>
            <li>✅ Punkty zdobyte w aplikacji nie mają wartości pieniężnej i nie podlegają wymianie</li>
            <li>✅ Aplikacja nie zawiera elementów losowych — wyniki zależą wyłącznie od wiedzy użytkownika</li>
            <li>✅ Aplikacja nie spełnia definicji gry hazardowej w rozumieniu polskiej ustawy o grach hazardowych (Dz.U. 2009 nr 201 poz. 1540) ani prawa szwajcarskiego (Geldspielgesetz)</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">5. Konta Premium</h2>
          <p>
            Konta Premium (ukrywające reklamy) będą dostępne w przyszłości za opłatą.
            Szczegóły cennika zostaną podane przed uruchomieniem płatności.
            Obecne konto <strong className="text-white">Beta</strong> jest bezpłatne.
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">6. Wersja Beta</h2>
          <div className="bg-white/[0.04] border border-white/[0.08] rounded-2xl p-4 text-sm text-white/60">
            <p>Aplikacja jest w fazie <strong className="text-white">Beta</strong>. Oznacza to:</p>
            <ul className="mt-2 flex flex-col gap-1">
              <li>• Funkcje mogą się zmieniać bez wcześniejszego powiadomienia</li>
              <li>• Dane (typy, punkty, historia) mogą zostać zresetowane</li>
              <li>• Dostęp do aplikacji może zostać tymczasowo wstrzymany</li>
              <li>• Aplikacja może zawierać błędy — prosimy o ich zgłaszanie</li>
            </ul>
          </div>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">7. Odpowiedzialność</h2>
          <p>
            Administrator dokłada wszelkich starań, aby aplikacja działała poprawnie,
            jednak nie ponosi odpowiedzialności za przerwy w dostępie, utratę danych
            ani błędy wynikające z czynników zewnętrznych (dostawcy API, serwery).
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">8. Prawo właściwe</h2>
          <p>
            Niniejszy regulamin podlega prawu szwajcarskiemu. W sprawach nieuregulowanych
            stosuje się przepisy szwajcarskiego Kodeksu Zobowiązań (OR).
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">9. Kontakt</h2>
          <p>
            Pytania i zgłoszenia kieruj na:{" "}
            <a href="mailto:info@andrzejmich.ch" className="text-[#F5C400] font-semibold">
              info@andrzejmich.ch
            </a>
          </p>
        </section>

        <div className="border-t border-white/[0.06] pt-4 pb-8 text-center">
          <p className="text-white/20 text-xs">© 2025 Typerly · Andrzej Mich · Rüti ZH, Szwajcaria</p>
          <p className="text-white/20 text-xs mt-1">
            <a href="mailto:info@andrzejmich.ch" className="text-white/30">info@andrzejmich.ch</a>
          </p>
        </div>
      </div>
    </div>
  );
}

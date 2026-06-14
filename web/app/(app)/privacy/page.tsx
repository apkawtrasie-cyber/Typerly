"use client";
import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";

export default function PrivacyPage() {
  const router = useRouter();
  return (
    <div className="px-4 pt-6 pb-nav fade-in">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => router.back()}
          className="w-9 h-9 rounded-full bg-white/[0.08] flex items-center justify-center active:scale-90 transition flex-shrink-0">
          <ArrowLeft size={16} className="text-white/60" />
        </button>
        <h1 className="text-white font-black text-xl font-archivo">Polityka Prywatności</h1>
      </div>

      <div className="flex flex-col gap-6 text-white/70 text-sm leading-relaxed">

        <section>
          <p className="text-white/30 text-xs mb-4">Ostatnia aktualizacja: czerwiec 2025 · Wersja Beta</p>
          <p>
            Niniejsza Polityka Prywatności opisuje, jakie dane osobowe są zbierane przez aplikację
            <strong className="text-white"> Typerly</strong> oraz w jaki sposób są wykorzystywane i chronione.
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">1. Administrator danych</h2>
          <p>Administratorem danych osobowych jest:</p>
          <div className="bg-white/[0.04] border border-white/[0.08] rounded-2xl p-4 mt-2 text-white/60 text-sm">
            <p className="font-semibold text-white">Andrzej Mich</p>
            <p>Unterwiesstrasse 41</p>
            <p>8630 Rüti ZH, Szwajcaria</p>
            <p className="mt-1">📧 <a href="mailto:info@andrzejmich.ch" className="text-[#F5C400]">info@andrzejmich.ch</a></p>
            <p>📞 +41 78 206 73 79</p>
          </div>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">2. Jakie dane zbieramy</h2>
          <ul className="list-none flex flex-col gap-2">
            {[
              ["📧", "Adres e-mail", "używany do logowania i kontaktu"],
              ["👤", "Nazwa użytkownika (nick)", "wyświetlana w rankingach i czatach"],
              ["🏆", "Historia typów i wyniki", "niezbędne do naliczania punktów i rankingów"],
              ["🌐", "Adres IP i dane urządzenia", "zbierane automatycznie przez serwer (Supabase)"],
              ["🍪", "Pliki cookie i dane analityczne", "przez Google AdSense (tylko użytkownicy bez Premium)"],
            ].map(([icon, title, desc]) => (
              <li key={title} className="flex items-start gap-3 bg-white/[0.03] rounded-xl p-3">
                <span className="text-base">{icon}</span>
                <div>
                  <p className="text-white font-semibold text-sm">{title}</p>
                  <p className="text-white/40 text-xs">{desc}</p>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">3. W jakim celu przetwarzamy dane</h2>
          <ul className="flex flex-col gap-1.5 text-white/60 text-sm">
            <li>• Świadczenie usług aplikacji (konto, rankingi, typy)</li>
            <li>• Umożliwienie logowania przez Google</li>
            <li>• Wyświetlanie spersonalizowanych reklam (Google AdSense) — tylko bez Premium</li>
            <li>• Wykrywanie nadużyć i zapewnienie bezpieczeństwa</li>
            <li>• Komunikacja z użytkownikiem w sprawach konta</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">4. Gdzie przechowywane są dane</h2>
          <p>
            Dane przechowywane są na serwerach <strong className="text-white">Supabase</strong> (infrastruktura AWS).
            Możliwa lokalizacja: Europa (eu-central-1) lub USA. Dane są szyfrowane w tranzycie (HTTPS) i w spoczynku.
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">5. Udostępnianie danych</h2>
          <p>Dane nie są sprzedawane osobom trzecim. Mogą być udostępniane wyłącznie:</p>
          <ul className="flex flex-col gap-1 mt-2 text-white/60 text-sm">
            <li>• <strong className="text-white/80">Supabase</strong> — dostawca infrastruktury bazy danych</li>
            <li>• <strong className="text-white/80">Google</strong> — logowanie OAuth i reklamy AdSense</li>
            <li>• <strong className="text-white/80">Vercel</strong> — hosting frontendu aplikacji</li>
            <li>• <strong className="text-white/80">Organy władzy</strong> — jeśli wymagają tego przepisy prawa</li>
          </ul>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">6. Twoje prawa (RODO)</h2>
          <ul className="flex flex-col gap-1 text-white/60 text-sm">
            <li>• Prawo dostępu do swoich danych</li>
            <li>• Prawo do sprostowania danych</li>
            <li>• Prawo do usunięcia konta i danych</li>
            <li>• Prawo do przenoszenia danych</li>
            <li>• Prawo do sprzeciwu wobec przetwarzania</li>
          </ul>
          <p className="mt-3">
            Aby skorzystać z tych praw, napisz na:{" "}
            <a href="mailto:info@andrzejmich.ch" className="text-[#F5C400] font-semibold">info@andrzejmich.ch</a>
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">7. Pliki cookie i reklamy</h2>
          <p>
            Google AdSense może używać plików cookie do wyświetlania spersonalizowanych reklam.
            Użytkownicy z kontem <strong className="text-white">Premium</strong> są zwolnieni z reklam.
            Więcej informacji:{" "}
            <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer"
              className="text-[#F5C400]">policies.google.com/privacy</a>
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">8. Wersja Beta</h2>
          <p>
            Aplikacja Typerly jest aktualnie w fazie <strong className="text-white">Beta</strong>.
            Oznacza to, że może zawierać błędy, a dane mogą zostać zresetowane lub usunięte
            bez wcześniejszego powiadomienia.
          </p>
        </section>

        <section>
          <h2 className="text-white font-black text-base mb-2">9. Zmiany polityki</h2>
          <p>
            Zastrzegamy prawo do zmiany niniejszej polityki. O istotnych zmianach poinformujemy
            w aplikacji. Dalsze korzystanie z aplikacji po zmianach oznacza ich akceptację.
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

import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          // WAŻNE: przekazujemy opcje Supabase BEZ zmian.
          // NIE wolno ustawiać httpOnly — klient przeglądarki (createBrowserClient)
          // czyta sesję z cookies przez JavaScript. httpOnly = klient ślepy = wylogowanie.
          cookiesToSet.forEach(({ name, value, options }) => {
            request.cookies.set(name, value);
            response.cookies.set(name, value, options);
          });
        },
      },
    },
  );

  // Odświeża sesję — to jest kluczowa linia.
  // Bez tego serwer nie wie że użytkownik jest zalogowany.
  await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|icons|og-image|manifest).*)",
  ],
};

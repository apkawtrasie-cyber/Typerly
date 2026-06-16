import { NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Obsługuje redirect OAuth od Supabase (Google itp.)
// Supabase wysyła ?code= po udanym logowaniu — wymieniamy go na sesję
// i ZAPISUJEMY ją do cookies, żeby serwer i middleware rozpoznawały usera.
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/home";

  if (code) {
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll: () => cookieStore.getAll(),
          setAll: (cookiesToSet) => {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, {
                ...options,
                maxAge: 60 * 60 * 24 * 400, // 400 dni — sesja nie wygasa po zamknięciu
                sameSite: "lax",
                httpOnly: true,
                secure: process.env.NODE_ENV === "production",
              });
            });
          },
        },
      },
    );
    await supabase.auth.exchangeCodeForSession(code);
  }

  return NextResponse.redirect(new URL(next, url.origin));
}

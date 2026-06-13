"use client";
import { useEffect } from "react";
import { ensureProfile } from "@/lib/supabase";

// Gwarantuje istnienie profilu zalogowanego użytkownika przy każdym wejściu do aplikacji
export default function ProfileGuard() {
  useEffect(() => { ensureProfile(); }, []);
  return null;
}

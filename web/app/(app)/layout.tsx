import BottomNav from "@/components/BottomNav";
import ProfileGuard from "@/components/ProfileGuard";
import TyperlyFab from "@/components/TyperlyFab";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col min-h-[100dvh] pb-nav">
      <ProfileGuard />
      <main className="flex-1">{children}</main>
      <TyperlyFab />
      <BottomNav />
    </div>
  );
}

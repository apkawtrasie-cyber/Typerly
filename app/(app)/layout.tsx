import BottomNav from "@/components/BottomNav";
import ProfileGuard from "@/components/ProfileGuard";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex flex-col min-h-screen pb-20">
      <ProfileGuard />
      <main className="flex-1">{children}</main>
      <BottomNav />
    </div>
  );
}

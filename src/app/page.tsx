import Landing from "@/components/Landing";
import { getIgPosts } from "@/lib/ig";
import { getMenu } from "@/lib/menu";

// ISR: regenera la página (menú + feed de IG) cada 5 min sin necesidad de deploy.
export const revalidate = 300;

export default async function Home() {
  const [igPosts, menu] = await Promise.all([getIgPosts(), getMenu()]);
  return <Landing igPosts={igPosts ?? undefined} menu={menu ?? undefined} />;
}

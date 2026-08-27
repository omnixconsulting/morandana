import Landing from "@/components/Landing";
import { getIgPosts } from "@/lib/ig";

// ISR: regenera la página (y el feed de IG) cada 5 min sin necesidad de deploy.
export const revalidate = 300;

export default async function Home() {
  const igPosts = await getIgPosts();
  return <Landing igPosts={igPosts ?? undefined} />;
}

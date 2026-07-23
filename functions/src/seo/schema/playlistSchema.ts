import { DOMAIN } from "./schemaConfig";

export interface PlaylistData {
  id: string;
  name?: string;
  playlistName?: string;
  description?: string;
  videoIds?: string[];
  videos?: Array<{ id: string; title: string }>;
}

export function generatePlaylistSchema(playlist: PlaylistData, playlistUrl: string) {
  const playlistName = playlist.playlistName || playlist.name || "Playlist";
  const descStr = playlist.description || `Watch this playlist on Truthworld.`;

  const videoList = playlist.videos || (playlist.videoIds || []).map(id => ({ id, title: `Video ${id}` }));

  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: playlistName,
    description: descStr,
    url: playlistUrl,
    numberOfItems: videoList.length,
    itemListElement: videoList.slice(0, 25).map((v, idx) => ({
      "@type": "ListItem",
      position: idx + 1,
      name: v.title,
      url: `${DOMAIN}/watch?v=${v.id}`
    }))
  };
}

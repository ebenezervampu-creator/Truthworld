export interface Comment {
  id: string;
  videoId: string;
  userId: string;
  userName: string;
  userAvatar?: string;
  userTrustIndex: number; // Snapshot of trust index at time of comment
  text: string;
  likes: number;
  dislikes: number;
  authorRankScore: number; // Multiplier: userTrustIndex * engagement
  createdAt: number;
  parentId?: string;      // For replies
  isPinned?: boolean;
}

export interface ThreadSettings {
  videoId: string;
  isLocked: boolean;
  minTrustToComment: number; // e.g. 5.0 for high-stakes topics
  sortOrder: "trust_weighted" | "recency" | "engagement";
}

export interface Comment {
  id: string;
  videoId: string;
  userId: string;
  userName: string;
  userAvatar?: string;
  text: string;
  likes: number;
  dislikes: number;
  createdAt: number;
  parentId?: string;      // For replies
  isPinned?: boolean;
}

export interface ThreadSettings {
  videoId: string;
  isLocked: boolean;
  sortOrder: "recency" | "engagement";
}

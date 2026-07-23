import { NotificationPriority } from "../types";

export class RankingEngine {
  /**
   * Computes a deterministic rankingScore for sorting notifications in Creator Intelligence UI
   */
  static calculateScore(priority: NotificationPriority, createdAt: number, isRead: boolean = false): number {
    let priorityWeight = 100;
    switch (priority) {
      case "critical":
        priorityWeight = 10000;
        break;
      case "high":
        priorityWeight = 5000;
        break;
      case "medium":
        priorityWeight = 1000;
        break;
      case "low":
      default:
        priorityWeight = 100;
        break;
    }

    const recencyHours = (Date.now() - createdAt) / (1000 * 3600);
    const recencyPenalty = Math.min(recencyHours * 10, 500);
    const readPenalty = isRead ? 2000 : 0;

    return priorityWeight - recencyPenalty - readPenalty;
  }
}

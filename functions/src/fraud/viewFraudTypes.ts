import { FieldValue } from 'firebase-admin/firestore';

export enum FraudSignalType {
  IP_CLUSTER = 'ip_cluster',
  BEHAVIORAL_UNIFORMITY = 'behavioral_uniformity',
  VIEW_VELOCITY = 'view_velocity',
  DEVICE_FINGERPRINT_CLUSTER = 'device_fingerprint_cluster',
  CONCURRENT_SESSION_ABUSE = 'concurrent_session_abuse',
  ANONYMOUS_FLOOD = 'anonymous_flood'
}

export enum FraudSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical'
}

export interface ViewFraudSignal {
  signalType: FraudSignalType;
  severity: FraudSeverity;
  videoId: string;
  channelId?: string;
  description: string;
  evidence: Record<string, any>;
  detectedAt: FieldValue;
  affectedSessionCount: number;
  affectedIPs?: string[];
  status: 'pending_review' | 'confirmed' | 'cleared';
}

export const IP_CLUSTER_SAME_VIDEO_THRESHOLD = 50;
export const IP_CLUSTER_SUBNET_THRESHOLD = 200;
export const IP_GLOBAL_BLOCK_THRESHOLD = 500;
export const CONCURRENT_SESSION_LIMIT = 3;
export const ANONYMOUS_IP_RATE_LIMIT = 20;
export const ANONYMOUS_IP_BLOCK_DURATION_MS = 3600000;
export const BEHAVIORAL_UNIFORMITY_MIN_SESSIONS = 50;
export const BEHAVIORAL_UNIFORMITY_CV_THRESHOLD = 0.15;
export const VIEW_VELOCITY_NEW_VIDEO_THRESHOLD = 1000;
export const VIEW_VELOCITY_BURST_THRESHOLD = 5000;
export const DEVICE_FINGERPRINT_DOMINANCE_THRESHOLD = 0.60;

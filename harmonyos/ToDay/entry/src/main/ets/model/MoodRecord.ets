export type Mood =
  | 'happy'
  | 'calm'
  | 'focused'
  | 'grateful'
  | 'excited'
  | 'tired'
  | 'anxious'
  | 'sad'
  | 'irritated'
  | 'bored'
  | 'sleepy'
  | 'satisfied';

export interface MoodPhotoAttachment {
  id: string;
  url: string;
  createdAt: number;
}

export interface MoodRecord {
  id: string;
  mood: Mood;
  note: string;
  createdAt: number;
  endedAt?: number;
  isTracking: boolean;
  captureMode: 'point' | 'session';
  photoAttachments: MoodPhotoAttachment[];
}

export interface MoodDescriptor {
  key: Mood;
  label: string;
  emoji: string;
  tone: string;
  softTone: string;
}

const MOOD_DESCRIPTORS: MoodDescriptor[] = [
  { key: 'happy', label: '开心', emoji: '😊', tone: 'accent', softTone: 'accentSoft' },
  { key: 'calm', label: '平静', emoji: '🌿', tone: 'teal', softTone: 'tealSoft' },
  { key: 'focused', label: '专注', emoji: '🎯', tone: 'blue', softTone: 'blueSoft' },
  { key: 'grateful', label: '感恩', emoji: '🙏', tone: 'teal', softTone: 'tealSoft' },
  { key: 'excited', label: '兴奋', emoji: '🤩', tone: 'rose', softTone: 'roseSoft' },
  { key: 'tired', label: '疲惫', emoji: '😴', tone: 'inkMuted', softTone: 'elevatedCard' },
  { key: 'anxious', label: '焦虑', emoji: '😰', tone: 'rose', softTone: 'roseSoft' },
  { key: 'sad', label: '难过', emoji: '😔', tone: 'blue', softTone: 'blueSoft' },
  { key: 'irritated', label: '烦躁', emoji: '😤', tone: 'workoutOrange', softTone: 'accentSoft' },
  { key: 'bored', label: '无聊', emoji: '🥱', tone: 'inkMuted', softTone: 'elevatedCard' },
  { key: 'sleepy', label: '困倦', emoji: '😪', tone: 'sleepIndigo', softTone: 'blueSoft' },
  { key: 'satisfied', label: '满足', emoji: '☺️', tone: 'accent', softTone: 'accentSoft' }
];

export function getMoodDescriptors(): MoodDescriptor[] {
  return MOOD_DESCRIPTORS.slice();
}

export function getMoodDescriptor(mood: Mood): MoodDescriptor {
  const match = MOOD_DESCRIPTORS.find((item) => item.key === mood);
  if (match) {
    return match;
  }
  return MOOD_DESCRIPTORS[0];
}

export function getMoodDisplayName(mood: Mood): string {
  return getMoodDescriptor(mood).label;
}

export function getMoodEmoji(mood: Mood): string {
  return getMoodDescriptor(mood).emoji;
}

export function moodFromStoredValue(value: string): Mood | undefined {
  const normalized = value.trim();
  const match = MOOD_DESCRIPTORS.find((item) => {
    return item.key === normalized || item.label === normalized || item.emoji === normalized;
  });
  return match?.key;
}

export function createMoodRecord(
  mood: Mood,
  note: string = '',
  createdAt: number = Date.now(),
  captureMode: 'point' | 'session' = 'point'
): MoodRecord {
  const isTracking = captureMode === 'session';
  return {
    id: `${createdAt}-${captureMode}-${mood}`,
    mood,
    note,
    createdAt,
    endedAt: captureMode === 'point' ? createdAt : undefined,
    isTracking,
    captureMode,
    photoAttachments: []
  };
}

export function completeMoodRecord(record: MoodRecord, completedAt: number = Date.now()): MoodRecord {
  return {
    id: record.id,
    mood: record.mood,
    note: record.note,
    createdAt: record.createdAt,
    endedAt: Math.max(completedAt, record.createdAt),
    isTracking: false,
    captureMode: 'session',
    photoAttachments: record.photoAttachments
  };
}

export function isMoodRecordOngoing(record: MoodRecord): boolean {
  return record.captureMode === 'session' && record.isTracking && record.endedAt === undefined;
}

export function moodRecordDisplayEndDate(record: MoodRecord, referenceDate: number = Date.now()): number {
  if (isMoodRecordOngoing(record)) {
    return Math.max(referenceDate, record.createdAt);
  }
  return record.endedAt ?? record.createdAt;
}

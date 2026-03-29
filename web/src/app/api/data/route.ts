import { NextRequest } from "next/server";

// In-memory store for MVP (replace with Supabase later)
const dataStore: DataPoint[] = [];

interface DataPoint {
  id: string;
  source: string;
  type: string;
  value: Record<string, unknown>;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { source, type, value, timestamp, metadata } = body;

    if (!source || !type || value === undefined || !timestamp) {
      return Response.json(
        { error: "Missing required fields: source, type, value, timestamp" },
        { status: 400 }
      );
    }

    const dataPoint: DataPoint = {
      id: crypto.randomUUID(),
      source,
      type,
      value: typeof value === "object" ? value : { raw: value },
      timestamp,
      metadata,
    };

    dataStore.push(dataPoint);

    return Response.json({ success: true, id: dataPoint.id });
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date"); // "2026-03-29"
  const source = searchParams.get("source"); // "browser-extension"

  let filtered = dataStore;

  if (date) {
    filtered = filtered.filter((d) => d.timestamp.startsWith(date));
  }

  if (source) {
    filtered = filtered.filter((d) => d.source === source);
  }

  return Response.json({ data: filtered, count: filtered.length });
}

// In-memory store for MVP (replace with Supabase later)
const dataStore: DataPoint[] = [];

interface DataPoint {
  id: string;
  source: string;
  type: string;
  value: number | string;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export async function POST(req: Request) {
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
      value,
      timestamp,
      metadata,
    };

    dataStore.push(dataPoint);

    return Response.json({ success: true, id: dataPoint.id });
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
}

export async function GET() {
  return Response.json({ data: dataStore, count: dataStore.length });
}

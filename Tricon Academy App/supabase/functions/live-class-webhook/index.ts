import { WebhookReceiver } from "npm:livekit-server-sdk@2.19.0";
import { db, env, response } from "../_shared/live.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return response({ message: "POST required" }, 405);
  try {
    // Verify signature against the exact raw body before parsing or accessing service-role data.
    const receiver = new WebhookReceiver(env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"));
    const event = await receiver.receive(await request.text(), request.headers.get("Authorization") ?? "");
    const room = event.room?.name;
    if (!room || !/^live-[0-9a-f-]{36}$/i.test(room)) return response({ ignored: true });
    const lessonID = room.slice(5);
    const participant = event.participant;
    const timestamp = new Date(Number(event.createdAt) * 1000).toISOString();
    if ((event.event === "participant_joined" || event.event === "participant_left") && participant) {
      if (!/^[0-9a-f-]{36}$/i.test(participant.identity)) return response({ ignored: true });
      await db("rpc/live_record_attendance", env("SUPABASE_SERVICE_ROLE_KEY"), {
        method: "POST", body: JSON.stringify({ p_lesson_id: lessonID, p_user_id: participant.identity,
          p_session_id: participant.sid, p_event: event.event, p_at: timestamp }),
      });
    }
    if (event.event === "room_finished") {
      await db("rpc/live_room_finished", env("SUPABASE_SERVICE_ROLE_KEY"), {
        method: "POST", body: JSON.stringify({ p_lesson_id: lessonID, p_at: timestamp }),
      });
    }
    return response({ received: true });
  } catch {
    // Non-2xx permits LiveKit retry after transient database failures. Never log tokens/body.
    return response({ message: "Webhook could not be verified or processed" }, 500);
  }
});

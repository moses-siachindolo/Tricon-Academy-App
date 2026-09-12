import { RoomServiceClient } from "npm:livekit-server-sdk@2.19.0";
import { authorize, db, env, response, roomName } from "../_shared/live.ts";

Deno.serve(async (request) => {
  try {
    const { token, input, lesson } = await authorize(request);
    const permitted = await db("rpc/live_can_manage", token, { method: "POST", body: JSON.stringify({ p_lesson_id: lesson.id }) });
    if (!permitted) return response({ message: "Only the assigned tutor or an administrator can manage this class." }, 403);
    if (input.action !== "end") {
      // Do not start a room or claim recording success without an egress integration.
      return response({ message: "Starting classes requires the LiveKit room and recording orchestration described in LIVE_CLASSES_SETUP.md." }, 503);
    }
    if (!["live", "completed"].includes(lesson.status)) return response({ message: "This class is not live." }, 409);
    const rooms = new RoomServiceClient(env("LIVEKIT_URL").replace(/^ws/, "http"), env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"));
    // Close admission before disconnecting participants. Retry end if room deletion fails.
    await db(`live_lessons?id=eq.${lesson.id}&status=eq.live`, env("SUPABASE_SERVICE_ROLE_KEY"), {
      method: "PATCH", body: JSON.stringify({ status: "completed", ended_at: new Date().toISOString() }),
    });
    const active = await rooms.listRooms([roomName(lesson.id)]);
    if (active.length) await rooms.deleteRoom(roomName(lesson.id));
    return response({ ended: true });
  } catch (error) {
    return response({ message: error instanceof Error ? error.message : "Unable to end class" }, 400);
  }
});

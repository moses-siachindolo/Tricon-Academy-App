import { AccessToken } from "npm:livekit-server-sdk@2.19.0";
import { authorize, env, response, roomName } from "../_shared/live.ts";

Deno.serve(async (request) => {
  try {
    const { user, lesson } = await authorize(request);
    if (lesson.status !== "live") return response({ message: "This lesson is not live." }, 409);
    const token = new AccessToken(env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"), {
      identity: user.id, ttl: 120,
    });
    token.addGrant({ room: roomName(lesson.id), roomJoin: true, canSubscribe: true,
      canPublish: true, canPublishData: true, roomAdmin: false, roomRecord: false });
    // No credentials are logged or persisted. One room, verified user, two-minute token.
    return response({ server_url: env("LIVEKIT_URL"), participant_token: await token.toJwt() });
  } catch (error) {
    return response({ message: error instanceof Error ? error.message : "Unable to join class" }, 400);
  }
});

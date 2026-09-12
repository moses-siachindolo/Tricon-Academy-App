# Live Classes implementation and deployment

The app has Live Classes on student Home and a dedicated Live Lessons tab for tutors and admins, replacing their Saved tab. All live lesson management is available in that tab; students retain Saved. It uses the existing SupabaseClient, AuthManager, User subject permissions, AppTheme, navigation, and VideoPlayerScreen. Existing tab indices are preserved.

## Implemented

- Live/upcoming/completed/cancelled lesson lists; recorded lessons with their logical folder.
- Schedule/edit/cancel, assign approved tutors, subject/form/topic/date/duration, recording preference and logical destination. Go Live Now saves a lesson for immediate starting; it does not pretend a room has started.
- Lesson invitations containing only a UUID, copy/share actions, authenticated deep-link navigation (including links opened before login).
- Reminder subscriptions, local 60/15-minute reminders, Updates with unread bell, read receipts, foreground refresh every 30 seconds. Logout removes lesson reminders and account data.
- Signed private recording playback using the existing player; metadata is written only by the backend.
- Classroom preview: tutor-video area, participants, mic/camera/share/hand/chat/leave/end controls and server-confirmed recording indicator.
- `LiveVideoService` protocol, deliberately unavailable adapter, and a classroom store. Unavailable controls cannot simulate attendance, video, chat or recording.
- SQL tables, RLS, notification triggers, reminder dispatcher, private bucket, and idempotent attendance functions.
- Server scaffolding for authenticated short-lived LiveKit tokens, ending rooms, and signature-verified attendance webhooks.

## Run this SQL

Apply **`supabase/20260912_live_classes.sql`**, once, after the existing repository's `../supabase/schema.sql` and student/admin/tutor migrations. This feature's files are inside the app workspace; the older SQL is in its parent directory. Use Supabase SQL Editor or include this migration in your normal deployment workflow. No remote changes have been applied by Codex.

The migration is transactional and expects existing `profiles` columns including `grade`, `is_blocked`, `is_removed`, `subject_major`, `allowed_extra_subjects`, and `tutor_approval_status`.

Student access is restricted to the profile's grade; approved tutors manage/view their assigned lessons in approved subjects; active admins manage all lessons. Recorded lessons inherit the lesson audience. Attendance sessions are visible to their owner and lesson managers. Clients cannot write attendance, recording metadata, lifecycle status or notification bodies.

The existing profile policies allow self-updates. A new trigger protects role, approval, approved tutor majors, extra subjects and block/removal flags from self-escalation. Tutor applications can still move from none/rejected to pending. Approval and changes to an already-approved major require an admin. Review this deliberate permission tightening when deploying; it is necessary for server-enforced tutor restrictions. Audit any other privileged RPCs/custom profile policies in your deployed project.

Enable Supabase Cron (`pg_cron`), then run once:

```sql
select cron.schedule('live-reminders', '* * * * *',
  'select public.dispatch_live_reminders()');
```

Notification triggers handle scheduled, edited, cancelled, live and recording-ready events. Cron generates 60/15-minute in-app reminders for subscribers. Devices refresh reminders while active; an offline device cannot learn about a reschedule/cancellation until it reconnects.

## LiveKit and Edge Functions still required

**Live audio/video is intentionally a stub in this build. Installing credentials alone will not enable it.** No LiveKit SDK is linked into the Xcode target. The following integration remains:

1. Add the official `https://github.com/livekit/client-sdk-swift` Swift package to the existing app target using an SDK release compatible with your Xcode. Implement `LiveVideoService` with LiveKit Room and inject it into `LiveClassroomStore`. Fetch `live-class-token` with the Supabase bearer token through the existing client; use its `server_url` and `participant_token` only in memory.
2. Forward participant/track/data/connection events to the classroom store; render the main tutor's camera or shared-screen track and participant tiles. Implement real microphone/camera controls, reliable chat and hand-state messages, reconnection and disconnect cleanup. No adapter/rendering bridge is included yet. For sharing outside the app, add a ReplayKit Broadcast Upload Extension and App Group; in-app sharing can use the SDK's in-app capture support.
3. Implement the **start** branch of `live-class-control`: authorize with `live_can_manage`, serialize concurrent starts, provision the deterministic `live-{lessonUUID}` room, configure recording when requested, then set `status='live'` and `started_at` with the service role. On failure, clean up provisioned resources and preserve a retryable scheduled state. The supplied start branch returns HTTP 503; the classroom Start button explains the unavailable setup.
4. Deploy the supplied `live-class-token`, `live-class-control`, and `live-class-webhook` functions, including `_shared/live.ts`. Set server secrets `LIVEKIT_URL` (wss URL), `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`. Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` in Edge Functions. Never add LiveKit secrets, service-role keys, or permanent room tokens to Swift/Info.plist.
5. Token/control endpoints authenticate through `/auth/v1/user` and RLS. The webhook must be deployed with platform JWT verification disabled because it validates the LiveKit signature on the raw body itself. Configure LiveKit webhook delivery to that endpoint for participant_joined, participant_left and room_finished. Token TTL is 120 seconds. Configure LiveKit token revocation/admission behavior and validate end-of-room rejoin prevention for your deployment; already-issued tokens may remain valid until expiry.
6. The supplied end endpoint closes database admission before deleting the LiveKit room. If deletion fails, retry the same end request (it accepts completed lessons). Add a durable cleanup/reconciliation worker for interrupted requests and missed webhook deliveries before production use. The Swift UI does not automatically retry a failed completed-room cleanup.

Server SDK reference: https://docs.livekit.io/reference/server-sdk-js/
Webhook verification: https://docs.livekit.io/intro/basics/rooms-participants-tracks/webhooks-events/
The scaffolding pins `livekit-server-sdk` 2.19.0; dependencies have not been downloaded or deployed here.

## Recording storage still required

The SQL creates/forces a **private** `live-recordings` bucket. Its read policy requires a ready metadata row and lesson access. Only your backend/service role should upload or delete objects. Verify that no pre-existing broad Storage policies grant access to every bucket, as PostgreSQL permissive policies combine with OR.

Implement LiveKit Egress orchestration before enabling recordings:

- Read `recording_enabled` and `recording_folder` from the authorized lesson before starting. Treat the folder (e.g. `Physics/Form 4/Kinematics/Motion Graphs`) as a logical organization label. Generate the actual object key server-side, e.g. `{lessonUUID}/{recordingUUID}.mp4`.
- Configure LiveKit Egress and Supabase Storage S3-compatible credentials/endpoint, or transfer the completed object to Supabase in a trusted worker. S3 keys belong only in backend secrets. Do not accept an arbitrary upload URL/object key from the app.
- Create processing metadata in `live_lesson_recordings`, storing the egress ID, title, folder and actual storage path. Set `recording_active=true` only after a verified egress-start event.
- Extend the webhook to verify and handle egress completion/failure idempotently, verify the object exists, mark it ready/failed, and clear `recording_active`. The recording-ready SQL trigger then creates notifications. Egress event processing is **not implemented** in the supplied webhook.
- Ensure ending a room stops its egress and finalizes metadata. Only ready objects appear in Recorded Lessons. Playback obtains a one-hour signed URL on opening; reopening playback obtains a new URL.

LiveKit recording documentation: https://docs.livekit.io/transport/media/ingress-egress/egress/

## Notifications beyond local reminders

In-app upcoming/live/recording-ready notifications work after database/worker setup, and local scheduled reminders work after user permission. Background **remote push** for LIVE/recording-ready events requires APNs entitlement/provisioning, an account-scoped device-token table, and a trusted notification delivery worker. These are not configured or implemented here. The app never labels a scheduled time as LIVE without a server state change.

## Validation

Run `python3 tests/run_live_classes_regressions.py` for production model/service/stub checks, and the existing regression scripts under `tests/`. The new test checks malformed/credential-bearing links, tutor permissions, Codable round trips, protected PATCH fields, stale edits and fail-closed classroom behavior.

Swift syntax and plist/project-format checks can run with Command Line Tools. Full SwiftUI type checking and an iOS simulator build require Xcode, which is absent on this Mac. After installing/selecting Xcode:

```sh
xcodebuild -project '../Tricon Academy App.xcodeproj' -scheme 'Tricon Academy App' -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Before release, test in a staging Supabase project with student (matching and different grade), approved and unapproved tutor, unrelated tutor, admin, blocked and removed accounts. Verify all privileged writes fail for students, tutors cannot assign themselves new subjects, non-subscribers do not get reminder notifications, and private recordings cannot be read anonymously. Test webhook retries/out-of-order delivery, room end/disconnect, denied camera/mic permissions, logout/login account isolation and cold invitation links on devices. SQL and Edge Functions have not been executed against a server here.

### Results on this machine

- PASS: Live Classes regressions (also type-checks production model, service, store, notification manager and video stub with test network dependencies).
- PASS: existing model/persistence, account-access and document-cache regressions.
- PASS: Swift source parsing, Info.plist and project.pbxproj validation, `git diff --check`.
- FAILED: existing video-download regression while generating media through macOS AVFoundation (`AVFoundationErrorDomain -11800`, underlying `-12903`). The existing video player/download implementation was not changed.
- BLOCKED: actual iOS `xcodebuild ... build` invocation because only `/Library/Developer/CommandLineTools` is selected and no Xcode app is installed. The iOS project has **not** been confirmed to build successfully.
- NOT RUN: Supabase SQL/RLS integration and Deno/LiveKit Edge Function tests (no local PostgreSQL/Deno or configured staging backend).

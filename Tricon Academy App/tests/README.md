# UI and reliability validation

Run the portable model regressions from the app source directory:

```sh
python3 tests/run_model_regressions.py
```

This harness compiles the production bookmark and activity managers with the Foundation-only curriculum model declarations. It uses an isolated UserDefaults suite and checks metadata persistence, legacy bookmark decoding, bookmark toggling, daily goal uniqueness, exact subject matching, form changes, first activity, and daily rollover. It does not compile SwiftUI, PDFKit, AVKit, or the full iOS target.

Bookmark regressions also check student/tutor account isolation, removal and clearing within one account, logout, signed-out actions, relaunch persistence, and exclusion of the old unowned shared list. Existing shared bookmarks remain on disk but are no longer displayed; users must save those resources again under their own accounts.

On a Mac with Xcode, build the app target and verify these scenarios on a small iPhone and at accessibility text sizes, in both light and dark appearance:

- Log in using the keyboard Next/Go buttons. Submit an invalid password and recover. Submit a password reset once; confirm repeat taps are blocked while waiting and failures permit retry.
- Open a valid local and remote PDF. Open a missing file, corrupt file, and unavailable remote URL. Failures should show a useful message and leave learning activity unchanged; remote failures should permit retry.
- Play a valid video, navigate away, and background the app. Playback should pause when leaving. Missing or failed videos should not award activity. Completion should appear only at the actual end of playback.
- Save a paper, note, and video. Restart and open each from Saved. Verify year, topic, and duration; search by title or subject and combine search with category filters.
- Save resources as a student, log out, and sign in as a tutor on the same device. Verify Saved, the profile count, and bookmark icons show only the tutor's saves. Save/remove/clear as the tutor, then return to the student and verify their saves remain. Repeat after relaunch and session restoration.
- Browse forms and library categories with large text. Check that content filters remain reachable horizontally and error messages have room to wrap.
- Refresh the library online and offline. Confirm loading feedback, retry, and preservation of cached books.
- Sign in as an approved tutor. Check that Overview and Content use the same responsive layout, subject shortcuts open the form picker, and resource counts/recent rows include only approved subjects (including approved extras). Check a tutor with no assigned subjects: resource upload should be disabled and Request subject access should remain available.
- On tutor Content, cancel a resource deletion and confirm the resource remains; confirm deletion on a disposable resource. Pull to refresh, test a failed sync and Retry, and check empty submissions plus pending/approved/rejected books with long review feedback.
- Reopen a rejected tutor application using Update details & resubmit. Verify existing details and specialist subjects are filled, the gender picker has a valid selection, and fields cannot change while submission is in progress. Check the form with accessibility text and the keyboard visible.
- Verify student, tutor, and administrator access, registration, email verification, uploads, and approval flows against the configured backend. These flows have not been exercised by the portable tests.

The workspace already contained changes before this repair pass. Repository-wide diff statistics include those earlier edits.

Document cache checks (macOS with Swift command-line tools and PDFKit):

```sh
python3 tests/run_document_cache_regressions.py
```

These checks compile the production PDF cache and verify offline disk reuse across cache instances, credential/account isolation, reuse after token refresh, availability beyond seven days, and corrupt PDF rejection. Documents are now kept in Application Support, excluded from device backup, with no automatic expiry or size-based eviction. Older cache files are copied across only when their credential hash matches; an older download that cannot be matched may need to be opened online once again.

Video download checks (macOS with Swift command-line tools and AVFoundation):

```sh
python3 tests/run_video_download_regressions.py
```

These create a playable video fixture and verify local playback lookup, relaunch persistence, account isolation, signed-out isolation, and corrupt file rejection. Videos require an explicit **Download for offline** action and a completed download; streaming alone does not save a full copy. Downloads support complete video files rather than HLS playlists.

On an iPhone/simulator:

- On the final onboarding page with the video illustration, tap Back and verify the first welcome page appears. Continue and Skip should still reach account creation/login.
- Log in with Remember me enabled. Open a paper, note, and library PDF, and download a video. Wait for Available offline, then enable airplane mode and restart the app. Browse and reopen those same resources, including through Saved.
- Verify an undownloaded resource fails with a useful retry option while offline. Restore connectivity and retry. Failed downloads must not show Available offline.
- Sign in as another account and confirm private downloads are not reused. Return to the original account and verify the downloads remain available.
- Verify video playback pauses on navigation/backgrounding, downloading does not mark a lesson complete, and token refresh does not hide downloaded PDFs.
- Signing in to a new account, new downloads, uploads, and server updates still require connectivity. A remembered account opens cached content immediately; a confirmed revoked or invalid session still requires login.


Shared UI polish verification on an iPhone/simulator:

- Check Light and Dark appearance on Home, Browse, subject folders, Saved, Library, Profile, Settings, authentication/onboarding, and all staff screens. Button fills should retain readable labels, with consistent control/card corners and semantic error colors.
- Check bookmark, delete, search-clear, and password-visibility controls: their rounded icon wells should provide 44-point targets, preserve accessibility labels, and trigger only their own action.
- Check disabled login, registration, tutor application, upload, and subject-request actions. They should look disabled and remain unavailable until valid.
- Check larger accessibility text sizes: primary actions and admin action rows should grow vertically without clipping. Check Reduce Motion: shared button press feedback should avoid scaling.

The Swift files were syntax-checked locally. Native visual verification and an iOS build require full Xcode, which is not installed on this Mac.

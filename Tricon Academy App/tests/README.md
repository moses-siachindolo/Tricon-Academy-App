# UI and reliability validation

Run the portable model regressions from the app source directory:

```sh
python3 tests/run_model_regressions.py
```

This harness compiles the production bookmark and activity managers with the Foundation-only curriculum model declarations. It uses an isolated UserDefaults suite and checks metadata persistence, legacy bookmark decoding, bookmark toggling, daily goal uniqueness, exact subject matching, form changes, first activity, and daily rollover. It does not compile SwiftUI, PDFKit, AVKit, or the full iOS target.

On a Mac with Xcode, build the app target and verify these scenarios on a small iPhone and at accessibility text sizes, in both light and dark appearance:

- Log in using the keyboard Next/Go buttons. Submit an invalid password and recover. Submit a password reset once; confirm repeat taps are blocked while waiting and failures permit retry.
- Open a valid local and remote PDF. Open a missing file, corrupt file, and unavailable remote URL. Failures should show a useful message and leave learning activity unchanged; remote failures should permit retry.
- Play a valid video, navigate away, and background the app. Playback should pause when leaving. Missing or failed videos should not award activity. Completion should appear only at the actual end of playback.
- Save a paper, note, and video. Restart and open each from Saved. Verify year, topic, and duration; search by title or subject and combine search with category filters.
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

These checks compile the production cache and verify offline disk reuse across cache instances, credential isolation, seven-day expiry, and corrupt PDF rejection. On an iPhone, open the same remote PDF through Content, Saved, and Library: subsequent opens should use the cached file. Also verify first downloads, simultaneous opens, retry after connection failure, and large PDFs while navigating back. The cache prunes old files toward 250 MB after downloads, retaining the current document even if it exceeds that size. First downloads still depend on network/server throughput; documents replaced at the same URL may remain cached for up to seven days.

Shared UI polish verification on an iPhone/simulator:

- Check Light and Dark appearance on Home, Browse, subject folders, Saved, Library, Profile, Settings, authentication/onboarding, and all staff screens. Button fills should retain readable labels, with consistent control/card corners and semantic error colors.
- Check bookmark, delete, search-clear, and password-visibility controls: their rounded icon wells should provide 44-point targets, preserve accessibility labels, and trigger only their own action.
- Check disabled login, registration, tutor application, upload, and subject-request actions. They should look disabled and remain unavailable until valid.
- Check larger accessibility text sizes: primary actions and admin action rows should grow vertically without clipping. Check Reduce Motion: shared button press feedback should avoid scaling.

The Swift files were syntax-checked locally. Native visual verification and an iOS build require full Xcode, which is not installed on this Mac.

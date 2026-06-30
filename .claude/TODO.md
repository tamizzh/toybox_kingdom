# Toybox Kingdoms — UI Button Task TODO

## Completed
- [x] Root cause fixed: `TextureButton.ignore_texture_size = true` in ui_kit.gd so custom_minimum_size is respected
- [x] UIKit always uses SM textures (btn_gold_sm.png / btn_blue_sm.png) for all overlay buttons
- [x] CenterContainer with `offset_bottom = -22% of h` shifts text up to align with 3D button face
- [x] daily_screen: PLAY TODAY=200, CLOSE=200
- [x] settings_screen: Restore Purchases=200 (font=16), Privacy Policy=200 (font=18), CLOSE=200
- [x] campaign_screen: CONQUER/REPLAY=110, CLOSE=100
- [x] world_map_screen: CLOSE=200
- [x] profile_screen: CLOSE=110
- [x] onboarding_screen: NEXT=200, SKIP=200 — SKIP position fixed to stay on-screen
- [x] z_index=100 + mouse_filter=MOUSE_FILTER_STOP on all overlay screens

## Remaining

### Verify remaining screenshots
- [ ] Check shot_campaign.png — CONQUER button in stage card row, CLOSE at bottom
- [ ] Check shot_profile.png — CLOSE button centered
- [ ] Check shot_world_map.png — CLOSE button centered (need to add world_map to shot harness if missing)
- [ ] Check shot_onboarding.png — NEXT centered, SKIP in top-right with margin

### In-game panels (kingdom_match.gd)
- [ ] Review in-game panel buttons: CONTINUE (w=264), GIVE UP (w=220), RESUME (w=220), MAIN MENU (w=220), PLAY AGAIN (w=264)
- [ ] These use a different button path (_sprite_button) — check if they also need ignore_texture_size or are already correct

### buttons_preview.gd
- [ ] Update buttons_preview.gd to reflect SM-only approach and new widths (currently may reference old LG/MD sizes)

### Polish
- [ ] Verify text is not clipped in any button (especially "Restore Purchases" at font=16, w=200)
- [ ] Test on a real device / different aspect ratio to confirm layout holds

# Publishing ExtendedCoop8 to the Steam Workshop

Everything you need is in this folder:

- `MattieTK-ExtendedCoop8.zip` — the mod, upload-ready
- `preview.png` — 512x512 workshop thumbnail
- `description.txt` — BBCode description to paste on the workshop page

## Steps (from the official Brotato modding guide)

1. In Steam: right-click **Brotato → Properties → Betas** and select the
   **modding** branch. Let it update.
2. Launch Brotato from Steam — it now offers the **workshop uploader**
   (GodotWorkshopUtility). Do NOT run the exe directly; it only works when
   started through Steam.
3. In the uploader:
   - Mod zip: `modwork\mod\workshop\MattieTK-ExtendedCoop8.zip`
   - Image: `modwork\mod\workshop\preview.png`
   - Workshop ID: leave **blank** (first upload creates the item;
     for later updates, paste the id from the mod's workshop URL)
4. After it uploads, open the new workshop page:
   - Paste in `description.txt`
   - Set visibility (new items start **Hidden** — keep it hidden for
     private testing with friends, or set Public)
5. Switch the Betas branch back to **None** to return to the normal game.
6. **Subscribe to your own item**, then clean up the temporary install:
   - delete `steamapps\workshop\content\1942280\3629226509\MattieTK-ExtendedCoop8.zip`
   - unsubscribe from the old "Extended Coop" mod (id 3629226509)
   Your subscription then keeps the mod installed and updated like any
   workshop mod, for you and anyone you share the link with.

Notes:
- Your Steam account needs at least $5 USD spent to publish workshop items.
- To ship an update later: rebuild the zip (`modwork\run_test.ps1` does this
  as part of a test run, or `Compress-Archive mods-unpacked -> zip`), run the
  uploader again with the existing workshop ID.

# Thử hình tướng bằng sprite-gen (quy trình làm lại)

Trạng thái 2026-11-09: **thử nghiệm, đã merge vào master nhưng TẮT mặc định** (user: "ổn đó", chưa đổi, release dùng tướng cũ). Hình chính vẫn là rig SVG (`docs/rig_port.md`). Bật: cờ `sprite` (desktop: `-- sprite`, web: `?sprite`), hoặc **F8** trong game.
Đã làm: tướng ta (Hiệp Sĩ Chỉ Huy, `hero_p`) = 1 ảnh đứng mới + đòn "Nhảy bổ" (thủ kiếm -> bật nhảy -> bổ kiếm cắm đất, có vệt chém + bụi vẽ sẵn). Tướng địch vẫn là rig.

## Nguyên tắc
- **Không tốn tiền** (user 2026-11-09). Vẽ ảnh + làm video trên web bằng lượt miễn phí (Gemini đã dùng được; grok.com cũng được nếu còn lượt). Phần còn lại chạy ở máy, miễn phí.
- Đường trả tiền (không dùng): `sprite-gen gen --provider grok` / `video` cần SuperGrok hoặc credit xAI (tài khoản user: HTTP 403 `personal-team-blocked:spending-limit`); `--provider codex` cần codex CLI + ChatGPT. `pixel-draw` (Claude) miễn phí nhưng ra pixel art ≤ 48 px, lệch kiểu chibi.

## Cài một lần (Windows)
- sprite-gen (ngoài repo, mỗi máy một lần): `git clone https://github.com/aldegad/sprite-gen`, rồi trong thư mục đó `python -m venv .venv && .venv/Scripts/python -m pip install -e .`. Gọi `.venv/Scripts/sprite-gen`.
- ffmpeg: `winget install Gyan.FFmpeg` (không tự vào PATH của shell đang mở: thêm `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_*\ffmpeg-*\bin`).
- img2webp ≥ 1.5 (`video-loop` bắt buộc có): tải `libwebp-1.5.0-windows-x64.zip` từ `storage.googleapis.com/downloads.webmproject.org/releases/webp/`, giải nén, thêm `bin\` vào PATH.
- Trong Git Bash, PATH phải dạng `/c/...` (dạng `C:/...` có dấu `:` làm hỏng PATH).
- Python đọc ảnh: dùng Python của venv sprite-gen (có Pillow + NumPy), chạy với `-I`.

## Các bước (RUN = 1 thư mục làm việc ngoài repo, ví dụ `%TEMP%\hero_try`)
Cấu trúc RUN mà `tools/sprite_try/sprite_try.py game` đọc: `RUN/still/hero_new_still.png`, `RUN/canvas.report.json`, `RUN/clip/frames/frames.report.json`, `RUN/clip/keyed_pad/`.

1. **Ảnh mẫu** từ hình hiện tại: mở `assets/units/styles/chibi/hero_p.svg` trong Chrome headless, chụp 1024×1024 nền trắng:
   `chrome --headless=new --window-size=1024,1024 --screenshot=RUN/hero_p_ref.png file:///.../ref.html` (ref.html = 1 thẻ `<img>` 1024px của SVG).
2. **Ảnh đứng (web)**: Gemini (gemini.google.com) hoặc grok.com Imagine: tải lên ảnh mẫu + dán `tools/sprite_try/prompts/hero_p_still.txt` (nhìn ngang, quay phải, nền xanh lá phẳng `#00FF00`, chừa lề). Tải ảnh về.
3. **Xoá logo + canvas**:
   - Gemini chèn logo ✦ góc dưới phải (ảnh 1024: khoảng 850..960): `python -I tools/sprite_try/sprite_try.py clean --still dl.jpg --out RUN/still/still_clean.png --erase 850,850,960,960`
   - `sprite-gen video-canvas --still RUN/still/still_clean.png --out RUN/canvas.png --state attack --facing right --headroom 0.3 --trail 0.25 --key green --report RUN/canvas.report.json` (khung 16:9, chừa chỗ trên đầu / phía trước / phía sau cho đường kiếm).
   - Ảnh đứng trong suốt: `sprite-gen cutout RUN/still/still_clean.png --out RUN/still/hero_new_still.png`.
4. **Video (web)**: tải `RUN/canvas.png` lên Gemini (tạo video) hoặc grok.com, dán `tools/sprite_try/prompts/hero_p_attack_video.txt` (không hiệu ứng, nền xanh phẳng, không chạm mép, máy quay đứng yên). Lần trước: Gemini trả 10 s, 1280×720, 24 fps, 1 đòn trọn vẹn ở giây 1.0–6.25 rồi đứng yên, có logo mờ (khi tách nền tự mất). Lưu thành `RUN/clip/clip.mp4`.
5. **Tách nền**: `sprite-gen video-frames --clip RUN/clip/clip.mp4 --out-dir RUN/clip/frames --key green --spill auto --reference RUN/canvas.png` (báo cáo phải có `edge_contacts: []`).
6. **Đệm mép dưới** (kiếm cắm đất chạm mép dưới -> `video-loop --cycle once` từ chối): `python -I tools/sprite_try/sprite_try.py pad --frames RUN/clip/frames/keyed --out RUN/clip/keyed_pad`.
7. **Tìm đoạn đòn**: `python -I tools/sprite_try/sprite_try.py match --frames RUN/clip/keyed_pad --ref 0` (IoU so với khung đứng: tụt xuống = bắt đầu thủ kiếm, lên lại ~0.98 = đã về tư thế đứng). Xem tấm ghép khung (ffmpeg `tile`, hoặc PIL) quanh lúc nhảy để chọn **khung kiếm chạm đất** = khung trúng đòn. Lần trước: thủ kiếm 24–69, nhảy ~70, chém 82–86 (trúng **86**), giữ thế tới ~130, về đứng 131–150.
8. (tuỳ chọn) bản tốc độ gốc để xem: `sprite-gen video-loop --frames-dir RUN/clip/keyed_pad --out-dir RUN/clip/loop_full --fps 24 --state attack --cycle once --start 24 --length 127 --facing right --name hero-attack-full`.
9. **Xuất cho game** (nén theo pha về ~1.2 s, đặt khung vào ô token):
   `python -I tools/sprite_try/sprite_try.py game --run RUN --picks "24-68:7,70-80:5,82,84,86,88,90,92,96,104,114,122,130,133-150:6" --hit 86 --out assets/units/sprite_try --name hero_p`
   -> `hero_p_still.png` (512), `hero_p_attack.png` (atlas 6 cột, 256 px / ô token), `hero_p_attack.json` (cells, frame_ms, hit_ms, slash_ms, lift_sq, rect_sq, source_frames). `a-b:n` = n khung rải đều từ a tới b. Đòn chậm -> bớt khung pha thủ kiếm (hit_ms = vị trí khung trúng × 41 ms).
10. **Kiểm tra trong game** (Godot console exe trong `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*`):
    - import: `--headless --path . --import` (không được có `SCRIPT ERROR`)
    - trận thật, mới vs cũ: `--path . --resolution 1280x720 -s sim/probes/rig_live.gd -- mission=m02 fresh nointro nobattle profile=test out=X.png att=hero def=soldier dir=right every=150 n=16` (+ `sprite` = bản mới, bỏ = rig cũ; thử thêm `dir=left|up`)
    - `tools/run_guarded.sh` + `sim/probes/rig_smoke.gd` -> `RIG SMOKE DONE ... fails=0`; `sim/tests.gd` -> 0 failed.
    - chơi: `--path . -- mission=m02 fresh sprite`; **F8** đổi qua lại mới / cũ (không có `sprite` = mở bằng hình cũ).

## Code (trong master, tắt mặc định)
| file | việc |
|---|---|
| `scripts/ui/rig/sprite_rig.gd` | `SpriteRig extends Rig`: đi đường `FX.rig_attack` như rig thường (máy quay, giật lùi, chớp, dừng hình, rung, số, tiếng, đánh trả); chỉ phần vẽ tướng = 1 ô atlas mỗi 41 ms qua `cam.char_xf` (ô 256-art = ô token, ô 0 trùng ảnh đứng). Sự kiện: tiếng chém + bụi ở `slash_ms`, HIT ở `hit_ms`, bụi + rung sau đó. Bóng thu nhỏ theo `lift_sq`. |
| `scripts/ui/rig/rigs.gd` | `Rigs.make`: thử `SpriteRig.make` trước (chỉ `hero`, phe `p`, `Token.sprite_hero`, kiểu `chibi`). |
| `scripts/ui/token.gd` | `Token.sprite_hero` (mặc định `false`), `SPRITE_STILL`: tướng ta đứng = PNG; chớp trắng = modulate sáng; khoá atlas có `sprite_hero` để F8 vẽ lại. |
| `scripts/ui/main.gd` | cờ `sprite` (bật lúc mở), phím F8 (đổi qua lại). |
| `export_presets.cfg` | `include_filter` thêm `assets/units/sprite_try/*.json` (thiếu = bản web/iOS âm thầm quay về rig). |
| `tools/sprite_try/` | `sprite_try.py` (clean / pad / match / game), `prompts/` (prompt ảnh đứng + video). |

## Nếu quyết định dùng thật (còn thiếu)
- Tướng địch: `sprite-gen recolor` ra bản đỏ rượu / tím (`docs/setting.md`), hoặc clip riêng cho Vorn; hiện 2 phe lệch kiểu.
- Đánh lên / xuống: video chỉ quay ngang -> vẫn chém ngang (rig cũ lao đúng hướng). Cần clip nhìn trước / sau, hoặc chấp nhận.
- Nhịp: trúng ~580–595 ms (rig cũ 362–372 ms) -> mỗi lần giao tranh thấy chậm hơn; chỉnh `--picks`.
- Dung lượng +2.9 MB PNG (bản web ~11 MB).
- Đồng bộ kiểu vẽ: chỉ đổi tướng thì lệch 10 loại lính còn lại -> làm cả bộ, hoặc lấy ý tưởng "nhảy bổ" làm đòn rig mới.
- `Token.warm()` vẫn raster `hero_p.svg` khi bật sprite (phí, không lỗi). `tools/lint.sh` chưa chạy được trên máy Windows này (thiếu gdtoolkit). Bật làm mặc định = đổi `Token.sprite_hero` + sửa `docs/STATUS.md` + `docs/rig_port.md` cùng commit.

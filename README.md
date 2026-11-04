# Hồn Sông Núi — bản Godot

Chiến thuật theo lượt trên lưới ô, lấy cảm hứng từ các cuộc khởi nghĩa của phụ nữ Việt thời Bắc thuộc. Godot 4.7, GDScript, chạy trên web và máy bàn.
Viết lại từ `../hon-song-nui` (JS + canvas, JS commit `3e888f1`), rồi mở rộng thành ba chương.

| Chương | Năm | Màn | Tướng ta mới | Địch |
|---|---|---|---|---|
| 1 · Khởi nghĩa Hai Bà Trưng | 40 | m01–m08 | Trưng Trắc, Trưng Nhị, Lê Chân | Đông Hán: Tô Định, Huyện lệnh, Đô úy, Hiệu úy |
| 2 · Chống Mã Viện | 42–43 | m09–m16 | Thánh Thiên, Bát Nàn, Phùng Thị Chính | Mã Viện, Lưu Long, Đoàn Chí |
| 3 · Bà Triệu | 248 | m17–m22 | Bà Triệu, Triệu Quốc Đạt | Đông Ngô: Lục Dận |

Kiểu màn: chiếm thành · diệt hết địch · hạ tướng địch · giữ vững N lượt · **đưa tướng tới ô đích** (mới, chương 2). Chương sau mở khi thắng hết chương trước. Thêm chế độ đấu tự do (chọn 1 trong 8 tướng) và Sách lính. Luật: `docs/spec.md`.

## Chơi
**Chơi ngay: https://hon-song-nui.vercel.app**

- **Cập nhật bản web trên Vercel** (scope cá nhân `nguyenvando51s-projects`, project `hon-song-nui`): `powershell -File tools/export_web.ps1`, chép `build/web` sang một thư mục tên `hon-song-nui`, rồi trong thư mục đó chạy `npx vercel deploy --prod --yes --scope nguyenvando51s-projects`. Kiểm tra: `python tools/web_smoke.py --url https://hon-song-nui.vercel.app/ --query "?mission=m05&bot&speed=3" --wait 60 --idb`.
- **Web:** mở bản dựng `build/web/index.html` qua một web server (không mở thẳng file). Phát hành: `powershell -File tools/export_web.ps1` -> `build/web/` + `build/hon-song-nui-web.zip` (~11 MB). itch.io: tạo project kiểu HTML, tải zip lên, bật "SharedArrayBuffer" không cần (bản dựng đơn luồng). GitHub Pages / Netlify: đẩy nguyên thư mục `build/web`.
- **Windows** (Godot 4.7.2 winget, không có trên PATH):
  ```
  set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
  %GODOT% --path .              # chơi
  %GODOT% -e --path .           # mở editor
  ```
  Clone mới: chạy `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` một lần. macOS: `godot --path .`.

### Điều khiển
- Bấm lính để thấy ô đi được. **Rê chuột lên kẻ địch**: bàn cờ vẽ đường tới ô đánh tốt nhất và nhãn "⚔ gây · ↩ nhận"; **bấm một lần là đánh**. (Màn hình cảm ứng: chạm lần 1 ngắm, lần 2 đánh.)
- Bấm ô xanh để đi tới; bấm **lại chính ô đó** = hành động mặc định (chiếm nếu được, không thì chờ). Thanh nút nhỏ hiện ngay cạnh lính (⚔ / 🏠 / 🩹 / Chờ / ✕).
- Phím: `Space`/`Enter` hành động mặc định · `Tab` lính kế chưa đi · `E` hết lượt · `H` gợi ý · `Esc`/chuột phải hủy.
- Bấm thành trống của ta để mua lính.

Cờ debug (sau `--`, hoặc trên web là query `?mission=m05&bot`): `mission=m03` vào thẳng màn · `bot` AI chơi phe ta · `speed=3` · `fresh` bỏ ván đang lưu · `screen=title|campaign[:c2]|briefing:m05|skirmish|codex` · `shots=res://shots/x shot_every=2 tag=x` chụp màn hình · `quit_at=60`.

## Kiểm tra
Mọi lệnh Godot nên chạy qua `tools/run_guarded.ps1` (kill khi vượt RAM / thời gian; một vòng lặp vẽ từng ngốn 60 GB làm treo máy):
```
powershell -File tools/run_guarded.ps1 -Log t.log -GArgs "--headless --path . -s sim/tests.gd"   # 42 test: luật, 22 màn hợp lệ, chương, lưu ván
powershell -File tools/run_guarded.ps1 -Log c.log -GArgs "--headless --path . -s sim/click_driver.gd -- mission=m02 fresh"  # 25 bước bấm chuột qua UI thật
bash tools/sim_many.sh "m09 m10 m11" 12 4                                                        # cân bằng: AI chơi cả hai phe
python tools/web_smoke.py --query "?mission=m05&bot&speed=3" --wait 70                           # chạy bản web trong Edge headless, in console + chụp
```
Godot có cửa sổ (chụp màn hình) cần màn hình đang bật; khi máy vắng người, chỉ chạy headless.

## Cân bằng (sim AI-vs-AI, 12 ván/màn)
AI chơi cả hai phe; "p" = số ván phe ta thắng. Chương 1 lấy số của bản JS gốc (20 ván, y hệt bản Godot).

| Màn | Kiểu | Ta thắng | Trung vị lượt | | Màn | Kiểu | Ta thắng | Trung vị lượt |
|---|---|---|---|---|---|---|---|---|
| m01 Lời Thề Hát Môn | diệt hết | 19/20 | 11 | | m12 Trận Lãng Bạc | chiếm thành | 12/12 | 24 |
| m02 Về Lại Mê Linh | chiếm thành | 20/20 | 18 | | m13 Địu Con Phá Vây | tới đích | 10/12 | 10 |
| m03 Giữ Làng Hạ Lôi | giữ vững | 20/20 | 11 | | m14 Rút Về Cấm Khê | tới đích | 8/12 | 8 |
| m04 Phá Đồn Cổ Loa | hạ tướng | 19/20 | 26 | | m15 Thành Cấm Khê | giữ vững | 7/12 | 11 |
| m05 Đêm Hồ Tây | chiếm thành | 11/20 | 19 | | m16 Đêm Sông Hát | giữ vững | 18/20 | 9 |
| m06 Kỵ Binh Bãi Sông | chiếm thành | 8/20 | 37 | | m17 Tiếng Gọi Núi Nưa | diệt hết | 11/12 | 9 |
| m07 Vây Thành Long Biên | chiếm thành | 12/20 | 26 | | m18 Hai Anh Em Họ Triệu | chiếm thành | 11/12 | 21 |
| m08 Trị Sở Luy Lâu | chiếm thành | 8/20 | 34 | | m19 Đồn Bồ Điền | hạ tướng | 9/12 | 18 |
| m09 Tin Dữ Hợp Phố | giữ vững | 12/12 | 10 | | m20 Voi Một Ngà | chiếm thành | 10/12 | 33 |
| m10 Sóng An Biên | hạ tướng | 8/12 | 29 | | m21 Lục Dận Kéo Quân | giữ vững | 10/12 | 11 |
| m11 Bát Nàn Giữ Ải | chiếm thành | 11/12 | 22 | | m22 Núi Tùng | chiếm thành | 7/12 | 36 |

Màn mở chương dễ (≥ 90%), giữa chương ~70–90%, trận cuối chương ~60%. Màn "giữ vững" khó cân hơn vì chỉ tướng địch chiếm được thành.

## Khớp với bản JS (chương 1)
Luật (`scripts/core/game.gd`) và AI (`scripts/core/ai.gd`) port 1-1 từ `src/core/engine.js` / `ai.js`: cùng thứ tự duyệt (Dijkstra lấy ô rẻ nhất, chèn trước thắng khi hòa = sort ổn định của V8), cùng biểu thức số thực, cùng RNG LCG tính bằng double. `sim/trace.gd` in cho mỗi ván hash của mọi nước AI + vị trí/máu/KN cuối + vàng; `sim/trace_js.cjs` in cùng định dạng từ bản JS.

| Đo 2026-11-04 (seed = 1000 + 7919·ván) | Ván giống hệt |
|---|---|
| Chiến dịch m01–m08 (AI cả hai phe) | 160/160 |
| Đấu tự do thường / dễ | 12/12 · 12/12 |
| Bot ngẫu nhiên vs AI | 10/10 |
| Sau khi thêm chương 2–3 (luật `reach`, tướng mới): m01, m04, m07 | 60/60 |

Các luật mới chỉ chạy khi màn khai báo (`win.type == "reach"`), nên chương 1 vẫn chơi y hệt bản JS. Đo lại: `node sim/trace_js.cjs ../hon-song-nui > js.txt`, `godot --headless --path . -s sim/trace.gd -- only=m01 > gd.txt`, `diff`.

AI một nước (GDScript, máy bàn): ~9 ms ở bản đồ nhỏ, ~26 ms ở bản đồ lớn.

## Thay nội dung (không đụng code)
| Muốn đổi | Sửa ở |
|---|---|
| Tên, icon, màu phe, chữ giao diện | `content/theme.gd` |
| Chương (tiêu đề, năm, bản đồ sơ đồ, đổi skin phe địch, lời kết chương) | `content/chapters/cN.gd` |
| Màn (1 file / màn, tự gom theo `order`, gắn `chapter`) | `content/campaign/mNN.gd`, định dạng ở `docs/content.md` |
| Bản đồ đấu tự do | `content/skirmish_maps.gd` |
| Chỉ số lính, tướng, địa hình, kinh tế | `scripts/core/rules.gd` |
| Ảnh thật thay emoji / hình vẽ | thêm `"img": "res://…png"` vào lính / tướng / địa hình trong theme |
Thêm emoji mới vào chữ: chạy `python tools/build_fonts.py <thư mục có NotoSansSymbols2.ttf>` để tải PNG Noto tương ứng.

## Kiến trúc
- `scripts/core`: luật thuần, không Node. Trạng thái ván là Dictionary (ô = `Vector2i`), lưu bằng `var_to_str` vào `user://` (web: IndexedDB). `content.gd` gom chương + màn và trả theme đã gộp theo chương đang mở.
- `scripts/ui`: `main.gd` (vỏ + cờ debug), `menus.gd` + `menu_bg.gd` + `camp_map.gd` (tiêu đề, tab chương + bản đồ, giới thiệu màn, đấu tự do, Sách lính), `game_screen.gd` (thanh trên, mẹo, bảng bên, thanh nút nổi, phát lại sự kiện, lượt địch, gợi ý, kết thúc), `board.gd` (bàn cờ: lớp địa hình cache, lớp động, FX, đêm, nhãn dự báo), `fx.gd`, `token.gd`, `style.gd`, `draw.gd`, `audio.gd` (âm thanh tổng hợp + nhạc ngũ cung), `emoji_font.gd`, `store.gd`.
- `shaders/`: nền menu, logo ánh kim, vignette, màn đêm.
- Font: Be Vietnam Pro + Alegreya SC (OFL), subset Noto Sans Symbols 2 (OFL), emoji Noto (Apache 2.0) đóng thành font bitmap lúc khởi động. Không dùng font hệ thống, nên web và máy bàn hiển thị như nhau.

## Giới hạn đã biết
- Bố cục ngang, tối ưu cho máy tính / máy tính bảng nằm ngang; điện thoại dọc chơi được nhưng chữ nhỏ.
- Âm thanh dựng sẵn thành sample lúc khởi động (22 kHz); trên web chỉ phát sau cú bấm đầu tiên (quy định trình duyệt).
- Sử tích trong game theo truyền thuyết và sách sử phổ thông, có lược bớt cho hợp lối chơi.

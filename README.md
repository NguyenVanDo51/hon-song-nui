# Hồn Sông Núi — bản Godot

Chiến thuật theo lượt trên lưới ô, lấy cảm hứng từ các cuộc khởi nghĩa của phụ nữ Việt thời Bắc thuộc. Godot 4.7, GDScript, chạy trên web và máy bàn.
Viết lại từ `../hon-song-nui` (JS + canvas, JS commit `3e888f1`), rồi mở rộng thành hai chương.

| Chương | Năm | Màn | Chỉ huy ta | Chỉ huy địch |
|---|---|---|---|---|
| 1 · Khởi nghĩa Hai Bà Trưng | 40 | m01–m08 | Trưng Trắc | Tô Định |
| 2 · Chống Mã Viện | 42–43 | m09–m16 | Trưng Trắc | Mã Viện |

Như các game chiến thuật lưới ô kinh điển: **hai phe dùng chung một bộ lính** (cùng tên, cùng icon, chỉ khác màu); chỉ huy ta suốt game là Trưng Trắc; chỉ huy địch mỗi chương một tên nhưng cùng hình, cùng chỉ số. Các nhân vật khác (Trưng Nhị, Lê Chân, Thánh Thiên, Bát Nàn, Phùng Thị Chính, Đoàn Chí...) chỉ xuất hiện trong lời thoại.

Kiểu màn: chiếm thành · diệt hết địch · hạ tướng địch · giữ vững N lượt · **đưa tướng tới ô đích** (chương 2). Chương sau mở khi thắng hết chương trước. Thêm chế độ đấu tự do (3 chiến trường) và Sách lính. Luật: `docs/spec.md`.

**Bản đồ** bố trí theo lối bản đồ chiến thuật cổ điển (đối chiếu bản làm lại Ancient Empires Reloaded): **đường mòn** nối thành với làng thành một mạng liền, qua sông bằng cầu; rừng / đồi / núi gom thành **khối** (núi ở lõi, đồi quanh, rừng ở mép) chiếm ~30% đất, chừa một vòng trống quanh thành. Đường mòn chỉ khác đồng lúa ở hình vẽ (thủ 0, tốn 1). Bản đồ sinh lại bằng `sim/mapgen.gd` từ bố cục tay (giữ thành, làng, sông, cầu, chỗ quân đứng / tiếp viện / ô đích).

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
- Bấm ô xanh để đi tới; bấm **lại chính ô đó** = hành động mặc định (chiếm nếu được, không thì chờ). Không có "đi tại chỗ": bấm lại lính đang đứng là bỏ chọn (trừ khi chiếm / cứu thương được ngay tại đó). Không có bảng bên: mọi lệnh (⚔ Đánh / 🏠 Chiếm / 🩹 / Chờ / Hủy), dự báo trận, mua lính, thông tin lính và ô đất hiện trong một popup ngay cạnh ô trên bàn cờ, tự né không che quân.
- **Cảnh giao chiến**: mỗi lần đánh, màn hình tách đôi, hai đội đứng trên địa hình ô của mình (đồng, đường, rừng, đồi, núi, sông, cầu, làng, thành, ban đêm), số người theo máu (5 lính / 3 voi, máy bắn đá / 1 tướng), xông lên chém hoặc bắn tên / phép / đá, lính ngã, đánh trả, rồi về bàn cờ. Bấm chuột hoặc phím bất kỳ để bỏ qua; 3 chế độ **Luôn / Khi ta đánh / Tắt** đổi bằng nút **⚔** trên thanh trên, phím `B`, hoặc chip **Cảnh đánh** ở màn tiêu đề (nhớ giữa các lần chơi). Tắt thì đánh ngay trên bàn cờ như cũ. Theo tốc độ x1/x2/x3.
- **Lượt địch**: giữ `Space` hoặc chuột để chạy x4; nút **⏩ Tua lượt địch** tua hết lượt đó và bỏ qua cảnh đánh.
- **Giữ chỗ**: chọn lính rồi `Space` = lính đứng yên, xong lượt (không đi). **Hết lượt** khi vẫn còn quân đánh / chiếm được: lần bấm đầu chỉ nhắc, bấm lần nữa mới hết lượt. **Đánh lại** trên thanh trên (có hỏi lại). Bắt đầu ván mới khi đang có ván dở: game hỏi trước (chỉ có một chỗ lưu).
- Phím: `Space`/`Enter` hành động mặc định · `Tab` lính kế chưa đi · `E` hết lượt · `H` gợi ý · `B` đổi chế độ cảnh đánh · `Esc`/chuột phải hủy.
- Bấm thành trống của ta để mua lính (popup cạnh thành). Nút **Hết lượt** nằm ở góc dưới bên phải bàn cờ, sáng nhịp khi mọi quân đã ra lệnh.
- **ⓘ** ở góc mỗi quân: thẻ thông tin (chỉ số, buff đang có, đặc tính, cách dùng). Quân đứng cạnh Trống trận / tướng hào quang có chấm ⚔ cam (+10 công), cạnh tướng che chắn có chấm 🛡 xanh (+10 thủ); rê chuột lên nguồn buff để thấy 4 ô nó phủ. Lần đầu gặp một loại quân, game dừng lại giới thiệu nó.

Cờ debug (sau `--`, hoặc trên web là query `?mission=m05&bot`): `mission=m03` vào thẳng màn · `bot` AI chơi phe ta · `speed=3` · `fresh` bỏ ván đang lưu · `screen=title|campaign[:c2]|briefing:m05|skirmish|codex` · `shots=res://shots/x shot_every=2 tag=x` chụp màn hình · `quit_at=60` · `bot` tắt cảnh giao chiến cho nhanh, thêm `battle` để bật · `nobattle` luôn tắt.

## Kiểm tra
Mọi lệnh Godot nên chạy qua `tools/run_guarded.ps1` (macOS / Linux: `MAX_SEC=120 tools/run_guarded.sh out.log -- --headless --path . -s sim/tests.gd`) (kill khi vượt RAM / thời gian; một vòng lặp vẽ từng ngốn 60 GB làm treo máy):
```
powershell -File tools/run_guarded.ps1 -Log t.log -GArgs "--headless --path . -s sim/tests.gd"   # 51 test: luật, 16 màn hợp lệ (kiểu thắng, đợt quân, thứ tự), tướng tới được mục tiêu, chương, lưu ván, 4 ván vàng chương 1
powershell -File tools/run_guarded.ps1 -Log c.log -GArgs "--headless --path . -s sim/click_driver.gd -- mission=m02 fresh nointro"  # ~38 bước bấm chuột qua UI thật (popup lệnh, ⓘ, giới thiệu quân, cảnh giao chiến 3 chế độ, thắng rồi thoát ngay vẫn giữ kết quả); dùng hồ sơ lưu riêng `driver`, không đụng ván thật
bash tools/sim_many.sh "m09 m10 m11" 12 4                                                        # cân bằng: AI chơi cả hai phe
python tools/web_smoke.py --query "?mission=m05&bot&speed=3" --wait 70                           # chạy bản web trong Edge headless, in console + chụp
powershell -File tools/run_guarded.ps1 -Log p.log -GArgs "--headless --path . -s sim/path_check.gd"   # mọi đường đi vẽ trên bàn cờ liền mạch (2365 đường)
powershell -File tools/run_guarded.ps1 -Log g.log -GArgs "--headless --path . -s sim/mapgen.gd -- only=m03"  # sinh lại bố cục bản đồ (in ra, không ghi file)
```
Godot có cửa sổ (chụp màn hình) cần màn hình đang bật; khi máy vắng người, chỉ chạy headless.

## Cân bằng (sim AI-vs-AI, 12 ván/màn, bản đồ mới 2026-11-05)
AI chơi cả hai phe; "Ta thắng" = số ván phe ta thắng; "hòa" = hết 60 lượt chưa phân thắng bại.

| Màn | Kiểu | Ta thắng | Trung vị lượt | | Màn | Kiểu | Ta thắng | Trung vị lượt |
|---|---|---|---|---|---|---|---|---|
| m01 Lời Thề Hát Môn | diệt hết | 11/12 | 10 | | m09 Tin Dữ Hợp Phố | giữ vững | 12/12 | 10 |
| m02 Về Lại Mê Linh | chiếm thành | 10/12 | 30 | | m10 Sóng An Biên | hạ tướng | 11/12 | 27 |
| m03 Giữ Làng Hạ Lôi | giữ vững | 12/12 | 11 | | m11 Bát Nàn Giữ Ải | chiếm thành | 12/12 | 15 |
| m04 Phá Đồn Cổ Loa | hạ tướng | 11/12 | 15 | | m12 Trận Lãng Bạc | chiếm thành | 10/12 | 23 |
| m05 Đêm Hồ Tây | chiếm thành | 11/12 | 19 | | m13 Địu Con Phá Vây | tới đích | 9/12 | 10 |
| m06 Kỵ Binh Bãi Sông | chiếm thành | 5/12 (4 hòa) | 47 | | m14 Rút Về Cấm Khê | tới đích | 10/12 | 5 |
| m07 Vây Thành Long Biên | chiếm thành | 10/12 | 41 | | m15 Thành Cấm Khê | giữ vững | 10/12 | 11 |
| m08 Trị Sở Luy Lâu | chiếm thành | 6/12 (4 hòa) | 51 | | m16 Đêm Sông Hát | giữ vững | 7/12 | 9 |

Màn đầu chương dễ, giữa chương ~80–90%, trận cuối chương ~50–60%. Rừng núi dày hơn làm các trận chiếm thành lớn (m06, m08) dài hơn trước. m04 đã chỉnh (thêm vàng + 1 bộ binh ta, bớt voi địch) vì Tô Định đi được trên sông; m16 bớt vàng ta và thêm quân địch lượt 1.

## Khớp với bản JS (luật)
Luật (`scripts/core/game.gd`) và AI (`scripts/core/ai.gd`) port 1-1 từ `src/core/engine.js` / `ai.js`: cùng thứ tự duyệt (Dijkstra lấy ô rẻ nhất, chèn trước thắng khi hòa = sort ổn định của V8), cùng biểu thức số thực, cùng RNG LCG tính bằng double. `sim/trace.gd` in cho mỗi ván hash của mọi nước AI + vị trí/máu/KN cuối + vàng; `sim/trace_js.cjs` in cùng định dạng từ bản JS.

| Đo 2026-11-04 (seed = 1000 + 7919·ván) | Ván giống hệt |
|---|---|
| Chiến dịch m01–m08 (AI cả hai phe) | 160/160 |
| Đấu tự do thường / dễ | 12/12 · 12/12 |
| Bot ngẫu nhiên vs AI | 10/10 |
| Sau khi thêm chương 2–3 (luật `reach`, tướng mới): m01, m04, m07 | 60/60 |

Từ khi đổi bản đồ và chỉ huy, `trace.gd` chạy trên **bản sao đóng băng** của nội dung chương 1 lúc port (`sim/legacy/`: 8 màn + bản đồ đấu tự do), còn luật và AI là code hiện tại. Nhờ vậy vẫn kiểm được luật khớp bản JS dù nội dung đã khác: m01, m04, đấu tự do 52/52 giống hệt (2026-11-05). Đo lại: `node sim/trace_js.cjs ../hon-song-nui > js.txt`, `godot --headless --path . -s sim/trace.gd -- only=m01 > gd.txt`, `diff`.

Từ 2026-11-05: chỉ số chương 1 cũng đóng băng (`sim/legacy/rules.gd`, nạp qua `Game.use_tables`), nên đổi cân bằng trong `rules.gd` không làm hỏng phép đo. Kết quả 194 ván của bản code đã khớp JS được lưu ở `sim/legacy/golden.txt`; `sim/tests.gd` chơi lại 4 ván trong đó mỗi lần chạy, còn kiểm đủ: `godot --headless --path . -s sim/trace.gd > gd.txt; diff <(sort sim/legacy/golden.txt) <(sort gd.txt)` (máy không cần bản JS). Luật mới chỉ bật ở `rules.gd` hiện tại (vd `raiseCap`: gọi hồn không vượt trần quân) không chạm bản đóng băng.

AI một nước (GDScript, máy bàn Mac, trung bình): m01 ~5 ms, m08 ~22 ms, m12 ~30 ms (trước tối ưu 9 / 51 / 39 ms). Bản đồ khoảng cách nhớ theo lượt + dùng chung vùng đi của địch; nước đi không đổi (194/194 ván vàng giống hệt).

## Thay nội dung (không đụng code)
| Muốn đổi | Sửa ở |
|---|---|
| Tên, icon, màu phe, chữ giao diện | `content/theme.gd` |
| Chương (tiêu đề, năm, bản đồ sơ đồ, lời kết chương) | `content/chapters/cN.gd` |
| Lối chơi từng loại quân (thẻ giới thiệu, ⓘ) | `content/guide.gd` (đặc tính tự sinh từ chỉ số) |
| Màn (1 file / màn, tự gom theo `order`, gắn `chapter`) | `content/campaign/mNN.gd`, định dạng ở `docs/content.md` |
| Bản đồ đấu tự do | `content/skirmish_maps.gd` |
| Chỉ số lính, tướng, địa hình, kinh tế | `scripts/core/rules.gd` |
| Ảnh thật thay emoji / hình vẽ | thêm `"img": "res://…png"` vào lính / tướng / địa hình trong theme |
| Bộ hình chibi (mặc định) | `assets/units/styles/chibi/<loại>_<p\|e>.svg` + `assets/terrain/chibi/*.svg` (SVG thô, importer "keep", vẽ lại đúng cỡ màn hình lúc chạy). Cờ `figstyle=off` = bóng người + địa hình vẽ code cũ |
Thêm emoji mới vào chữ: chạy `python tools/build_fonts.py <thư mục có NotoSansSymbols2.ttf>` để tải PNG Noto tương ứng.

## Kiến trúc
- `scripts/core`: luật thuần, không Node. Trạng thái ván là Dictionary (ô = `Vector2i`), lưu bằng `var_to_str` vào `user://` (web: IndexedDB). `content.gd` gom chương + màn và trả theme đã gộp theo chương đang mở.
- `scripts/ui`: `main.gd` (vỏ + cờ debug), `menus.gd` + `menu_bg.gd` + `camp_map.gd` (tiêu đề, tab chương + bản đồ, giới thiệu màn, đấu tự do, Sách lính), `battle_view.gd` (cảnh giao chiến, lớp CanvasLayer trên cùng), `game_screen.gd` (thanh trên, mẹo, popup lệnh cạnh ô, nút Hết lượt cạnh bàn cờ, giới thiệu quân mới, ⓘ, phát lại sự kiện, lượt địch, gợi ý, kết thúc), `board.gd` (bàn 2D: địa hình bake 1 texture, quân vẽ từ atlas, FX, đêm, nhãn dự báo), `board3d.gd` + `kit.gd` + `pieces.gd` (sa bàn 3D thử nghiệm: cùng giao diện với `board.gd`, mô hình low-poly dựng bằng code, máy quay sà xuống khi giao chiến), `fx.gd`, `token.gd`, `style.gd`, `draw.gd`, `audio.gd` (âm thanh dựng sẵn thành wav trong `assets/sfx`, tạo lại: `godot --headless --path . -s tools/bake_sfx.gd`; + nhạc ngũ cung), `emoji_font.gd`, `store.gd`.
- `shaders/`: nền menu, logo ánh kim, vignette, màn đêm, mặt nước 3D.
- Font: Be Vietnam Pro + Alegreya SC (OFL), subset Noto Sans Symbols 2 (OFL), emoji Noto (Apache 2.0) đóng thành font bitmap lúc khởi động. Không dùng font hệ thống, nên web và máy bàn hiển thị như nhau.

## Giới hạn đã biết
- Bố cục ngang (khung gốc 1280x720). Màn nhỏ: giao diện không thu dưới 0.8 lần, trang menu cuộn được (điện thoại nằm ngang đọc được). Điện thoại dọc: màn "Xoay ngang màn hình để chơi".
- Âm thanh là wav dựng sẵn (22 kHz); trên web chỉ phát sau cú bấm đầu tiên (quy định trình duyệt).
- Bàn 3D: mới thử trên m01 (máy Mac), chưa thử bản web.
- Sử tích trong game theo truyền thuyết và sách sử phổ thông, có lược bớt cho hợp lối chơi.

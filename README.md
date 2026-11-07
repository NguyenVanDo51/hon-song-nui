# Công Thành Chiến — bản Godot

Tên cũ: Hồn Sông Núi (repo / thư mục `hon-song-nui`, save cũ ở `~/Library/Application Support/Godot/app_userdata/Hồn Sông Núi/`, đã chép sang thư mục tên mới).

Chiến thuật theo lượt trên lưới ô, lấy cảm hứng từ các cuộc khởi nghĩa của phụ nữ Việt thời Bắc thuộc. Godot 4.7, GDScript, chạy trên web và máy bàn.
Viết lại từ `../hon-song-nui` (JS + canvas, JS commit `3e888f1`), rồi mở rộng thành hai chương.

| Chương | Năm | Màn | Chỉ huy ta | Chỉ huy địch |
|---|---|---|---|---|
| 1 · Khởi nghĩa Hai Bà Trưng | 40 | m01–m08 | Trưng Trắc | Tô Định |
| 2 · Chống Mã Viện | 42–43 | m09–m16 | Trưng Trắc | Mã Viện |

Như các game chiến thuật lưới ô kinh điển: **hai phe dùng chung một bộ lính** (cùng tên, cùng icon, chỉ khác màu); chỉ huy ta suốt game là Trưng Trắc; chỉ huy địch mỗi chương một tên nhưng cùng hình, cùng chỉ số. Các nhân vật khác (Trưng Nhị, Lê Chân, Thánh Thiên, Bát Nàn, Phùng Thị Chính, Đoàn Chí...) chỉ xuất hiện trong lời thoại.

Kiểu màn: chiếm thành · diệt hết địch · hạ tướng địch · giữ vững N lượt · **đưa tướng tới ô đích** (chương 2). Chương sau mở khi thắng hết chương trước. Thêm chế độ đấu tự do (3 chiến trường), **1 đấu 1** (hai người chung máy, đổi tay mỗi lượt, hoặc đấu máy Dễ / Thường / Khó; `docs/1v1.md`) và Sách lính. Luật: `docs/spec.md`.

**Bản đồ** bố trí theo lối bản đồ chiến thuật cổ điển (đối chiếu bản làm lại Ancient Empires Reloaded): **đường mòn** nối thành với làng thành một mạng liền, qua sông bằng cầu; rừng / đồi / núi gom thành **khối** (núi ở lõi, đồi quanh, rừng ở mép) chiếm ~30% đất, chừa một vòng trống quanh thành. Đường mòn chỉ khác đồng lúa ở hình vẽ (thủ 0, tốn 1). Bản đồ sinh lại bằng `sim/mapgen.gd` từ bố cục tay (giữ thành, làng, sông, cầu, chỗ quân đứng / tiếp viện / ô đích).

## Chơi
**Chơi ngay: https://hon-song-nui.vercel.app**

- **Cập nhật bản web trên Vercel** (scope cá nhân `nguyenvando51s-projects`, project `hon-song-nui`): `powershell -File tools/export_web.ps1`, chép `build/web` sang một thư mục tên `hon-song-nui`, rồi trong thư mục đó chạy `npx vercel deploy --prod --yes --scope nguyenvando51s-projects`. Kiểm tra: `python tools/web_smoke.py --url https://hon-song-nui.vercel.app/ --query "?mission=m05&bot&speed=3" --wait 60 --idb`.
- **Web:** mở bản dựng `build/web/index.html` qua một web server (không mở thẳng file). Phát hành: `powershell -File tools/export_web.ps1` -> `build/web/` + `build/hon-song-nui-web.zip` (~11 MB). itch.io: tạo project kiểu HTML, tải zip lên, bật "SharedArrayBuffer" không cần (bản dựng đơn luồng). GitHub Pages / Netlify: đẩy nguyên thư mục `build/web`.
- **iOS / TestFlight** (macOS, cần Xcode + Apple ID đăng nhập trong Xcode, team `764ACT5Z4W`, bundle `com.nguyenvando.congthanhchien`): preset `iOS` xuất project Xcode -> `godot --headless --path . --export-release iOS build/ios/CongThanhChien.xcodeproj`, rồi archive + upload bằng `xcodebuild` (mỗi lần upload tăng `application/version` trong `export_presets.cfg`). Icon: `godot --headless --path . -s tools/make_ios_icon.gd` -> `assets/ios/icon_1024.png` (RGB, không alpha). Chỉ xoay ngang (`window/handheld/orientation=4`).
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
- **Đánh trên bàn cờ**: mỗi đòn, máy quay sà vào hai quân, hoạt cảnh đòn đánh (rig) + đánh trả, rồi lùi ra. Theo tốc độ x1/x2/x3.
- **Lượt địch**: giữ `Space` hoặc chuột để chạy x4; nút **⏩ Tua lượt địch** tua hết lượt đó (bỏ cận cảnh).
- **Giữ chỗ**: chọn lính rồi `Space` = lính đứng yên, xong lượt (không đi). **Hết lượt**: bấm 1 lần là hết lượt (không hỏi lại). **Đánh lại** trên thanh trên (có hỏi lại). Bắt đầu ván mới khi đang có ván dở: game hỏi trước (chỉ có một chỗ lưu).
- **Vào màn**: bấm màn trên bản đồ chiến dịch -> vào thẳng bàn cờ: thẻ tên màn, rồi thoại từng người ở dải dưới (sử tích -> lời nhân vật -> mục tiêu). Chạm / `Space` = hết câu / câu sau, giữ hoặc **»» Tua** = chạy nhanh, **Bỏ qua** / `Esc` = vào trận. Ván đang dở mở lại không chiếu lại thoại.
- Phím: `Space`/`Enter` hành động mặc định · `Tab` lính kế chưa đi · `E` hết lượt · `H` gợi ý · `Esc`/chuột phải hủy.
- Bấm thành trống của ta để mua lính (popup cạnh thành). Nút **Hết lượt** nằm ở góc dưới bên phải bàn cờ, sáng nhịp khi mọi quân đã ra lệnh.
- **ⓘ** ở góc mỗi quân: thẻ thông tin (chỉ số, buff đang có, đặc tính, cách dùng). Quân đứng cạnh Trống trận / tướng hào quang có chấm ⚔ cam (+10 công), cạnh tướng che chắn có chấm 🛡 xanh (+10 thủ); rê chuột lên nguồn buff để thấy 4 ô nó phủ. Lần đầu gặp một loại quân, game dừng lại giới thiệu nó.

Cờ debug (sau `--`, hoặc trên web là query `?mission=m05&bot`): `mission=m03` vào thẳng màn (thêm `story` = có thoại mở màn) · `bot` AI chơi phe ta · `speed=3` · `fresh` bỏ ván đang lưu · `screen=title|campaign[:c2]|skirmish|duel|codex` · `shots=res://shots/x shot_every=2 tag=x` chụp màn hình · `quit_at=60` · `bot` tắt cận cảnh đánh cho nhanh, thêm `zoom` để bật · `nozoom` luôn tắt.

## Kiểm tra
Mọi lệnh Godot nên chạy qua `tools/run_guarded.ps1` (macOS / Linux: `MAX_SEC=120 tools/run_guarded.sh out.log -- --headless --path . -s sim/tests.gd`) (kill khi vượt RAM / thời gian; một vòng lặp vẽ từng ngốn 60 GB làm treo máy):
```
powershell -File tools/run_guarded.ps1 -Log t.log -GArgs "--headless --path . -s sim/tests.gd"   # 81 test: luật, 16 màn hợp lệ (kiểu thắng, đợt quân, thứ tự), tướng tới được mục tiêu, chương, lưu ván, 4 ván vàng chương 1
powershell -File tools/run_guarded.ps1 -Log c.log -GArgs "--headless --path . -s sim/click_driver.gd -- mission=m02 fresh nointro"  # ~55 bước bấm chuột qua UI thật (popup lệnh, ⓘ, giới thiệu quân, cảnh giao chiến 3 chế độ, thắng rồi thoát ngay vẫn giữ kết quả); dùng hồ sơ lưu riêng `driver`, không đụng ván thật
bash tools/sim_many.sh "m09 m10 m11" 12 4                                                        # cân bằng: AI chơi cả hai phe
python tools/web_smoke.py --query "?mission=m05&bot&speed=3" --wait 70                           # chạy bản web trong Edge headless, in console + chụp
powershell -File tools/run_guarded.ps1 -Log p.log -GArgs "--headless --path . -s sim/path_check.gd"   # mọi đường đi vẽ trên bàn cờ liền mạch (2365 đường)
powershell -File tools/run_guarded.ps1 -Log g.log -GArgs "--headless --path . -s sim/mapgen.gd -- only=m03"  # sinh lại bố cục bản đồ (in ra, không ghi file)
```
Godot có cửa sổ (chụp màn hình) cần màn hình đang bật; khi máy vắng người, chỉ chạy headless.

### Lint
- Cài 1 lần: `pipx install "gdtoolkit==4.*"` (macOS: `brew install pipx` trước), rồi `tools/install_hooks.sh` -> git pre-commit chạy `tools/lint.sh --staged` (bỏ qua 1 lần: `git commit --no-verify`).
- `tools/lint.sh` (cả repo, ~4 s) = `gdlint` theo `gdlintrc` + Godot parse mọi script với cảnh báo = lỗi (`project.godot` [debug]: unused_*, unreachable_*, standalone_*, unassigned_*, narrowing_conversion, redundant_await, confusable_identifier, static_called_on_instance) qua `sim/check_scripts.gd`. Kiểu chặt toàn repo (2026-11-06): untyped_declaration, unsafe_* , integer_division, incompatible_ternary, shadowed_* cũng = lỗi -> đọc field Dictionary vào biến có kiểu (`var hp: int = u.hp`), không `as` từ Variant.
- `tools/warn_count.sh [-v] [thư mục]`: đếm cảnh báo chưa bật (override.cfg tạm) — dùng trước khi bật thêm một cảnh báo.
- Cố ý tắt: `return_value_discarded` (267 chỗ, >90% chủ ý: append / do_action / connect / end_turn / tween / erase; lỗi IO thì kiểm tay), `inferred_declaration` (`:=` là chuẩn).
- `run_guarded.sh/.ps1` trả exit 1 nếu log có `SCRIPT ERROR` (test crash giữa chừng không còn tính là qua).
- Format: [gdscript-formatter](https://github.com/GDQuest/GDScript-formatter) 0.27 (GDQuest, binary ở `~/.local/bin`); `tools/lint.sh` chạy `--check`. Sửa: `gdscript-formatter --max-line-length 150 --blank-lines-around-definitions 1 <files>`. Lỗi tool: comment cuối lambda nhiều dòng làm đối số -> mỗi lần chạy thêm 1 dấu `,` vào comment => đặt comment lên dòng trên. Không dùng `gdformat` (gdtoolkit 4.5.0 hỏng lambda nhiều dòng).
- `gdlintrc`: dòng ≤ 150, class-definitions-order bật; còn nới `max-file-lines` 2650 (game_screen ~2610 sau format, tách = E5).

## Cân bằng (sim AI-vs-AI, 12 ván/màn (24 nếu ghi /24), 2026-11-06, luật AE2 + AI `fe83a5d` + nhịp ra quân mới)
AI chơi cả hai phe; "Ta thắng" = số ván phe ta thắng; "hòa" = hết 60 lượt chưa phân thắng bại. Mới = loại quân ra mắt (thấy → cầm → mua, xem `docs/content.md` mục "Nhịp ra quân mới").

| Màn | Kiểu | Mới | Ta thắng | Trung vị lượt | | Màn | Kiểu | Mới | Ta thắng | Trung vị lượt |
|---|---|---|---|---|---|---|---|---|---|---|
| m01 Lời Thề Hát Môn | diệt hết | bộ binh, tướng | 12/12 | 6 | | m09 Tin Dữ Hợp Phố | giữ vững | thủy binh (địch) | 12/12 | 10 |
| m02 Về Lại Mê Linh | chiếm thành | nỏ thủ | 16/24 | 11 | | m10 Sóng An Biên | hạ tướng | thủy binh (ta) | 11/12 | 9 |
| m03 Giữ Làng Hạ Lôi | giữ vững | trống (đặt sẵn) | 12/12 | 10 | | m11 Bát Nàn Giữ Ải | chiếm thành | sói (địch) | 11/12 | 12 |
| m04 Phá Đồn Cổ Loa | hạ tướng | voi (địch) | 9/12 | 9 | | m12 Trận Lãng Bạc | chiếm thành | sói (ta) | 21/24 | 18 |
| m05 Đêm Hồ Tây | chiếm thành | (đêm) | 12/12 | 12 | | m13 Địu Con Phá Vây | tới đích | thầy mo (đặt sẵn) | 20/24 | 6 |
| m06 Trận Bãi Sông | hạ tướng | — | 12/12 | 7 | | m14 Rút Về Cấm Khê | tới đích | — | 12/12 | 8 |
| m07 Vây Thành Long Biên | chiếm thành | máy bắn đá | 10/12 | 13 | | m15 Thành Cấm Khê | giữ vững | rồng (1 con) | 10/12 | 11 |
| m08 Trị Sở Luy Lâu | chiếm thành | — | 14/24 (4 hòa) | 21 | | m16 Đêm Sông Hát | giữ vững | — | 14/24 | 9 |

- Màn ra mắt quân ≥ ~75%; trận cuối chương ~55–60% (m08, m16).
- `fe83a5d` (lính máu < 50 về ô hồi máu, không đứng ỳ ở góc) so với ngay trước nó (`5f45645`, cùng seed): mọi màn lệch ≤ 3 ván (24 ván: m08 16→14 + hòa 1→4, m12 18→21, m13 23→20, m16 16→14, m02 15→16).
- m14 hết lệch: 12/12 (bảng `31a006e`: 3/12; ở `5f45645` đã 10/12).
- Bảng cũ (2026-11-05) đo trước khi đưa luật về AE2; số trước đổi (AI cũ): m07 7/12, m08 7/12, m13 5/12, m15 4/12.

## Luật = AE2 (2026-11-06)
Luật đã đưa về giống Ancient Empires II theo `docs/review/rules_compare.html` (số liệu từ dữ liệu gốc + mã dịch ngược bản mod; điểm chưa xác nhận ghi trong `docs/spec.md`). Bản port JS cũ + phép đo khớp JS (`sim/legacy/`, `trace_js.cjs`) đã bỏ.

### Logic game gốc ở đâu
Không có mã nguồn gốc công khai; chỉ có jar gốc + bản mod dịch ngược.
- **Jar gốc** (Macrospace 2005, v1.0.2): https://github.com/ancient-empires/games-download/blob/main/Java/AE2-en.jar — tên lớp bị làm rối (`c` = Unit, `i` = MainDisplayable, `e` = Renderer); muốn đọc phải disassemble bytecode + giải nén `1.pak` (`units.bin`, `tiles0.prop`). Cách làm + kết quả: `docs/review/ae2_research.md`.
- **Mã Java đọc được** (bản mod RM 2.5, decompile; cùng cấu trúc + hằng số với gốc, luật mod có lệch): https://github.com/ProjectD8/Ancient-Empires-II-RM — logic chính ở `src/aeii/MainDisplayable.java`, dữ liệu ở `res/res/` (`*.unit`, `tiles0.prop`).
- **Chữ trong game gốc**: https://github.com/ancient-empires/Java-tools/blob/main/AE2lang/data/AE2/lang.txt
- **Đối chiếu từng luật vs code mình** (link thẳng tới dòng Java): `docs/review/rules_compare.html`; điểm còn theo bản mod: `docs/spec.md` mục cuối.
- Ưu tiên: bytecode jar gốc > mã RM > wiki (fandom `ancient-empires.fandom.com`, chỉ tham khảo).

Hồi quy: `sim/trace.gd` chơi AI-vs-AI có seed trên luật hiện tại cho mọi màn + bản đồ đấu tự do, in 1 dòng/ván (hash mọi nước + kết quả). `sim/golden.txt` = kết quả đã chốt; `sim/tests.gd` chơi lại 4 ván mỗi lần chạy. Đổi luật / AI / bản đồ có chủ đích thì tạo lại: `godot --headless --path . -s sim/trace.gd > sim/golden.txt`.

AI một nước (GDScript, Mac Apple Silicon, `sim/probes/ai_time.gd` = 4 ván seed vàng, đo 2026-11-06 ở `fe83a5d`, trung bình / tệ nhất): m01 1.4 / 3.7 ms, m08 3.4 / 15 ms, m12 3.7 / 16 ms (ngay trước, cùng máy: 1.2 / 3.6, 3.3 / 14, 3.6 / 14.5). Bản đồ khoảng cách nhớ theo lượt + dùng chung vùng đi của địch.

Tham số AI (`AI.DEFAULT`, ghi đè theo phe `s.aiParams`), tự đấu để tune (`sim/tune.gd`, `tools/tune.sh`), phác thảo độ khó Dễ / Thường / Khó + bảng thắng thua: `docs/ai.md`.

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
- `scripts/core`: luật thuần, không Node. Trạng thái ván là Dictionary (ô = `Vector2i`), lưu bằng `var_to_str` vào `user://` (web: IndexedDB). `content.gd` gom chương + màn và trả theme đã gộp theo chương đang mở. `rules.gd` = số liệu + cờ (quân, công trình), `objectives.gd` = kiểu mục tiêu màn; `game.gd` / `ai.gd` không so tên quân / ký tự ô.
- `scripts/ui`: `main.gd` (vỏ + cờ debug), `menus.gd` + `menu_bg.gd` + `camp_map.gd` (tiêu đề, tab chương + bản đồ, đấu tự do, Sách lính), `story_overlay.gd` (thẻ tên màn + thoại mở màn từng người trên bản đồ), `game_screen.gd` (trạng thái ván, chọn quân + click, gợi ý) + phần tách ra: `game_hud.gd` (HUD nổi, ⚙, thẻ góc, Hết lượt), `info_panel.gd` (popup lệnh / ⓘ / mua cạnh ô), `event_player.gd` (phát lại sự kiện, đếm vàng / máu), `turn_driver.gd` (lượt, lượt địch, bot, trao máy, kết thúc), `game_cards.gd` (giới thiệu quân mới, thẻ kết thúc), `board.gd` (bàn 2D: địa hình bake 1 texture, quân vẽ từ atlas, FX, đêm, nhãn dự báo), `board3d.gd` + `kit.gd` + `pieces.gd` (sa bàn 3D thử nghiệm: cùng giao diện với `board.gd`, mô hình low-poly dựng bằng code, máy quay sà xuống khi giao chiến), `fx.gd`, `token.gd`, `style.gd`, `draw.gd`, `audio.gd` (âm thanh dựng sẵn thành wav trong `assets/sfx`, tạo lại: `godot --headless --path . -s tools/bake_sfx.gd`; + nhạc ngũ cung), `emoji_font.gd`, `store.gd`.
- `shaders/`: nền menu, logo ánh kim, vignette, màn đêm, mặt nước 3D.
- Font: Be Vietnam Pro + Alegreya SC (OFL), subset Noto Sans Symbols 2 (OFL), emoji Noto (Apache 2.0) đóng thành font bitmap lúc khởi động. Không dùng font hệ thống, nên web và máy bàn hiển thị như nhau.

## Giới hạn đã biết
- Bố cục ngang (khung gốc 1280x720). Màn nhỏ: giao diện không thu dưới 0.8 lần, trang menu cuộn được (điện thoại nằm ngang đọc được). Điện thoại dọc: màn "Xoay ngang màn hình để chơi".
- Âm thanh là wav dựng sẵn (22 kHz); trên web chỉ phát sau cú bấm đầu tiên (quy định trình duyệt).
- Bàn 3D: mới thử trên m01 (máy Mac), chưa thử bản web.
- Sử tích trong game theo truyền thuyết và sách sử phổ thông, có lược bớt cho hợp lối chơi.

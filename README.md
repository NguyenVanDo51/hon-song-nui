# Công Thành Chiến — bản Godot

Tên cũ: Hồn Sông Núi (repo / thư mục `hon-song-nui`, save cũ ở `~/Library/Application Support/Godot/app_userdata/Hồn Sông Núi/`, đã chép sang thư mục tên mới).

Chiến thuật theo lượt trên lưới ô, lấy cảm hứng từ các cuộc khởi nghĩa của phụ nữ Việt thời Bắc thuộc. Godot 4.7, GDScript, chạy trên web và máy bàn.
Viết lại từ `../hon-song-nui` (JS + canvas, JS commit `3e888f1`). Chế độ chính: **Thử thách** = chuỗi level đánh số, thắng level này mở level sau, nhãn Dễ / Trung bình / Khó, 3 sao mỗi level (không cốt truyện, không chương; thiết kế `docs/superpowers/specs/2026-11-07-levels-design.md`).

Như các game chiến thuật lưới ô kinh điển: **hai phe dùng chung một bộ lính** (cùng tên, cùng icon, chỉ khác màu); một chỉ huy mỗi phe (Anh hùng / Tướng giặc), cùng chỉ số. Không có cốt truyện: chỉ chơi cờ.

Kiểu màn: chiếm thành · diệt hết địch · hạ tướng địch · giữ vững N lượt · **đưa tướng tới ô đích**. Thêm chế độ đấu tự do (3 chiến trường), **1 đấu 1** (hai người chung máy, đổi tay mỗi lượt, hoặc đấu máy Dễ / Trung bình / Khó / Siêu khó; `docs/1v1.md`) và Sách lính. Luật: `docs/spec.md`.

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
- Bấm lính để thấy ô đi được. Bấm **quân địch**: ô trắng = nó đi tới, ô đỏ + viền đỏ = ô nó đánh tới được lượt sau; quân ta trong vùng có dấu **!** đỏ.
- **Sao màn**: thắng · tướng không ngã · mốc riêng (thắng trong N lượt / mất ≤ K lính). Hiện ở thẻ kết thúc + lưới Thử thách (giữ số sao cao nhất). **Rê chuột lên kẻ địch**: bàn cờ vẽ đường tới ô đánh tốt nhất và nhãn "⚔ gây · ↩ nhận"; **bấm một lần là đánh**. (Màn hình cảm ứng: chạm lần 1 ngắm, lần 2 đánh.)
- Bấm ô xanh để đi tới; bấm **lại chính ô đó** = hành động mặc định (chiếm nếu được, không thì chờ). Không có "đi tại chỗ": bấm lại lính đang đứng là bỏ chọn (trừ khi chiếm / cứu thương được ngay tại đó). Không có bảng bên: mọi lệnh (⚔ Đánh / 🏠 Chiếm / 🩹 / Chờ / Hủy), dự báo trận, mua lính, thông tin lính và ô đất hiện trong một popup ngay cạnh ô trên bàn cờ, tự né không che quân.
- **Đánh trên bàn cờ**: mỗi đòn, máy quay sà vào hai quân, hoạt cảnh đòn đánh (rig) + đánh trả, rồi lùi ra. Theo tốc độ x1/x2/x3.
- **Lượt địch**: giữ `Space` hoặc chuột để chạy x4; nút **⏩ Tua lượt địch** tua hết lượt đó (bỏ cận cảnh).
- **Giữ chỗ**: chọn lính rồi `Space` = lính đứng yên, xong lượt (không đi). **Hết lượt**: bấm 1 lần là hết lượt (không hỏi lại). **Đánh lại** trên thanh trên (có hỏi lại). Bắt đầu ván mới khi đang có ván dở: game hỏi trước (chỉ có một chỗ lưu).
- **Vào màn**: bấm màn -> vào thẳng bàn cờ (thẻ giới thiệu quân mới nếu có).
- Phím: `Space`/`Enter` hành động mặc định · `Tab` lính kế chưa đi · `E` hết lượt · `H` gợi ý · `Esc`/chuột phải hủy.
- Bấm thành trống của ta để mua lính (popup cạnh thành). Nút **Hết lượt** nằm ở góc dưới bên phải bàn cờ, sáng nhịp khi mọi quân đã ra lệnh.
- **ⓘ** ở góc mỗi quân: thẻ thông tin (chỉ số, buff đang có, đặc tính, cách dùng). Quân đứng cạnh Trống trận / tướng hào quang có chấm ⚔ cam (+10 công), cạnh tướng che chắn có chấm 🛡 xanh (+10 thủ); rê chuột lên nguồn buff để thấy 4 ô nó phủ. Lần đầu gặp một loại quân, game dừng lại giới thiệu nó.

Cờ debug (sau `--`, hoặc trên web là query `?mission=m05&bot`): `mission=m03` vào thẳng màn · `bot` AI chơi phe ta · `speed=3` · `fresh` bỏ ván đang lưu · `screen=title|levels|skirmish|duel|codex` · `shots=res://shots/x shot_every=2 tag=x` chụp màn hình · `quit_at=60` · `crash_at=5` cố ý crash (thử log crash) · `bot` tắt cận cảnh đánh cho nhanh, thêm `zoom` để bật · `nozoom` luôn tắt.

## Kiểm tra
Mọi lệnh Godot nên chạy qua `tools/run_guarded.ps1` (macOS / Linux: `MAX_SEC=120 tools/run_guarded.sh out.log -- --headless --path . -s sim/tests.gd`) (kill khi vượt RAM / thời gian; một vòng lặp vẽ từng ngốn 60 GB làm treo máy):
```
powershell -File tools/run_guarded.ps1 -Log t.log -GArgs "--headless --path . -s sim/tests.gd"   # sim/tests.gd = runner, test theo mảng ở sim/tests/*.gd (test_base.gd = check / eq / run + helper); 150 test: luật, 16 màn hợp lệ (kiểu thắng, đợt quân, thứ tự), tướng tới được mục tiêu, chương, lưu ván, 4 ván vàng chương 1
powershell -File tools/run_guarded.ps1 -Log c.log -GArgs "--headless --path . -s sim/click_driver.gd -- mission=m02 fresh nointro"  # ~55 bước bấm chuột qua UI thật (popup lệnh, ⓘ, giới thiệu quân, cảnh giao chiến 3 chế độ, thắng rồi thoát ngay vẫn giữ kết quả); dùng hồ sơ lưu riêng `driver`, không đụng ván thật
bash tools/sim_many.sh "m09 m10 m11" 12 4                                                        # cân bằng: AI chơi cả hai phe
python tools/web_smoke.py --query "?mission=m05&bot&speed=3" --wait 70                           # chạy bản web trong Edge headless, in console + chụp
powershell -File tools/run_guarded.ps1 -Log p.log -GArgs "--headless --path . -s sim/path_check.gd"   # mọi đường đi vẽ trên bàn cờ liền mạch (2365 đường)
powershell -File tools/run_guarded.ps1 -Log g.log -GArgs "--headless --path . -s sim/mapgen.gd -- only=m03"  # sinh lại bố cục bản đồ (in ra, không ghi file)
godot --headless --path . -s sim/levelgen.gd -- recipe=g05 seeds=12 out=/tmp/lg                   # vẽ level mới từ công thức (sim/level_recipes.gd), in ứng viên tốt nhất trước
godot --headless --path . -s sim/levelgen.gd -- install=/tmp/lg/g05_s3.gd                         # chép ứng viên vào content/levels/ (rồi formatter + --import + tests)
```
Godot có cửa sổ (chụp màn hình) cần màn hình đang bật; khi máy vắng người, chỉ chạy headless.

### Log lỗi / crash
- Mỗi lần chơi thật (có cửa sổ; không headless / `-s sim/...` / web) -> 1 file `user://logs/game/<profile>/<YYYY-MM-DD_HH-MM-SS>.log` (`scripts/ui/game_log.gd`, `OS.add_logger`). Ghi + flush từng dòng -> crash vẫn giữ tới dòng cuối. Giữ 20 phiên + 10 file crash. Hồ sơ `profile=test` ghi riêng thư mục `test/`, không đẩy log của người chơi ra.
- Dòng: `HH:MM:SS +giây_từ_lúc_mở <loại> nội dung`. Loại: `E` lỗi engine / `push_error` · `W` cảnh báo / `push_warning` · `S` lỗi script · `H` shader · `X` printerr (gồm bản dump của crash handler: C++ + GDScript backtrace) · `P` print · `B` dấu vết (màn hình, bắt đầu ván + ctx, lượt / phe, từng lệnh / mua, kết thúc) · `==` mốc phiên (`session open`, `clean exit`, `paused`, `resumed`). Lỗi kèm `@ file:dòng hàm()` + GDScript backtrace (bản xuất release: backtrace rỗng trừ khi bật `debug/settings/gdscript/always_track_call_stacks`). Cùng một nội dung: 20 dòng đầu đủ, sau đó 1 dòng / 1000 lần kèm `(xN)`; file > 8 MB chỉ còn mốc + dấu vết.
- Crash: phiên trước không có `== clean exit` (thoát qua nút đóng cửa sổ / `get_tree().quit()` mới có) -> lần mở sau đổi tên thành `crash_<tên cũ>.log` + chép 15 dòng cuối vào log mới (`previous session CRASHED`). Tên giữ giờ mở phiên -> khớp với `~/Library/Logs/DiagnosticReports/Godot-*.ips`. Phiên kết thúc bằng `paused` (iOS cho app xuống nền rồi bị hệ thống tắt) không tính crash. Lỗi `Message queue out of memory` (ERR_PRINT) nằm trong log trước SIGBUS.
- Thử: `godot --path . -- profile=test crash_at=3` (cố ý `OS.crash`) rồi `godot --path . -- profile=test quit_at=4` -> `PROFILE=test tools/game_logs.sh crash`.
- Đọc (macOS): `tools/game_logs.sh` (= `ls`) · `last [N]` · `crash` · `errors [N]` · `grep MẪU` · `dir`; `PROFILE=test` cho hồ sơ test.
- Đường dẫn: macOS `~/Library/Application Support/Godot/app_userdata/Công Thành Chiến/logs/game/` · iOS `user://` = thư mục `Documents/` của app (chưa kiểm trên máy): Xcode > Devices and Simulators > app > Download Container (preset iOS chưa bật `user_data/accessible_from_files_app`) · web: không ghi file, xem console trình duyệt. `logs/godot.log` (log Godot mặc định) vẫn có nhưng bị sim / test chạy song song ghi đè -> dùng log phiên.

### Ghi trận / phân tích
- Mỗi ván chơi thật (có cửa sổ; cùng luật bật/tắt với log phiên: không headless / `-s sim/...` / web) -> `user://replays/<profile>/<YYYY-MM-DD_HH-MM-SS>_<kind>_<id>.replay` (`scripts/ui/match_rec.gd`, định dạng `scripts/core/replay.gd`). Mọi chế độ: thử thách, đấu tự do, 1 đấu 1 (cả 2 người). Giữ 200 ván mới nhất (file review đi kèm bị xoá theo).
- File = JSON 1 dòng / bản ghi, flush từng dòng: `head` (ctx, ai mỗi bên, cờ `bot`, cả state đầu dạng `var_to_str` -> nội dung đổi sau vẫn dựng lại được), `step` (`turn`, `side`, `who` human|ai, `step` = act / buy / unbuy / end, `h` = hash state sau bước), `resume`, `finish` (thắng / lý do / lượt). Chỉ ghi bước đã đổi `s` (hash trước ≠ sau): huỷ / bị luật từ chối không ghi.
- Đánh tiếp ván lưu: `ctx.replay` + `ctx.replayHash` (lưu cùng save, không đổi `STATE_V`) khớp state -> ghi tiếp cùng file (dòng `resume`); không khớp / file mất -> file mới (`head.prev` = file cũ).
- Phân tích (headless, ~0,3 s / lượt): `tools/review_match.sh [latest|all-new|<file>] [PROFILE=test] [LESSONS=off|<file>] [noscen]` (= `sim/review.gd`). Chạy lại các bước từ state đầu + kiểm hash (lệch -> báo bản ghi đầu tiên lệch, dừng ở đó). Mỗi nửa lượt: điểm `AIPlan.evaluate` (góc nhìn bên người), Khó v3 (`AI.PRESETS.hard`) lập kế hoạch từ cùng vị trí -> so 2-ply (nước đi + phản đòn greedy, roll giữa) -> lỗi người chơi xếp theo điểm mất + nhãn luật (`hero_killable`, `lone_unit_killed`, `missed_sure_kill`, `castle_lost` / `village_lost`, `gold_unspent`, `fed_promotion`, `no_retreat`, `missed_win`). Lượt bot: `bot_blunder` (kém planner), `bot_exploited` (người đáp hay hơn mô hình đối thủ của bot -> lưu `sim/scenarios/<replay-id>_t<lượt>.scenario` = state đầu lượt + bên + ghi chú, cho test hồi quy / luyện AI), số đo rủi ro `sim/tactics_lib.gd` (quân lẻ, tướng giết được, thành trống trong tầm chiếm; `_punished` = bị trả giá thật).
- Kết quả: `<id>.review.md` (gọn: kết quả, bước ngoặt + lượt + toạ độ (x,y) + nước tốt hơn, lỗi người chơi, điểm yếu bot, file scenario) + `<id>.review.json` (cùng dữ liệu) cạnh file `.replay`; `docs/review/match_lessons.md` thêm 1 mục / trận + mục "Mẫu lặp lại" dựng lại mỗi lần chạy. `all-new` = các replay chưa có `.review.json`.
- Thử (không đụng save thật): `godot --path . -- mission=g03 fresh bot profile=test speed=8 quit_at=450` rồi `tools/review_match.sh latest PROFILE=test LESSONS=off`.
- Đường dẫn macOS: `~/Library/Application Support/Godot/app_userdata/Công Thành Chiến/replays/`.
- **iPhone** (từ build 1.0.4, preset iOS `user_data/accessible_from_files_app`): app Tệp (Files) > Trên iPhone > Công Thành Chiến > `replays/default/` -> chọn file `.replay` (hoặc cả thư mục) -> AirDrop sang Mac -> `tools/review_match.sh ~/Downloads/<file hoặc thư mục>` (thư mục = phân tích mọi replay chưa có `.review.json`, kết quả ghi cạnh file). Head replay có `build` (= `application/config/version`, tăng cùng `application/version` iOS) + `platform`; build khác checkout -> review báo, `git checkout ios-<build>` rồi chạy lại (bảng luật lấy từ code hiện tại, TODO "Replay lưu cả state đầu"). Log phiên cũng ở `logs/game/`.

### Lint
- Cài 1 lần: `pipx install "gdtoolkit==4.*"` (macOS: `brew install pipx` trước), rồi `tools/install_hooks.sh` -> git pre-commit chạy `tools/lint.sh --staged` (bỏ qua 1 lần: `git commit --no-verify`).
- `tools/lint.sh` (cả repo, ~4 s) = `gdlint` theo `gdlintrc` + Godot parse mọi script với cảnh báo = lỗi (`project.godot` [debug]: unused_*, unreachable_*, standalone_*, unassigned_*, narrowing_conversion, redundant_await, confusable_identifier, static_called_on_instance) qua `sim/check_scripts.gd`. Kiểu chặt toàn repo (2026-11-06): untyped_declaration, unsafe_* , integer_division, incompatible_ternary, shadowed_* cũng = lỗi -> đọc field Dictionary vào biến có kiểu (`var hp: int = u.hp`), không `as` từ Variant.
- `tools/warn_count.sh [-v] [thư mục]`: đếm cảnh báo chưa bật (override.cfg tạm) — dùng trước khi bật thêm một cảnh báo.
- Cố ý tắt: `return_value_discarded` (267 chỗ, >90% chủ ý: append / do_action / connect / end_turn / tween / erase; lỗi IO thì kiểm tay), `inferred_declaration` (`:=` là chuẩn).
- `run_guarded.sh/.ps1` trả exit 1 nếu log có `SCRIPT ERROR` (test crash giữa chừng không còn tính là qua).
- Format: [gdscript-formatter](https://github.com/GDQuest/GDScript-formatter) 0.27 (GDQuest, binary ở `~/.local/bin`); `tools/lint.sh` chạy `--check`. Sửa: `gdscript-formatter --max-line-length 150 --blank-lines-around-definitions 1 <files>`. Lỗi tool: comment cuối lambda nhiều dòng làm đối số -> mỗi lần chạy thêm 1 dấu `,` vào comment => đặt comment lên dòng trên. Không dùng `gdformat` (gdtoolkit 4.5.0 hỏng lambda nhiều dòng).
- `gdlintrc`: dòng ≤ 150, class-definitions-order bật; `max-file-lines` 1000 (gdlint mặc định).

## Cân bằng (sim AI-vs-AI, 24 ván/màn, 2026-11-08, luật đi AE2 (mv − 1) + AI master `facd372`)
AI chơi cả hai phe; "Ta thắng" = số ván phe ta thắng / 24; "hòa" = hết 60 lượt. Mốc sao 3 = trung vị khi phe ta thắng (`docs/content.md` "Sao màn"). Mục tiêu khi cân lại: tỉ lệ thắng như trước khi đổi luật đi (bảng 12 ván ở `docs/TODO.md`) ± ~4/24; đã chỉnh: vàng p / e, m13 voi 50 máu, m15 giữ 11 lượt. m08 vẫn hòa nhiều (9/24 hết 60 lượt; trước đổi luật 3/12).

| Màn | Ta thắng | Hòa | Trung vị lượt | Sao 3 | | Màn | Ta thắng | Hòa | Trung vị lượt | Sao 3 |
|---|---|---|---|---|---|---|---|---|---|---|
| m01 Lời Thề Hát Môn | 24/24 | 0 | 8 | ≤ 8 lượt | | g03 Ngã Ba Sông | 10/24 | 0 | 22 | ≤ 23 lượt |
| m02 Về Lại Mê Linh | 19/24 | 0 | 12 | ≤ 11 lượt | | g04 Giữ Đồn | 24/24 | 0 | 10 | mất ≤ 7 |
| m03 Giữ Làng Hạ Lôi | 24/24 | 0 | 11 | mất ≤ 0 | | g05 Rừng Lim | 13/24 | 0 | 15 | ≤ 14 lượt |
| m04 Phá Đồn Cổ Loa | 19/24 | 0 | 12 | ≤ 11 lượt | | g06 Bãi Bồi | 8/24 | 0 | 14 | ≤ 27 lượt |
| m05 Đêm Hồ Tây | 23/24 | 0 | 12 | ≤ 12 lượt | | g07 Cửa Sông | 22/24 | 0 | 10 | ≤ 10 lượt |
| m06 Trận Bãi Sông | 23/24 | 0 | 12 | ≤ 11 lượt | | g08 Sông Đáy | 20/24 | 0 | 21 | ≤ 20 lượt |
| m07 Vây Thành Long Biên | 20/24 | 1 | 14 | ≤ 12 lượt | | g09 Làng Ven Đê | 22/24 | 0 | 10 | ≤ 10 lượt |
| m08 Trị Sở Luy Lâu | 15/24 | 9 | 20 | ≤ 17 lượt | | g10 Rừng Đêm | 24/24 | 0 | 12 | ≤ 12 lượt |
| m09 Tin Dữ Hợp Phố | 24/24 | 0 | 10 | mất ≤ 1 | | g11 Thành Đá | 7/24 | 0 | 19 | ≤ 16 lượt |
| m10 Sóng An Biên | 17/24 | 0 | 20 | ≤ 16 lượt | | g12 Bãi Lau | 24/24 | 0 | 6 | ≤ 6 lượt |
| m11 Bát Nàn Giữ Ải | 23/24 | 0 | 14 | ≤ 14 lượt | | g13 Miếu Cổ | 15/24 | 0 | 11 | ≤ 11 lượt |
| m12 Trận Lãng Bạc | 23/24 | 1 | 18 | ≤ 17 lượt | | g14 Đầm Lầy | 24/24 | 0 | 8 | mất ≤ 0 |
| m13 Địu Con Phá Vây | 20/24 | 0 | 7 | ≤ 7 lượt | | g15 Thành Mới | 20/24 | 0 | 15 | ≤ 15 lượt |
| m14 Rút Về Cấm Khê | 20/24 | 0 | 9 | ≤ 9 lượt | | g16 Núi Rồng | 24/24 | 0 | 11 | ≤ 11 lượt |
| m15 Thành Cấm Khê | 12/24 | 0 | 12 | mất ≤ 12 | | g17 Lũy Tre | 10/24 | 0 | 19 | ≤ 20 lượt |
| m16 Đêm Sông Hát | 12/24 | 0 | 9 | mất ≤ 7 | | g18 Trăng Khuyết | 24/24 | 0 | 12 | ≤ 12 lượt |
| g01 Bến Đò | 13/24 | 0 | 16 | ≤ 16 lượt | | g19 Giữ Thành | 24/24 | 0 | 11 | mất ≤ 6 |
| g02 Đồi Sim | 23/24 | 1 | 13 | ≤ 13 lượt | | g20 Trận Cuối | 9/24 | 1 | 25 | ≤ 25 lượt |

- Bảng cũ (2026-11-06, luật đi cũ = mv đủ, AI `fe83a5d`, 12 ván): xem git history README trước `rules/move-minus-one`.

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
| Lối chơi từng loại quân (thẻ giới thiệu, ⓘ) | `content/guide.gd` (đặc tính tự sinh từ chỉ số) |
| Level (1 file / level, tự gom theo `order`) | `content/levels/mNN.gd`, định dạng ở `docs/content.md` |
| Bản đồ đấu tự do | `content/skirmish_maps.gd` |
| Chỉ số lính, tướng, địa hình, kinh tế | `scripts/core/rules.gd` |
| Ảnh thật thay emoji / hình vẽ | thêm `"img": "res://…png"` vào lính / tướng / địa hình trong theme |
| Bộ hình chibi (mặc định) | `assets/units/styles/chibi/<loại>_<p\|e>.svg` + `assets/terrain/chibi/*.svg` (SVG thô, importer "keep", vẽ lại đúng cỡ màn hình lúc chạy). Cờ `figstyle=off` = bóng người + địa hình vẽ code cũ |
Thêm emoji mới vào chữ: chạy `python tools/build_fonts.py <thư mục có NotoSansSymbols2.ttf>` để tải PNG Noto tương ứng.

## Kiến trúc
- `scripts/core`: luật thuần, không Node. Trạng thái ván là Dictionary (ô = `Vector2i`), lưu bằng `var_to_str` vào `user://` (web: IndexedDB). `content.gd` gom level + theme. `rules.gd` = số liệu + cờ (quân, công trình), `objectives.gd` = kiểu mục tiêu màn; `game.gd` / `ai.gd` không so tên quân / ký tự ô.
- `scripts/ui`: `main.gd` (vỏ + cờ debug), `menus.gd` + `menu_bg.gd` + `level_select.gd` (tiêu đề, lưới Thử thách, đấu tự do, Sách lính), `game_screen.gd` (trạng thái ván, chọn quân + click, gợi ý) + phần tách ra: `game_hud.gd` (HUD nổi, ⚙, thẻ góc, Hết lượt), `info_panel.gd` (popup lệnh / ⓘ / mua cạnh ô), `event_player.gd` (phát lại sự kiện, đếm vàng / máu), `turn_driver.gd` (lượt, lượt địch, bot, trao máy, kết thúc), `game_cards.gd` (giới thiệu quân mới, thẻ kết thúc), `board.gd` (bàn 2D: quân vẽ từ atlas, FX, đêm, nhãn dự báo) + `board_paint.gd` (vẽ địa hình bake 1 texture, nhà cửa), `fx.gd` + `fx_strikes.gd` (đòn cận chiến riêng từng loại quân), `token.gd`, `style.gd`, `draw.gd`, `audio.gd` (âm thanh dựng sẵn thành wav trong `assets/sfx`, tạo lại: `godot --headless --path . -s tools/bake_sfx.gd`; + nhạc ngũ cung), `emoji_font.gd`, `store.gd`.
- `shaders/`: nền menu, logo ánh kim, vignette, màn đêm.
- Font: Be Vietnam Pro + Alegreya SC (OFL), subset Noto Sans Symbols 2 (OFL), emoji Noto (Apache 2.0) đóng thành font bitmap lúc khởi động. Không dùng font hệ thống, nên web và máy bàn hiển thị như nhau.

## Giới hạn đã biết
- Bố cục ngang (khung gốc 1280x720). Màn nhỏ: giao diện không thu dưới 0.8 lần, trang menu cuộn được (điện thoại nằm ngang đọc được). Điện thoại dọc: màn "Xoay ngang màn hình để chơi".
- Âm thanh là wav dựng sẵn (22 kHz); trên web chỉ phát sau cú bấm đầu tiên (quy định trình duyệt).
- Sử tích trong game theo truyền thuyết và sách sử phổ thông, có lược bớt cho hợp lối chơi.

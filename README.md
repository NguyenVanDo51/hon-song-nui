# Hồn Sông Núi — bản Godot

Viết lại `../hon-song-nui` (JS + canvas, một trang HTML) bằng Godot 4.7, GDScript.
Gốc so sánh: JS commit `3e888f1` (reskin Hai Bà Trưng, 2026-11-04).

Chiến thuật theo lượt trên lưới ô: khởi nghĩa Hai Bà Trưng năm 40, chiến dịch 8 màn quanh Hà Nội + đấu tự do. Luật xem `docs/spec.md`.

## Chạy (Windows)
Godot 4.7.2 cài bằng winget, không có trên PATH:

```
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
%GODOT% --path .              # chơi
%GODOT% -e --path .           # mở editor
```
Clone mới: chạy `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` một lần trước. Lệnh không cửa sổ (test, sim) dùng bản `_console.exe` để thấy output. macOS: `godot --path .`.

Điều khiển: chuột trái chọn / đi / đánh, chuột phải hoặc `Esc` hủy (Esc cũng đóng Sách lính).

Cờ debug (sau `--`): `mission=m03` vào thẳng màn · `bot` AI chơi phe ta · `speed=3` · `fresh` bỏ ván đang lưu · `screen=title|campaign|briefing:m05|skirmish|codex` · `shots=res://shots/x shot_every=2 tag=x` chụp màn hình định kỳ (và màn kết thúc) · `quit_at=60`.

## Kiểm tra
```
godot --headless --path . -s sim/tests.gd                 # 25 test (luật, nội dung, lưu ván), exit 1 nếu hỏng
godot --headless --path . -s sim/sim.gd -- mission all 20  # cân bằng: AI chơi cả hai phe, giống scripts/sim.cjs
godot --headless --path . -s sim/sim.gd -- skirmish 12 [easy] | naive 10
godot --headless --path . -s sim/trace.gd [-- only=m01,m05] # 1 dòng/ván: kết quả + hash FNV mọi nước đi
```

## Khớp với bản JS
Luật (`scripts/core/game.gd`) và AI (`scripts/core/ai.gd`) port 1-1 từ `src/core/engine.js` / `ai.js`: cùng thứ tự duyệt (Dijkstra lấy ô rẻ nhất, chèn trước thắng khi hòa = sort ổn định của V8), cùng biểu thức số thực, cùng RNG LCG tính bằng double. `sim/trace.gd` in cho mỗi ván hash của mọi nước AI + vị trí/máu/KN cuối + vàng; bản JS tương ứng in cùng định dạng, `diff` hai file:

PARITY_TABLE

Thời gian AI một nước (GDScript): m01 trung bình ~9 ms, m05/m08 ~26 ms, tệ nhất ~100 ms (đo khi máy đang bận).

## Thay nội dung (không đụng code)
| Muốn đổi | Sửa ở |
|---|---|
| Tên, icon, màu phe, chữ giao diện, bản đồ chiến dịch | `content/theme.gd` |
| Màn chiến dịch (1 file / màn, tự gom theo `order`) | `content/campaign/mNN.gd`, định dạng ở `docs/content.md` |
| Bản đồ đấu tự do | `content/skirmish_maps.gd` |
| Chỉ số lính, tướng, địa hình, kinh tế | `scripts/core/rules.gd` |
| Ảnh thật thay emoji / hình vẽ | thêm `"img": "res://…png"` vào lính / tướng / địa hình trong theme |

## Kiến trúc
- `scripts/core`: luật thuần, không Node. Trạng thái ván là Dictionary cùng tên trường với bản JS (ô = `Vector2i`), lưu bằng `var_to_str` vào `user://`.
- `scripts/ui`: `main.gd` (vỏ + cờ debug), `menus.gd` + `menu_bg.gd` + `camp_map.gd` (tiêu đề, bản đồ chiến dịch, giới thiệu màn, đấu tự do, Sách lính), `game_screen.gd` (thanh trên, mẹo, bảng bên, phát lại sự kiện, lượt địch, gợi ý, màn kết thúc), `board.gd` (bàn cờ: lớp địa hình cache + lớp động + FX + đêm), `fx.gd` (hạt, đạn, vòng, số bay, rung), `token.gd`, `style.gd` (bảng màu, font, Theme, widget), `draw.gd` (gradient / elip / đường cong), `audio.gd` (âm thanh tổng hợp lúc khởi động, nhạc ngũ cung sinh ngẫu nhiên), `store.gd`.
- `shaders/`: nền menu, logo ánh kim, vignette, màn đêm.
- Font: Be Vietnam Pro + Alegreya SC (OFL, `assets/fonts`). Emoji lấy từ font hệ thống (Segoe UI Emoji / Apple Color Emoji) qua fallback.

## Khác bản JS
- Chỉ bố cục ngang (bảng bên phải); bản web còn có bố cục dọc cho điện thoại.
- Bỏ hiệu ứng nhấc nút khi rê chuột và nút "Xuất quân" dính đáy; thẻ màn khóa làm mờ thay vì xám.
- Âm thanh dựng sẵn thành sample lúc khởi động (22 kHz) thay vì WebAudio thời gian thực; nhạc canh nhịp theo khung hình.
- Giữ nguyên hai chuỗi còn sót từ skin cũ của bản gốc: "Yêu quái đang ra quân…" (bảng bên lúc địch đi) và tab "Yêu quái" trong Sách lính.

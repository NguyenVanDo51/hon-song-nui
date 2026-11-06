# Code review 2026-11-06 (5 reviewers: mở rộng / tái sử dụng / tối ưu / độ phủ test / bug tiềm ẩn)

Phạm vi: toàn repo, tập trung `9ae3f66..1cba1a9`. Đã sửa trong commit "fix: review findings"; còn lại = backlog dưới.

## Đã sửa
| # | Vấn đề | Sửa |
|---|---|---|
| B1 | m13 (reach, ta không có thành): tướng chết -> game chạy tiếp vô ích tới hết lượt | `loss_reason`: reach + tướng chết + 0 thành -> `heroFell` |
| B2 | AI đứng mãi trên ô đích khi tướng mua lại ở đó (`offGoal`) -> m14 hết giờ | AI: tướng `offGoal` đứng trên đích -500 (bước ra, lượt sau quay lại). golden: 3 ván m14 e timeUp -> p reached |
| B3 | Đếm vàng đầu lượt không bao giờ chạy (gắn nhầm vào end_turn của ta) | đặt `_gold_shown` ở `enemy_turn` (nơi vàng ta thật sự cộng) |
| B4 | Tween đếm máu chạy lấn sang ván mới / đè máu hiển thị khi đánh | `_heal_tws` + `_stop_heal_counts()` ở `start()` và `commit()` |
| B5 | Thẻ góc dùng ô cũ sau khi đổi cỡ cửa sổ | `_card_avoid` lưu ô, đổi ra rect lúc đặt |
| B6 | Bấm lại ô thành của quân vừa mua chồng = hủy mua (ngoài ý muốn) | ô của chính nó không hủy |
| B7 | Vòng lượt địch / bot không có chặn khi bước AI bị từ chối -> treo | `_progress_sig()`: không đổi gì -> thoát |
| B8 | `hadCastle` chỉ ghi lúc đầu ván (spec: "chưa từng có thành") | chiếm thành -> `hadCastle[side] = true` |
| T1 | Test crash giữa chừng vẫn tính qua | `run_guarded.sh/.ps1`: có SCRIPT ERROR -> exit 1 |
| T2 | Thiếu test | + bảng chỉ số = spec, modifier sát thương, cấp tối đa / chết khi phản đòn, B1, B2, B8; click_driver: đếm vàng luồng thật, hủy mua |
| P6 | coin_pop đổi cỡ chữ mỗi khung (cache glyph theo cỡ) | cỡ cố định + `draw_set_transform` |

## Backlog (chưa làm; user chọn)
### Hiệu năng (đo trên Mac; mobile = ước lượng x3–5)
- P1 `board._draw_water` vẽ lại mỗi khung: 0.8–1.0 ms/khung m12 (~80% thời gian vẽ GDScript) -> shader.
- P2 Zoom đánh: raster SVG theo scale đang tween -> 145 raster mới / lần, khung tệ nhất 18.6 ms (ấm: 7.6) -> raster theo scale đích / vẽ từ atlas khi đang zoom.
- P3 `_terrain_hi` luôn giữ: 19 MB (1x) / 77 MB (2x), > 4096 px ở scale ~2.1 -> cấp khi focus, giải phóng khi unfocus.
- P4 Nhà vẽ lại mỗi khung (~275 draw call) -> bake vào terrain.
- P5 AI trên main thread: tệ nhất 12 ms/bước (m12); `threat_map` tính lại mỗi bước.
- P7 `_draw_smear` 155–200 µs/khung; P8 `_attackable_anywhere` chưa memo (307 µs/hover).
### Mở rộng
- E1 Chỉ 2 phe "p"/"e" (`Game.other`, lượt mới khi side=="p", không team, 1 tướng/phe) -> chặn 3–4 phe / đồng minh / hotseat.
- E2 Công trình nhận theo ký tự ô (v/c), làng = sở hữu − thành -> mô tả công trình trong TERRAIN.
- E3 Danh sách tên quân viết tay (heavy, AI WEIGHTS crash nếu thiếu, aura/poison 10 cứng) -> cờ dữ liệu.
- E4 Mục tiêu màn rải 7 chỗ -> registry `objectives`.
- E5 `game_screen.gd` 2051 dòng -> TurnDriver / EventPlayer / InfoPanel; "p" = `local_side`.
- E6 Chuỗi tiếng Việt trong code (~150 dòng) -> theme.text / `tr()`.
- E7 Xoá `battle_view.gd` (667 dòng, đã tắt).
### Tái sử dụng
- R1 Thanh máu chép 3 nơi, ngưỡng đã lệch (60/30 vs 50/25) -> `Board.draw_unit_badges` + `Style.hp_color`.
- R2 Board / Board3D không có lớp cha (input, view, focus, danh sách quân; 3D thiếu offset quân chồng) -> `BoardBase`.
- R3 Hằng số token (chân 0.30T, cao, bóng) ở Token + Rig + Board -> `Token.FOOT/fig_h/draw_shadow`.
- R4 Spec đòn đánh: INK khai báo 7 lần; hạt bụi/giọt/than chép 5 lần -> `RigFx.Mote`, `extends RigFx.Timed`.
- R5 Probe lặp boilerplate (~120 dòng), LCG + vòng AI chép 4 lần -> `probe_base.gd`, `sim_lib.gd`.
### Test còn thiếu
- Golden chỉ phát hiện thay đổi, mỗi lần đổi AI lại tạo lại -> replay thêm 1 ván chương 2 trong tests; test "mọi màn AI-vs-AI kết thúc".
- UI: phá / sửa làng / gọi hồn qua click, phím tắt, quân chồng chặn hết lượt; save giữa ván (paid, độc, mộ, rng); cache raster; heal cap 100.

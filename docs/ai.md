# AI: tham số, tự đấu, độ khó

## Tham số (`scripts/core/ai.gd`)
- Mọi hằng số chấm điểm ở `AI.DEFAULT` (1 Dictionary): trọng số khoảng cách tới mục tiêu, thủ địa hình, thận trọng (lính / tướng), giá máu / giá chết, hồi máu, về nhà, thành, chiếm, đánh, nhiễu, mua lính.
- Ghi đè theo phe: `s.aiParams = { "e": { "noise": 40.0, ... } }` (dict thiếu khóa cũng được, gộp lên `DEFAULT`, nhớ trong `mem` theo lượt). Không có `aiParams` = `DEFAULT`, file lưu không đổi, golden không đổi.
- Lính máu thấp: hp < `home_hp` (50) -> mục tiêu = ô hồi máu của phe (làng / thành của ta, đền) còn trống -> đi về qua nhiều lượt; thưởng `heal_hp` (< 70) giữ nó trên ô tới ~70 máu rồi quay lại đánh. Ô hồi gần nhất xa hơn `home_turns` (4) lượt đi / không có -> mục tiêu thường, lính thường bỏ sợ chết (không ngồi ỳ). Mục tiêu màn "tới đích" vẫn ưu tiên.
- Thử: `sim/probes/sulk.gd -- scene` (1 lính máu 25 ở xa nhà, địch đứng yên: vị trí / máu mỗi lượt), `-- scan 4` (mọi màn + đấu tự do: lính < 50 máu ngoài ô hồi -> đánh / về nhà / ỳ), `sim/probes/ai_time.gd` (ms mỗi nước AI).

## Tự đấu (`sim/tune.gd`, `tools/tune.sh`)
- `match a=<spec> b=<spec> games=N salt=S`: A (phe p) vs B (phe e) rồi đổi chỗ, trên mọi bản đồ đấu tự do (`Content.SKIRMISH.MAPS`, 3 bản) -> điểm A (thắng 1, hòa 0.5), 6·N ván. Seed: ván k của salt -> `1000 + (salt·64 + k)·7919` (LCG như `sim_lib`). Cùng params -> đúng 0.500 (kiểm tra).
- `evolve out=<file> games=8 minutes=20 island=k thr=0.55`: đột biến ~3 khóa của best (×exp(N(0, 0.3)), `noise` + `cap_last` giữ nguyên), đấu con vs best; giữ con khi > thr trên 2 bộ seed (2·48 ván). Ghi `var_to_str({gen, best, history})` sau mỗi thế hệ -> chạy lại cùng file = tiếp tục.
- `tools/tune.sh [islands] [minutes] [games] [held_games]`: các đảo chạy song song (mỗi đảo 1 tiến trình, `run_guarded`), rồi mỗi best vs `DEFAULT` trên seed giữ riêng (salt 9000000, `held_games`·6 ván); đảo tốt nhất (nếu > 0.5) -> `sim/tuned_params.txt`. Không đổi AI mặc định của game.
- `presets games=N`: vòng tròn các mức độ khó (bên dưới).

### Phiên tune 2026-11-06 (AI `5a75b2a` = `fe83a5d` + bảng tham số, Mac 10 nhân, chạy chung máy với việc khác)
- `tools/tune.sh 6 25 8 16`: 6 đảo × 25 phút, 12–13 thế hệ / đảo (48 ván / thế hệ, 96 khi xác nhận; 576–624 ván / đảo), 2 lần nhận.
- Tốc độ: ~1,0 ván/s một tiến trình khi máy rảnh; 0,4 ván/s mỗi đảo khi 6 đảo + việc khác (tổng ~2,4 ván/s); 4 tiến trình: ~0,65 ván/s mỗi cái.
- Ván có lợi thế ghế theo bản đồ (DEFAULT vs DEFAULT: dong_bang phe e thắng ~80%, nui_rung phe p ~75%) -> luôn đấu cả 2 ghế.
- Best (đảo 5): `hp_cap` 150 -> 81,3, `kill_hero` 600 -> 552 (lính rẻ cũng tính giá chết -> ít lao vào chỗ chết). Vs `DEFAULT`: 0,562 / 96 ván (seed chọn đảo), **0,573 / 384 ván seed mới** (salt 9000001–4; ~2,9 SE). Đảo 2 (`caution` 0,6 -> 0,94): 0,531 / 96. 4 đảo còn lại không nhận con nào (0,500).
- Ghi vào `sim/tuned_params.txt`; AI mặc định của game **không đổi**.

## Độ khó (phác thảo, chưa nối vào game)
Cho chế độ 1v1 sau này (người vs người tại chỗ, hoặc người vs AI Dễ / Thường / Khó). Nối: lúc tạo ván, `s.aiParams = { "e": PRESET }` (lưu cùng ván -> nạp lại vẫn đúng mức).

| Mức | Params | Ghi chú |
|---|---|---|
| Dễ | `noise` 60, `caution` 0, `caution_hero` 0.3, `home_hp` 0, `heal_hp` 0, `maydie_w` 0.1 | liều: không sợ chết, không về hồi máu, chọn nước thô |
| Dễ + ½ vàng | Dễ + vàng đầu ván ×0.5 (`skirmish_def(..., easy=true)` đã có cho phe e) | chấp thêm |
| Thường | `DEFAULT` | AI hiện tại |
| Khó | `sim/tuned_params.txt` (`noise` giữ 8) | tham số tự đấu. Bản ít nhiễu (`noise` 2, `hard_n2`) đo ra **yếu hơn** Thường -> bỏ |

Đo (`sim/tune.gd -- presets games=8`, 4 bộ seed salt 9000000/10/20/30, 192 ván / cặp; điểm hàng vs cột, thắng 1 hòa 0,5):

| | Dễ+½ vàng | Dễ | Thường | Khó | Khó noise 2 |
|---|---|---|---|---|---|
| Dễ+½ vàng | – | 0,318 | 0,125 | 0,146 | 0,120 |
| Dễ | 0,682 | – | 0,326 | 0,234 | 0,260 |
| Thường | 0,875 | 0,674 | – | 0,448 | 0,542 |
| Khó | 0,854 | 0,766 | 0,552 | – | 0,539 |
| Khó noise 2 | 0,880 | 0,740 | 0,458 | 0,461 | – |

- Thứ tự đúng: Dễ+½ vàng < Dễ < Thường < Khó. Khó vs Thường 0,552 (riêng 3 bộ seed không dùng để chọn đảo: 0,549).
- Khoảng cách Thường–Khó nhỏ (~55%): muốn Khó rõ hơn -> tune lâu hơn / nhiều ván hơn mỗi thế hệ, hoặc cho Khó thêm vàng.
- Dễ còn thắng Thường ~1/3 (AI-vs-AI); với người thật, Dễ nên thử chơi trước khi chốt số.

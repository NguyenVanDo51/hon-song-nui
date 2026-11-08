# Tiền đề "Ngọn Lửa Lâu Đài" — thiết kế

Ngày: 2026-11-08. Nhánh `feat/flame-premise` (từ master 7527069).
**(user)** = user quyết · **(Claude)** = Claude tự quyết (user "ok quất luôn đi", xem lại được).

## 1. Vì sao
- User gần như luôn bỏ qua cốt truyện; ra App Store toàn cầu -> không đầu tư truyện để đọc. (user)
- Cần 1 tiền đề cho ảnh store / màn tiêu đề + chút bối cảnh mỗi màn, không chen vào lúc chơi. (user duyệt)
- Thế giới giả tưởng chung, bỏ hẳn chất Việt. Không khí nghiêm túc: khởi nghĩa giành lại vương quốc từ Đế Quốc. (user)
- Chọn hướng 2 "Ngọn Lửa Lâu Đài": mỗi lâu đài từng giữ ngọn lửa thề, Đế Quốc dập tắt; giành lại lâu đài = thắp lại lửa. (user)

## 2. Làm
1. **Tiền đề** (`content/theme.gd`): `lede` = "Đế Quốc đã dập tắt mọi ngọn lửa. Thắp lại từng lâu đài." hiện dưới logo màn tiêu đề (trước đây `lede` không dùng). `tagline` giữ "Cờ chiến thuật theo lượt". Câu store tiếng Anh *"The Empire put out every flame. Relight them, castle by castle."* chỉ ghi ở đây, không vào game (dịch = việc riêng).
2. **Lửa trên bàn cờ** (Claude): lâu đài phe ta có ngọn lửa cháy (động, mọi frame) trên tháp cổng; lâu đài Đế Quốc: khói mảnh; lâu đài trung lập: không gì (lửa tắt). Vừa đổi chủ -> lửa bùng to rồi dịu (~1 s) / khói phụt. Vẽ cho mọi lâu đài kể cả có ảnh SVG (ảnh vẽ sẵn, lửa = lớp riêng), dựng đứng khi bàn xoay dọc (`up_xf`).
3. **Màn tiêu đề**: lâu đài trong tranh có ngọn lửa.
4. **Lưới chọn màn**: dòng bối cảnh dưới tên màn; dòng đếm "🔥 N/39 ngọn lửa đã thắp" (N = số màn đã thắng) trên khung thông tin. Không vẽ lửa trên từng ô (ô 52–84 px đã đủ chật) (Claude).
5. **Bối cảnh 1 câu / màn**: khóa mới `"lore"` trong `DEF` (không dùng lại `story` / `history` / `tips`: test cấm). Câu khiêu khích của tướng địch = cùng khóa này ở 4 màn (m02, m12, g16, g20), dạng `Vorn: «…»`. Không UI mới, không thoại.
6. **Tướng địch có tên**: `tuonggiac` name "Hắc Hiệp Sĩ" -> **"Vorn"** (ngắn, đọc được mọi thứ tiếng, vừa thanh mục tiêu "Hạ Vorn") (Claude); blurb nói Vorn là Hắc Hiệp Sĩ đã dập lửa. Tướng ta giữ "Hiệp Sĩ Chỉ Huy".
7. **Đổi tên 36 màn** m01–m16, g01–g20 (bảng §3) + `sim/level_recipes.gd` (g*) + chú thích đầu file m* (còn tên nhân vật sử Việt). Đổi `skirmishTitle` "Đồng bằng sông Hồng", bản đấu tự do "Cù lao sông Bạc". Đóng `docs/TODO.md` mục tên màn Việt.

## 3. Tên + bối cảnh (Claude soạn)
Mạch: nhóm lửa (t01–m04) -> lan ra sông, biển (g01–m10) -> vùng núi + ải (m11–g13) -> bị dồn, rút lên núi giữ lửa (m14–m16) -> phản công về kinh đô (g17–g20).

| id | Tên mới | Bối cảnh |
|---|---|---|
| t01 | Bài Học Đầu (giữ) | Một làng nhỏ ngoài biên, nơi cuộc khởi nghĩa nhóm những tia lửa đầu tiên. |
| t02 | Lâu Đài Trống (giữ) | Lâu đài bỏ hoang từ ngày lửa tắt. Quân Đế Quốc đang kéo tới. |
| t03 | Chiêu Binh (giữ) | Có lâu đài, có làng: đủ để chiêu binh. |
| m01 | Lời Thề Bên Tro Tàn | Bên đống tro lâu đài cũ, những người cuối cùng thề thắp lại ngọn lửa. |
| m02 | Ngọn Lửa Đầu Tiên | Vorn: «Một đốm lửa con. Ta dập nó trong một đêm.» |
| m03 | Giữ Làng Biên Giới | Đế Quốc kéo quân tới đòi lại làng. Giữ vững cho tới khi chúng nản. |
| m04 | Đồn Gác Phương Bắc | Vorn đích thân trấn đồn gác. Hạ hắn, cả đồn tan rã. |
| g01 | Bến Phà Cũ | Bến phà là đường duy nhất qua sông, và một lâu đài đang giữ nó. |
| m05 | Đêm Hồ Gương | Trăng lặn. Đánh úp lâu đài bên hồ khi Đế Quốc còn ngủ. |
| g02 | Đồi Gió | Một đạo quân Đế Quốc cắm trại trên đồi. Quét sạch chúng. |
| m06 | Bãi Sông Xám | Vorn đuổi tới tận bãi sông. Lần này không lùi nữa. |
| g03 | Ngã Ba Sông | Ai giữ ngã ba sông, người đó giữ cả vùng. |
| g04 | Giữ Đồn | Đồn gác vừa giành lại. Đế Quốc quay lại đòi nó. |
| m07 | Vây Lâu Đài Đá Trắng | Tường đá quá dày cho gươm giáo. Máy bắn đá sẽ mở đường. |
| g05 | Rừng Sồi Già | Vorn ẩn trong rừng sồi. Lùng ra và hạ hắn. |
| m08 | Phủ Thành Đế Quốc | Nơi Đế Quốc cai trị cả vùng. Chiếm nó, cả vùng sẽ thắp lửa. |
| g06 | Bãi Cát Giữa Sông | Quân Đế Quốc mắc kẹt trên bãi cát. Đừng để tên nào thoát. |
| m09 | Tin Dữ Từ Biển | Thuyền Đế Quốc đổ bộ từ biển. Giữ vững tới khi chúng rút. |
| g07 | Cửa Sông | Vorn đóng quân ở cửa sông. Hạ hắn, cắt đường tiếp viện. |
| m10 | Vịnh Bão | Đế Quốc đốt làng dọc vịnh. Dựng lại làng, rồi hạ Vorn. |
| g08 | Sông Bạc | Lâu đài bên Sông Bạc giữ đường vào vùng trong. |
| g09 | Làng Cối Xay | Vorn lấy làng cối xay làm đại bản doanh. Hạ hắn. |
| m11 | Ải Sói | Bầy sói của Đế Quốc canh ải núi. Chiếm lâu đài sau ải. |
| g10 | Rừng Đêm (giữ) | Trong rừng tối, quân Đế Quốc lạc nhau. Săn từng toán. |
| m12 | Hồ Sương Mù | Vorn: «Ngươi thắp mười ngọn, ta dập mười một.» |
| g11 | Thành Đá (giữ) | Thành Đá chưa từng thất thủ. Cho tới hôm nay. |
| g12 | Bãi Sậy | Quân Đế Quốc phục trong bãi sậy. Lôi chúng ra. |
| m13 | Phá Vòng Vây | Vòng vây khép lại. Mở đường tới cờ vàng trước khi quá muộn. |
| g13 | Đền Cổ | Lâu đài quanh ngôi đền cổ đã tắt lửa quá lâu. |
| m14 | Rút Lên Núi | Đại quân Đế Quốc tràn tới. Rút lên pháo đài trên núi, giữ lấy ngọn lửa. |
| g14 | Đầm Lầy (giữ) | Kẹt giữa đầm lầy. Trụ vững cho tới khi địch đuối sức. |
| g15 | Thành Mới Xây | Đế Quốc xây thành mới để chặn đường. Đừng để nó đứng vững. |
| m15 | Pháo Đài Trên Núi | Ngọn lửa cuối cùng phía tây. Giữ nó bằng mọi giá. |
| g16 | Núi Rồng (giữ) | Vorn: «Leo tới đây rồi sao? Đỉnh núi này là mồ của ngươi.» |
| m16 | Đêm Dài Nhất | Nếu lửa còn cháy tới sáng, Đế Quốc sẽ phải lùi. |
| g17 | Tường Gai | Bức tường cuối cùng trước kinh đô. Phá nó. |
| g18 | Trăng Khuyết (giữ) | Dưới trăng khuyết, cận vệ của Vorn đi tuần. Diệt sạch. |
| g19 | Cổng Kinh Đô | Trước cổng kinh đô, Đế Quốc dốc toàn lực phản công. Trụ vững. |
| g20 | Ngọn Lửa Kinh Đô | Vorn: «Ngọn lửa cuối cùng thuộc về Đế Quốc.» |

## 4. Không làm
- Không thoại, không cảnh dẫn truyện, không mở màn bằng chữ. (user)
- Không lối đánh riêng cho tướng địch, không sửa bot. (user)
- Không chia lại quân theo phe. (user)
- Không đổi tên game "Công Thành Chiến" / tướng ta (đi cùng việc dịch). Không dịch. (Claude)
- Không đổi luật / chỉ số / bản đồ.

## 5. Kiểm
- `sim/tests` + lint xanh; golden không đổi (tên / lore không vào trace).
- `click_driver m02` 0 lỗi; `tut_driver t02` 0 lỗi (lâu đài có lớp lửa).
- Ảnh: lâu đài ta / địch / trung lập + vừa chiếm, 1280x720 + 540x1170 (dọc); màn tiêu đề; lưới chọn màn.

## 6. Bản đồ Thử thách (thêm sau, user)
- User: màn chọn Thử thách làm dạng bản đồ như ngày xưa; thấy vùng đã chiếm lại / chưa (chưa mở = chưa chiếm lại); chạm = thông tin cơ bản, bớt chữ; "Xuất quân" vào game luôn. (user)
- 1 bản đồ vương quốc, 5 vùng theo mạch §3: Biên Giới (tây nam) -> Vùng Sông -> Vùng Núi -> Pháo Đài (tây bắc) -> Kinh Đô (đông bắc); biển phía đông. (Claude)
- Điểm màn trên đường hành quân: đã thắng = đỏ + lửa + sao, đất quanh đỏ; màn kế = vàng nhấp nháy; chưa mở = mờ, sương xanh Đế Quốc. Vùng thắng hết -> tên vùng đỏ. (Claude)
- Thẻ: số (màu độ khó) + tên + sao tốt nhất, `lore`, mục tiêu dạng ngắn (`goals[type].short`), nút "Xuất quân ›"; chưa mở: "🔒 Chưa chiếm lại". Bỏ: dòng "THỬ THÁCH N / độ khó", 3 dòng mục tiêu sao, "Bấm để vào trận". (Claude)
- "Xuất quân" vẫn qua `confirm_start`: đang dở ván khác -> hỏi trước khi xoá (không mất ván). (Claude)
- Kéo để xem (≥ 6 px / đơn vị bản đồ); màn dọc phóng theo chiều cao, kéo ngang. Mở ra canh vào màn kế, hoặc màn vừa chơi khi quay về. (Claude)
- Vòng 2 (user): mở bản đồ không hiện thẻ (chỉ khi chạm); chọn màn không được cuộn bản đồ đi (chỉ dịch tối thiểu nếu thẻ che); bản đồ đẹp + chi tiết hơn -> lâu đài thật mỗi màn (đỏ + lửa = của ta, xanh = Đế Quốc), cảnh từ ảnh địa hình bàn cờ, biển có thuyền + la bàn, mây che vùng chưa mở. (user / Claude)
- Vòng 3 (user): thẻ giữa màn hình (chọn màn góc dưới không bị cuộn); lâu đài to quá, sao bé quá -> "đổi cách khác, không hiện lâu đài lửa" -> khiên có số + dải sao to (Claude chọn khiên); mây phải ra hình mây.


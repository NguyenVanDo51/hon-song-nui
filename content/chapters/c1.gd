extends RefCounted
## chapter 1. Fields: id, order, title, years, subtitle, blurb (chapter tab), note, rivers / lakes / labels (schematic map,
## 100 x 70 viewbox, SVG path "M x,y C … S …"), theme (overrides merged over content/theme.gd), outro (shown when its last mission is won)

const DEF := {
	"id": "c1", "order": 1,
	"title": "Khởi nghĩa Hai Bà Trưng",
	"years": "Năm 40",
	"subtitle": "Mùa xuân năm 40 · Giao Chỉ dưới ách Đông Hán",
	"blurb": "Dựng cờ ở Hát Môn, lấy lại Mê Linh, Cổ Loa, Long Biên, tới trị sở Luy Lâu.",
	"note": "Sơ đồ phỏng theo, không đúng tỉ lệ. Địa danh ghi theo tên ngày nay.",
	"rivers": [
		{ "name": "Sông Hồng", "w": 3.2, "d": "M0,16 C14,20 22,26 34,30 S52,36 58,42 S70,56 80,62 S94,68 100,70" },
		{ "name": "Sông Đuống", "w": 2, "d": "M57,40 C64,36 72,36 80,34 S92,32 100,31" },
		{ "name": "Sông Đáy", "w": 1.6, "d": "M10,22 C12,32 9,42 13,52 S16,64 15,70" },
		{ "name": "Sông Cà Lồ", "w": 1.3, "d": "M22,8 C34,10 44,8 54,12 S66,20 74,26 S80,32 82,34" },
	],
	"lakes": [{ "name": "Hồ Tây", "cx": 50, "cy": 42.5, "rx": 3, "ry": 2.1 }],
	"labels": [
		{ "text": "GIAO CHỈ", "x": 30, "y": 62, "size": 4 },
		{ "text": "Sông Hồng", "x": 82, "y": 58, "size": 2.2, "river": true },
		{ "text": "Sông Đuống", "x": 86, "y": 29, "size": 2, "river": true },
		{ "text": "Sông Đáy", "x": 4, "y": 46, "size": 2, "river": true },
	],
	"outro": [
		["truyenthuyet", "Mùa xuân năm 40, Trưng Trắc lên ngôi vua, đóng đô ở Mê Linh. Sử gọi là Trưng Vương."],
		["truyenthuyet", "Nhưng ở phương Bắc, nhà Hán đã sai Phục Ba tướng quân Mã Viện sửa soạn thuyền binh..."],
	],
}

class_name BanhTet
extends RefCounted

## Hằng số dùng chung cho toàn app (chuyển từ src/lib/types.ts + constants.ts).

const ORDER_STATUSES: Array[String] = [
	"Mới đặt",
	"Đã cọc",
	"Đang nấu/gói",
	"Đã giao",
	"Đã hủy",
]

const STATUS_LABELS: Dictionary = {
	"Mới đặt": "🟡 Mới đặt",
	"Đã cọc": "🔵 Đã cọc",
	"Đang nấu/gói": "🟠 Đang nấu/gói",
	"Đã giao": "🟢 Đã giao",
	"Đã hủy": "🔴 Đã hủy",
}

const STATUS_COLORS: Dictionary = {
	"Mới đặt": Color(0.99, 0.95, 0.78),
	"Đã cọc": Color(0.87, 0.93, 1.0),
	"Đang nấu/gói": Color(1.0, 0.93, 0.83),
	"Đã giao": Color(0.85, 0.98, 0.91),
	"Đã hủy": Color(1.0, 0.87, 0.87),
}

const STATUS_TEXT_COLORS: Dictionary = {
	"Mới đặt": Color(0.45, 0.35, 0.05),
	"Đã cọc": Color(0.05, 0.25, 0.5),
	"Đang nấu/gói": Color(0.5, 0.3, 0.03),
	"Đã giao": Color(0.03, 0.4, 0.2),
	"Đã hủy": Color(0.55, 0.1, 0.1),
}

## Màu viền trái của card theo trạng thái (giống web: STATUS_ACCENT)
const STATUS_ACCENT_COLORS: Dictionary = {
	"Mới đặt": Color(0.984, 0.749, 0.141),      # yellow-400
	"Đã cọc": Color(0.235, 0.51, 0.965),        # blue-500
	"Đang nấu/gói": Color(0.949, 0.549, 0.157), # orange-500
	"Đã giao": Color(0.063, 0.792, 0.589),      # emerald-500
	"Đã hủy": Color(0.937, 0.267, 0.267),      # red-500
}

## Gợi ý nhanh các ngày giao trong dịp Tết
const DELIVERY_DATE_SUGGESTIONS: Array[Dictionary] = [
	{"value": "2027-02-02", "label": "26 Tết (02/02)", "short": "26 Tết"},
	{"value": "2027-02-03", "label": "27 Tết (03/02)", "short": "27 Tết"},
	{"value": "2027-02-04", "label": "28 Tết (04/02)", "short": "28 Tết"},
	{"value": "2027-02-05", "label": "29 Tết (05/02)", "short": "29 Tết"},
	{"value": "2027-02-06", "label": "Mùng 1 Tết (06/02)", "short": "Mùng 1"},
]

const DELIVERY_TIME_SUGGESTIONS: Array[String] = [
	"Sáng (07:00 - 11:00)",
	"Chiều (13:00 - 17:00)",
	"Tối (18:00 - 21:00)",
]

const DEFAULT_DELIVERY_DATE := "2027-02-03"
const DEFAULT_DELIVERY_TIME := "Sáng (07:00 - 11:00)"

## Ngày mùng 1 Tết Nguyên Đán Đinh Mùi
const TET_DATE_ISO := "2027-02-06"

## Dải ngày cao điểm cần giao: 27-29 Tết
const PEAK_DELIVERY_DATES: Array[String] = ["2027-02-03", "2027-02-04", "2027-02-05"]

const PRODUCT_CATEGORIES: Dictionary = {
	"CHUNG": "Bánh Chưng",
	"TET": "Bánh Tét",
}

## Bảng màu chủ đạt (port từ Tailwind theme của web app)
const RED_50 := Color(0.996, 0.949, 0.949)
const RED_100 := Color(1.0, 0.882, 0.882)
const RED_200 := Color(0.996, 0.749, 0.749)
const RED_300 := Color(0.984, 0.627, 0.627)
const RED_500 := Color(0.937, 0.267, 0.267)
const RED_600 := Color(0.863, 0.149, 0.149)
const RED_700 := Color(0.725, 0.11, 0.11)
const RED_800 := Color(0.6, 0.106, 0.106)
const RED_900 := Color(0.498, 0.114, 0.114)
const AMBER_50 := Color(1.0, 0.98, 0.941)
const AMBER_100 := Color(0.988, 0.953, 0.816)
const AMBER_200 := Color(0.992, 0.898, 0.698)
const AMBER_300 := Color(0.949, 0.788, 0.462)
const AMBER_400 := Color(0.984, 0.749, 0.141)
const AMBER_500 := Color(0.961, 0.62, 0.043)
const AMBER_600 := Color(0.851, 0.467, 0.024)
const AMBER_700 := Color(0.722, 0.349, 0.012)
const AMBER_800 := Color(0.545, 0.255, 0.016)
const AMBER_900 := Color(0.396, 0.204, 0.016)
const GRAY_50 := Color(0.98, 0.98, 0.98)
const GRAY_100 := Color(0.949, 0.949, 0.949)
const GRAY_200 := Color(0.898, 0.898, 0.898)
const GRAY_300 := Color(0.827, 0.827, 0.827)
const GRAY_400 := Color(0.639, 0.639, 0.639)
const GRAY_500 := Color(0.46, 0.46, 0.46)
const GRAY_600 := Color(0.36, 0.36, 0.36)
const GRAY_700 := Color(0.29, 0.29, 0.29)
const GRAY_800 := Color(0.18, 0.18, 0.18)
const GRAY_900 := Color(0.09, 0.09, 0.09)
const GREEN_600 := Color(0.02, 0.59, 0.41)
const GREEN_700 := Color(0.02, 0.47, 0.34)
const GREEN_800 := Color(0.024, 0.373, 0.275)
const EMERALD_600 := Color(0.02, 0.59, 0.41)
const WHITE := Color(1, 1, 1)
const BLACK := Color(0, 0, 0)


## Định dạng tiền Việt Nam: 150.000 đ
static func format_money(amount: int) -> String:
	var negative := amount < 0
	var value := absi(amount)
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		result = text[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "." + result
	if negative:
		result = "-" + result
	return result + " đ"


## Định dạng ngày ISO (2027-02-03) -> 03/02/2027, kèm nhãn Tết nếu có
static func format_date_display(date_str: String) -> String:
	if date_str.is_empty():
		return ""
	var parts := date_str.split("-")
	if parts.size() != 3:
		return date_str
	var lunar := ""
	for suggestion in DELIVERY_DATE_SUGGESTIONS:
		if suggestion["value"] == date_str:
			lunar = " (%s)" % suggestion["short"]
			break
	return "%s/%s/%s%s" % [parts[2], parts[1], parts[0], lunar]


## Ngày hôm nay dạng ISO
static func today_iso() -> String:
	return Time.get_date_string_from_system()


## Chuẩn hoá chuỗi: bỏ dấu, lowercase, gộp khoảng trắng
static func normalize_text(text: String) -> String:
	return QuickParse.normalize_text(text)


## Chuẩn hoá mã bánh: bỏ dấu, uppercase, bỏ khoảng trắng
static func normalize_code(code: String) -> String:
	return normalize_text(code).replace(" ", "").replace("\t", "")


## Tính tổng tiền từ danh sách số lượng
static func calculate_total(quantities: Dictionary, products: Array) -> int:
	var product_map := {}
	for p in products:
		product_map[p.get("id", "")] = p
	var total := 0
	for product_id in quantities:
		var qty: int = int(quantities[product_id])
		if qty <= 0:
			continue
		var product = product_map.get(product_id, null)
		if product == null:
			continue
		total += int(product.get("price", 0)) * qty
	return total


## Giá sỉ: ưu tiên wholesalePrice, nếu không có thì lấy 80% giá bán lẻ (làm tròn nghìn)
static func get_wholesale_price(product: Dictionary) -> int:
	var wholesale = product.get("wholesalePrice", null)
	if wholesale != null and int(wholesale) > 0:
		return int(wholesale)
	return int(round(float(product.get("price", 0)) * 0.8 / 1000.0) * 1000)

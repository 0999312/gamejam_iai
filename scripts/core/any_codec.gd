class_name AnyCodec
extends Codec

## 透传 Codec：接受任意 JSON 兼容值原样通过，用于设置/统计这类
## 「键集合由运行时决定」的字典。校验的是 JSON 载体能表达的六种类型，
## 而不是具体字段——字段级校验交给外层 record。

const _ALLOWED_TYPES: Array[int] = [
	TYPE_NIL,
	TYPE_BOOL,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_ARRAY,
	TYPE_DICTIONARY,
]


func encode(value: Variant, _ops: DynamicOps) -> DataResult:
	if not _is_json_value(value):
		return DataResult.error("AnyCodec: 无法编码为 JSON 的类型 %s" % type_string(typeof(value)))
	return DataResult.success(value)


func decode(value: Variant, _ops: DynamicOps) -> DataResult:
	if not _is_json_value(value):
		return DataResult.error("AnyCodec: 存档里的值不是 JSON 兼容类型 %s" % type_string(typeof(value)))
	return DataResult.success(value)


func _is_json_value(value: Variant) -> bool:
	if not _ALLOWED_TYPES.has(typeof(value)):
		return false
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			if not _is_json_value(item):
				return false
	elif typeof(value) == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			if typeof(key) != TYPE_STRING and typeof(key) != TYPE_INT:
				return false
			if not _is_json_value((value as Dictionary)[key]):
				return false
	return true

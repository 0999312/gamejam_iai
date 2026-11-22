class_name RainyNightBackdrop
extends Control

## 雨夜背景的降采样容器：shader 在 1280×720 的 SubViewport 里渲染，
## 再由 TextureRect 放大到实际画布。全屏（尤其 4K）时像素成本按逻辑分辨率封顶，
## 代价是背景被线性放大后略软；前景角色/UI 仍是原生分辨率。
##
## 对外只暴露 shader 参数设置：调用方不再直接拿 `material`，
## 避免拿到根 Control 的 CanvasItem 材质而不是雨夜材质。

const RENDER_SIZE := Vector2i(1280, 720)
const RAIN_SHADER := preload("res://resources/shaders/rainy_night.gdshader")

@onready var _viewport: SubViewport = $SubViewport
@onready var _rain: ColorRect = $SubViewport/Rain
@onready var _display: TextureRect = $Display

var _material: ShaderMaterial
var _pending_parameters: Dictionary = {}


func _ready() -> void:
	_viewport.size = RENDER_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rain.size = Vector2(RENDER_SIZE)
	var base := _rain.material as ShaderMaterial
	if base == null:
		base = ShaderMaterial.new()
		base.shader = RAIN_SHADER
	_material = base.duplicate() as ShaderMaterial
	_rain.material = _material
	_display.texture = _viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for key in _pending_parameters.keys():
		_material.set_shader_parameter(key, _pending_parameters[key])
	_pending_parameters.clear()


## 截图工具需要在竖屏相机下改变可见矩形；正常游戏固定 1280×720。
func set_render_size(render_size: Vector2i) -> void:
	if _viewport == null:
		return
	if render_size.x <= 0 or render_size.y <= 0:
		return
	_viewport.size = render_size
	_rain.size = Vector2(render_size)


func get_shader_material() -> ShaderMaterial:
	return _material


func set_shader_parameter(parameter: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(parameter, value)
	else:
		_pending_parameters[parameter] = value

class_name PBRPreviewCube
extends MeshInstance3D


@onready var material: StandardMaterial3D = mesh.material
@onready var albedo := ImageTexture.new()
@onready var metallic := ImageTexture.new()
@onready var roughness := ImageTexture.new()
@onready var normal := ImageTexture.new()

var default_albedo: Image
var default_metallic: Image
var default_roughness: Image
var default_normal: Image


func _ready() -> void:
	var white_image = Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	white_image.set_pixel(0, 0, Color.WHITE)
	var black_image = Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	black_image.set_pixel(0, 0, Color.BLACK)
	var normal_image = Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	normal_image.set_pixel(0, 0, Color(0.5, 0.5, 1.0))
	
	default_albedo = white_image
	default_metallic = black_image
	default_roughness = white_image
	default_normal = normal_image
	
	albedo.set_image(default_albedo)
	metallic.set_image(default_metallic)
	roughness.set_image(default_roughness)
	normal.set_image(default_normal)
	
	material.albedo_texture = albedo
	material.metallic_texture = metallic
	material.roughness_texture = roughness
	material.normal_texture = normal

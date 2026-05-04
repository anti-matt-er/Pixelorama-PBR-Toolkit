@tool
class_name PBRPreviewCube
extends MeshInstance3D


@onready var material: StandardMaterial3D = material_override
@onready var albedo := ImageTexture.new()
@onready var metallic := ImageTexture.new()
@onready var roughness := ImageTexture.new()
@onready var normal := ImageTexture.new()

var default_albedo: Image
var default_metallic: Image
var default_roughness: Image
var default_normal: Image


func _ready() -> void:
	if Engine.is_editor_hint():
		generate_mesh()
		return
	
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
	
	albedo.changed.connect(check_alpha)


func check_alpha() -> void:
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if albedo.has_alpha() else BaseMaterial3D.TRANSPARENCY_DISABLED


func generate_mesh() -> void:
	if mesh:
		return
		
	mesh = ArrayMesh.new()
	
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var s = 0.5 # Extents for unit-size cube
	
	var faces = [
		[Vector3.BACK,    Vector3(-s,  s,  s), Vector3( s,  s,  s), Vector3( s, -s,  s), Vector3(-s, -s,  s)], # Front
		[Vector3.FORWARD, Vector3( s,  s, -s), Vector3(-s,  s, -s), Vector3(-s, -s, -s), Vector3( s, -s, -s)], # Back
		[Vector3.UP,      Vector3(-s,  s, -s), Vector3( s,  s, -s), Vector3( s,  s,  s), Vector3(-s,  s,  s)], # Top
		[Vector3.DOWN,    Vector3(-s, -s,  s), Vector3( s, -s,  s), Vector3( s, -s, -s), Vector3(-s, -s, -s)], # Bottom
		[Vector3.RIGHT,   Vector3( s,  s,  s), Vector3( s,  s, -s), Vector3( s, -s, -s), Vector3( s, -s,  s)], # Right
		[Vector3.LEFT,    Vector3(-s,  s, -s), Vector3(-s,  s,  s), Vector3(-s, -s,  s), Vector3(-s, -s, -s)], # Left
	]
	
	var uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

	for face in faces:
		var face_normal = face[0]
		surface.set_normal(face_normal)
		
		surface.set_uv(uvs[0])
		surface.add_vertex(face[1])
		surface.set_uv(uvs[1])
		surface.add_vertex(face[2])
		surface.set_uv(uvs[2])
		surface.add_vertex(face[3])
		
		surface.set_uv(uvs[0])
		surface.add_vertex(face[1])
		surface.set_uv(uvs[2])
		surface.add_vertex(face[3])
		surface.set_uv(uvs[3])
		surface.add_vertex(face[4])

	surface.commit(mesh)
	

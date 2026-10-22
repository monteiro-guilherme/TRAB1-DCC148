
extends CharacterBody2D

const SPEED: float = 175.0
const DETECTION_RANGE: float = 400.0
const ATTACK_RANGE: float = 85.0

const VIDA_MAXIMA: int = 350
var vida_atual: int = VIDA_MAXIMA

const DANO_PUNCH: int = 30
const DANO_HEADBUTT: int = 40
const DANO_SUPERKICK: int = 50

# Nomes dos ataques
@export var anim_punch: StringName = &"ATK1(punch)"
@export var anim_headbutt: StringName = &"ATK2(headbutt)"
@export var anim_superkick: StringName = &"ATK3(super kick)"

# Frames de impacto
@export var punch_inicio: int = 4
@export var punch_fim: int = 6
@export var headbutt_inicio: int = 2
@export var headbutt_fim: int = 4
@export var superkick_inicio: int = 3
@export var superkick_fim: int = 5

enum Estado {
	IDLE,
	PERSEGUINDO,
	ATACANDO,
	RECEBENDO_DANO,
	MORTO
}

var estado_atual: Estado = Estado.IDLE
var combate_iniciado: bool = false

var rng := RandomNumberGenerator.new()
var dano_ataque: int = 0
var alvos_atingidos: Array[Area2D] = []

var player: CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox

@onready var punch: CollisionPolygon2D = $HitBox/Punch
@onready var headbutt: CollisionPolygon2D = $HitBox/Headbutt
@onready var superkick: CollisionPolygon2D = $HitBox/SuperKick

@onready var punch_x: float = punch.position.x
@onready var headbutt_x: float = headbutt.position.x
@onready var superkick_x: float = superkick.position.x

@onready var punch_original: PackedVector2Array = punch.polygon.duplicate()
@onready var headbutt_original: PackedVector2Array = headbutt.polygon.duplicate()
@onready var superkick_original: PackedVector2Array = superkick.polygon.duplicate()


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	rng.randomize()

	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	desativar_hitboxes()
	sprite.flip_h = false
	sprite.play("Idle")


func _physics_process(_delta: float) -> void:
	if estado_atual == Estado.MORTO or estado_atual == Estado.RECEBENDO_DANO:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	if player.get("morto") == true:
		velocity = Vector2.ZERO
		return

	var distancia: float = global_position.distance_to(player.global_position)

	# A detecção acontece apenas uma vez.
	if not combate_iniciado and distancia <= DETECTION_RANGE:
		combate_iniciado = true
		mudar_estado(Estado.PERSEGUINDO)

	match estado_atual:
		Estado.IDLE:
			velocity = Vector2.ZERO

		Estado.PERSEGUINDO:
			olhar_para_player()

			if distancia > ATTACK_RANGE:
				var direcao: Vector2 = global_position.direction_to(player.global_position)
				velocity = direcao * SPEED
			else:
				velocity = Vector2.ZERO
				escolher_ataque()

		Estado.ATACANDO:
			velocity = Vector2.ZERO

	move_and_slide()
	atualizar_animacao()


func mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return

	estado_atual = novo_estado
	print(name, " mudou para: ", Estado.keys()[estado_atual])


func atualizar_animacao() -> void:
	if estado_atual in [Estado.ATACANDO, Estado.RECEBENDO_DANO, Estado.MORTO]:
		return

	if velocity == Vector2.ZERO:
		if sprite.animation != "Idle":
			sprite.play("Idle")
	else:
		if sprite.animation != "Walk":
			sprite.play("Walk")


func olhar_para_player() -> void:
	var diferenca_x: float = player.global_position.x - global_position.x

	if absf(diferenca_x) <= 1.0:
		return

	var olhando_esquerda: bool = diferenca_x < 0

	if sprite.flip_h == olhando_esquerda:
		return

	sprite.flip_h = olhando_esquerda

	var multiplicador: float = -1.0 if olhando_esquerda else 1.0

	punch.position.x = punch_x * multiplicador
	headbutt.position.x = headbutt_x * multiplicador
	superkick.position.x = superkick_x * multiplicador

	if olhando_esquerda:
		punch.polygon = espelhar_poligono(punch_original)
		headbutt.polygon = espelhar_poligono(headbutt_original)
		superkick.polygon = espelhar_poligono(superkick_original)
	else:
		punch.polygon = punch_original
		headbutt.polygon = headbutt_original
		superkick.polygon = superkick_original


func espelhar_poligono(pontos: PackedVector2Array) -> PackedVector2Array:
	var resultado := PackedVector2Array()

	for ponto in pontos:
		resultado.append(Vector2(-ponto.x, ponto.y))

	resultado.reverse()
	return resultado


func escolher_ataque() -> void:
	var sorteio: int = rng.randi_range(0, 2)

	match sorteio:
		0:
			executar_ataque(anim_punch)
		1:
			executar_ataque(anim_headbutt)
		2:
			executar_ataque(anim_superkick)


func executar_ataque(animacao: StringName) -> void:
	if not sprite.sprite_frames.has_animation(animacao):
		push_warning("Animação não encontrada no Brute: " + str(animacao))
		return

	mudar_estado(Estado.ATACANDO)
	velocity = Vector2.ZERO

	alvos_atingidos.clear()
	desativar_hitboxes()

	sprite.play(animacao)


func desativar_hitboxes() -> void:
	punch.set_deferred("disabled", true)
	headbutt.set_deferred("disabled", true)
	superkick.set_deferred("disabled", true)


func configurar_hitbox(animacao: StringName) -> void:
	desativar_hitboxes()

	if animacao == anim_punch:
		dano_ataque = DANO_PUNCH
		punch.set_deferred("disabled", false)

	elif animacao == anim_headbutt:
		dano_ataque = DANO_HEADBUTT
		headbutt.set_deferred("disabled", false)

	elif animacao == anim_superkick:
		dano_ataque = DANO_SUPERKICK
		superkick.set_deferred("disabled", false)


func _on_frame_changed() -> void:
	if estado_atual != Estado.ATACANDO:
		return

	desativar_hitboxes()

	var frame_atual: int = sprite.frame

	if sprite.animation == anim_punch:
		if frame_atual >= punch_inicio and frame_atual <= punch_fim:
			configurar_hitbox(anim_punch)

	elif sprite.animation == anim_headbutt:
		if frame_atual >= headbutt_inicio and frame_atual <= headbutt_fim:
			configurar_hitbox(anim_headbutt)

	elif sprite.animation == anim_superkick:
		if frame_atual >= superkick_inicio and frame_atual <= superkick_fim:
			configurar_hitbox(anim_superkick)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if estado_atual != Estado.ATACANDO:
		return

	if area in alvos_atingidos:
		return

	if not area.is_in_group("player_hurtbox"):
		return

	var protagonista := area.get_parent()

	if protagonista.has_method("receber_dano"):
		alvos_atingidos.append(area)

		var ataque_especial: bool = sprite.animation == anim_superkick
		protagonista.receber_dano(dano_ataque, ataque_especial)


func receber_dano(dano: int) -> void:
	if estado_atual in [Estado.MORTO, Estado.RECEBENDO_DANO]:
		return

	vida_atual = maxi(vida_atual - dano, 0)
	print(name, " vida: ", vida_atual)

	velocity = Vector2.ZERO
	desativar_hitboxes()

	if vida_atual == 0:
		mudar_estado(Estado.MORTO)

		if sprite.sprite_frames.has_animation("Hurt3(knockdown)"):
			sprite.play("Hurt3(knockdown)")
		else:
			queue_free()
	else:
		mudar_estado(Estado.RECEBENDO_DANO)

		if sprite.sprite_frames.has_animation("Hurt1"):
			sprite.play("Hurt1")
		else:
			mudar_estado(Estado.PERSEGUINDO)


func _on_animation_finished() -> void:
	if estado_atual == Estado.ATACANDO:
		desativar_hitboxes()
		mudar_estado(Estado.PERSEGUINDO)

	elif estado_atual == Estado.RECEBENDO_DANO:
		mudar_estado(Estado.PERSEGUINDO)

	elif estado_atual == Estado.MORTO:
		queue_free()

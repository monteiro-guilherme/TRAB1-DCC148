
extends CharacterBody2D

const SPEED: float = 140.0
const DETECTION_RANGE: float = 550.0
const CHASE_RANGE: float = 400.0
const STOP_DISTANCE: float = 75.0
const ATTACK_RANGE: float = 100


const VIDA_MAXIMA: int = 135
var vida_atual: int = VIDA_MAXIMA

const RECUO_DISTANCIA: float = 175.0
const TEMPO_MIN_PREPARACAO: float = 0.5
const TEMPO_MAX_PREPARACAO: float = 2.0
const DISTANCIA_LATERAL: float = 45.0

@onready var hitbox: Area2D = $HitBox

var dano_ataque: int = 0
var alvos_atingidos: Array[Area2D] = []

var rng := RandomNumberGenerator.new()
var tempo_preparacao: float = 0.0
var distancia_recuada: float = 0.0
var direcao_recuo: Vector2 = Vector2.ZERO
var direcao_lateral: float = 1.0
var ataque_acertou: bool = false

enum Estado {
	IDLE,
	OBSERVANDO,
	PERSEGUINDO,
	ATACANDO,
	RECUANDO,
	CIRCULANDO,
	RECEBENDO_DANO,
	MORTO
}
var estado_atual: Estado = Estado.IDLE
var combate_iniciado: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var front_kick_hitbox: CollisionPolygon2D = $HitBox/FrontKick
@onready var super_hitbox: CollisionPolygon2D = $HitBox/Super

@onready var front_kick_hitbox_x: float = front_kick_hitbox.position.x
@onready var super_x: float = super_hitbox.position.x

@onready var front_kick_original: PackedVector2Array = front_kick_hitbox.polygon.duplicate()
@onready var super_original: PackedVector2Array = super_hitbox.polygon.duplicate()

@onready var hurtbox: Area2D = $HurtBox
@onready var hurtbox_polygon: CollisionPolygon2D = $HurtBox/CollisionPolygon2D

@onready var hurtbox_x: float = hurtbox_polygon.position.x
@onready var hurtbox_original: PackedVector2Array = hurtbox_polygon.polygon.duplicate()

var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	sprite.play("Idle")
	rng.randomize()
	sprite.animation_finished.connect(_on_animation_finished)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	sprite.frame_changed.connect(_on_frame_changed)
	desativar_hitboxes()
	sprite.flip_h = false
	front_kick_hitbox.position.x = front_kick_hitbox_x
	super_hitbox.position.x = super_x
	hurtbox_polygon.position.x = hurtbox_x
	hurtbox_polygon.polygon = hurtbox_original
	#Teste de radar
	#print("Bancho encontrou o player: ", player)
	

func olhar_para_player() -> void:
	var diferenca_x: float = player.global_position.x - global_position.x

	if absf(diferenca_x) <= 1.0:
		return

	var olhando_esquerda: bool = diferenca_x < 0

	if sprite.flip_h == olhando_esquerda:
		return

	sprite.flip_h = olhando_esquerda

	var multiplicador: float = -1.0 if olhando_esquerda else 1.0

	front_kick_hitbox.position.x = front_kick_hitbox_x * multiplicador
	super_hitbox.position.x = super_x * multiplicador
	hurtbox_polygon.position.x = hurtbox_x * multiplicador

	if olhando_esquerda:
		front_kick_hitbox.polygon = espelhar_poligono(front_kick_original)
		super_hitbox.polygon = espelhar_poligono(super_original)
		hurtbox_polygon.polygon = espelhar_poligono(hurtbox_original)
	else:
		front_kick_hitbox.polygon = front_kick_original
		super_hitbox.polygon = super_original
		hurtbox_polygon.polygon = espelhar_poligono(hurtbox_original)


func espelhar_poligono(pontos: PackedVector2Array) -> PackedVector2Array:
	var resultado := PackedVector2Array()

	for ponto in pontos:
		resultado.append(Vector2(-ponto.x, ponto.y))

	resultado.reverse()
	return resultado

func mudar_estado(novo_estado: Estado) -> void:
	if estado_atual == novo_estado:
		return

	estado_atual = novo_estado
	print("Bancho mudou para: ", Estado.keys()[estado_atual])

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		atualizar_animacao()
		return
		
	if estado_atual == Estado.RECEBENDO_DANO:
		velocity = Vector2.ZERO
		return
	if estado_atual == Estado.MORTO:
		velocity = Vector2.ZERO
		return
		
	var distancia: float = global_position.distance_to(player.global_position)

	# Quando o combate começa, o Bancho nunca volta ao estado passivo.
	if not combate_iniciado:
		if distancia <= CHASE_RANGE:
			combate_iniciado = true
			mudar_estado(Estado.PERSEGUINDO)
			
		elif distancia <= DETECTION_RANGE:
			mudar_estado(Estado.OBSERVANDO)
		else:
			mudar_estado(Estado.IDLE)

	match estado_atual:
		Estado.IDLE:
			velocity = Vector2.ZERO

		Estado.OBSERVANDO:
			velocity = Vector2.ZERO
			olhar_para_player()

		Estado.PERSEGUINDO:
			olhar_para_player()
			if distancia > STOP_DISTANCE:
				var direcao := global_position.direction_to(player.global_position)
				velocity = direcao * SPEED
			else:
				velocity = Vector2.ZERO
				escolher_ataque()
				
		Estado.ATACANDO:
			velocity = Vector2.ZERO


		Estado.RECUANDO:
			var posicao_anterior := global_position

			velocity = direcao_recuo * SPEED
			move_and_slide()

			distancia_recuada += global_position.distance_to(posicao_anterior)

			if distancia_recuada >= RECUO_DISTANCIA:
				velocity = Vector2.ZERO
				preparar_proximo_ataque()
			atualizar_animacao()
			return


		Estado.CIRCULANDO:
			olhar_para_player()
			tempo_preparacao -= _delta

			velocity = Vector2.ZERO

		_:
			velocity = Vector2.ZERO

	move_and_slide()
	if estado_atual == Estado.CIRCULANDO and tempo_preparacao <= 0.0:
		if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
			escolher_ataque()
		else:
			mudar_estado(Estado.PERSEGUINDO)
	atualizar_animacao()



func atualizar_animacao() -> void:
	if estado_atual in [Estado.ATACANDO, Estado.RECEBENDO_DANO, Estado.MORTO]:
			return
	if velocity == Vector2.ZERO:
		if sprite.animation != "Idle":
			sprite.play("Idle")
	else:
		if sprite.animation != "Walk":
			sprite.play("Walk")

func executar_ataque(animacao: String) -> void:
	mudar_estado(Estado.ATACANDO)
	ataque_acertou = false
	velocity = Vector2.ZERO
	
	print("Iniciando ataque: ", animacao)
	print("Animação existe: ", sprite.sprite_frames.has_animation(animacao))
	
	alvos_atingidos.clear()
	desativar_hitboxes()
	sprite.play(animacao)
	


func receber_dano(dano: int) -> void:
	if estado_atual == Estado.MORTO or estado_atual == Estado.RECEBENDO_DANO:
		return

	vida_atual = maxi(vida_atual - dano, 0)
	print("Vida do Bancho: ", vida_atual)

	velocity = Vector2.ZERO
	desativar_hitboxes()

	if vida_atual == 0:
		mudar_estado(Estado.MORTO)
		sprite.play("Hurt3(knockdown)")
	else:
		mudar_estado(Estado.RECEBENDO_DANO)
		sprite.play("Hurt1")

func _on_frame_changed() -> void:
	if estado_atual != Estado.ATACANDO:
		return

	desativar_hitboxes()

	match sprite.animation:
		"Atk1(kick)":
			if sprite.frame >= 4 and sprite.frame <= 6:
				configurar_hitbox("Atk1(kick)")

		"Atk3(super)":
			if sprite.frame >= 2 and sprite.frame <= 5:
				configurar_hitbox("Atk3(super)")

func preparar_proximo_ataque() -> void:
	tempo_preparacao = rng.randf_range(
		TEMPO_MIN_PREPARACAO,
		TEMPO_MAX_PREPARACAO
	)

	direcao_lateral = -1.0 if rng.randf() < 0.5 else 1.0

	mudar_estado(Estado.CIRCULANDO)

func escolher_ataque() -> void:
	var sorteio := rng.randf()

	if sorteio < 0.6:
		executar_ataque("Atk1(kick)")
	else:
		executar_ataque("Atk3(super)")	

func iniciar_recuo() -> void:
	distancia_recuada = 0.0

	direcao_recuo = (
		global_position - player.global_position
	).normalized()

	mudar_estado(Estado.RECUANDO)

func _on_animation_finished() -> void:
	print("Animação finalizada: ", sprite.animation)

	if estado_atual == Estado.ATACANDO:
		if sprite.animation == "Atk1(kick)" or sprite.animation == "Atk3(super)":
			desativar_hitboxes()
			iniciar_recuo()
	elif estado_atual == Estado.RECEBENDO_DANO:
		mudar_estado(Estado.PERSEGUINDO)
	elif estado_atual == Estado.MORTO:
		queue_free()


func desativar_hitboxes() -> void:
	front_kick_hitbox.set_deferred("disabled", true)
	super_hitbox.set_deferred("disabled", true)


func configurar_hitbox(animacao: String) -> void:
	desativar_hitboxes()

	match animacao:
		"Atk1(kick)":
			dano_ataque = 15
			front_kick_hitbox.set_deferred("disabled", false)

		"Atk3(super)":
			dano_ataque = 30
			super_hitbox.set_deferred("disabled", false)

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("BANCHO HITBOX detectou: ", area.name)
	print("Grupo player_hurtbox: ", area.is_in_group("player_hurtbox"))
	print("Estado do Bancho: ", Estado.keys()[estado_atual])
	if estado_atual != Estado.ATACANDO:
		return

	if area in alvos_atingidos:
		return

	if not area.is_in_group("player_hurtbox"):
		return

	var protagonista := area.get_parent()

	if protagonista.has_method("receber_dano"):
		alvos_atingidos.append(area)

		var especial: bool = sprite.animation == "Atk3(super)"
		protagonista.receber_dano(dano_ataque, especial)

		ataque_acertou = true

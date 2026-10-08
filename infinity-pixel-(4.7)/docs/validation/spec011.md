# Spec 011 — Registro de validação (2026-10-04)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

## Ponto de partida (auditoria)

- `Player.take_damage` só imprimia "sem HP definido ainda": o Player já era
  `damageable` e recebia os golpes, mas não havia vida, morte nem HUD.
- A única fonte de dano é `wild_dino.gd` (WildDino e Carnotauro):
  - 15 de dano, ×1,3 à noite (19,5);
  - cooldown de 1,0 s e alcance de 2 m;
  - alvo buscado nos grupos `player`/`domesticated` a cada 0,15 s.

  Esses valores **não foram alterados**.
- O Player nasce em (0, 1, 0) na `prototype_area.tscn`.
- A HUD (`main.gd`) consultava o refúgio a cada quadro em `_process`.
- Nenhum outro inimigo, projétil ou armadilha causa dano.

## Resultados automatizados (execução final)

| Execução | Resultado |
|---|---|
| `tests/player_health.tscn` (Spec 011), headless / janela GL | 47/47 / 47/47 |
| `tests/player_facing.tscn` (orientação visual), headless / janela | 37/37 / 37/37 |
| `tests/physics_contracts.tscn` (Spec 009), headless / janela | 23/23 / 23/23 |
| `tests/navigation_contracts.tscn` (Spec 010), headless / janela | 38/38 / 38/38 |
| `tests/acceptance.tscn`, headless / janela | 33/33 / 36/36 |
| Cena principal, headless, 120 quadros | sem erros nem warnings de script |

Os relatórios JSON estão em `spec011-evidence/`. A suíte acceptance rodou com
`--evidence-dir` fora do projeto, para não sobrescrever `docs/ac1/evidence`.
Os scripts de regressão das Specs 007/008 citados em `spec010.md` ficavam
fora do projeto e não estavam disponíveis. Os pontos deles (câmera não gira,
WASD relativo, clique em UI, amanhecer sem modal) estão cobertos por
acceptance, physics, facing e pela suíte da Spec 011.

### O que a suíte da Spec 011 verifica (cena real, IA e HUD reais)

- **HP e contrato:** 100/100 no início; segue `damageable`/`take_damage`;
  15 → 85; nunca abaixo de 0; 0, negativo, NaN e infinito ignorados sem
  abrir a janela de invulnerabilidade.
- **Invulnerabilidade:** hits a 0 s e 0,3 s ignorados; a 0,7 s, aplicado;
  três hits no mesmo quadro aplicam um só.
- **Dano real:** um WildDino com a IA real causa múltiplos de 15 de dia.
- **Morte:**
  - `died` uma única vez, mesmo com mais dano ou outra chamada de `_die`;
  - o canal de E em andamento é cancelado e o alvo continua selvagem;
  - morto não anda, não ataca e não domestica com E segurado;
  - sai do grupo `player`, fica com camada 0 e um inimigo de onda ao lado
    troca de alvo;
  - nada de modal ou pausa, e o aviso aparece.
- **Respawn:**
  - 2,00 s de tempo de jogo, no `PlayerSpawn`, com 100/100;
  - grupo e camada 2 de volta;
  - HUD atualizada e aviso fechado;
  - não corre com o jogo pausado e conclui depois de retomar.
- **Proteção:** dano a 1,0 s ignorado; a 1,6 s, aplicado.
- **Depois do respawn:**
  - anda e o Visual olha para o movimento;
  - ataca com 20 de dano;
  - domestica (20/80 preservado);
  - Carnotauro continua não domesticável;
  - a câmera não gira com o Player.
- **Mundo:**
  - noite vencida volta ao dia sem pausar;
  - o refúgio recebe dano e a HUD mostra "REFÚGIO  70 / 100";
  - refúgio em 0 abre "O refúgio caiu".

## Problemas encontrados durante a validação

- O primeiro teste do tempo de respawn media relógio de parede. Com
  `--fixed-fps 60` em headless o jogo roda mais rápido que o tempo real, e o
  resultado deu 0,21 s. Passou a medir quadros de física (tempo de jogo):
  2,00 s.
- Na janela, a checagem do texto "REFÚGIO" logo após o início falhou. O
  texto do refúgio é atualizado em `_process`, e o teste só esperava quadros
  de física. O teste passou a esperar dois quadros de processo. Nada mudou
  no jogo.

## Limites conhecidos

- O teste automatizado não avalia a sensação: se 100 HP e 0,6 s são justos,
  se o pisca da proteção é legível, se o aviso é notado.
- Aliados que seguiam o Player ficam perto do ponto onde ele morreu até o
  respawn, e depois voltam a segui-lo.
- Um golpe de dino já em andamento no intervalo de até 0,15 s antes da troca
  de alvo é ignorado pelo `take_damage` (morto), sem efeito visível.
- O respawn é no ponto inicial (corredor central), não no refúgio. O aviso
  diz "ponto inicial".

## Reproduzir

```powershell
godot --headless --path . --fixed-fps 60 res://tests/player_health.tscn
godot --path . --rendering-method gl_compatibility res://tests/player_health.tscn
```

Grava `user://spec011-health.json`; aceita `-- --report=<arquivo>`.

## TESTE MANUAL NECESSÁRIO

- A — Dano: começar em JOGADOR 100/100, deixar um dino atacar, HP e HUD
  caem.
- B — Invulnerabilidade: cercado por vários dinos, sem vários hits no mesmo
  instante.
- C — Morte: HP 0, sem andar/atacar/domesticar, aviso discreto.
- D — Respawn: ~2 s, volta ao ponto inicial com 100/100.
- E — Proteção: ~1,5 s piscando, sem dano, para sair de perto.
- F — Refúgio: inimigos destroem o refúgio → "O refúgio caiu".
- G — Depois do respawn: andar, mirar, atacar, domesticar, câmera.

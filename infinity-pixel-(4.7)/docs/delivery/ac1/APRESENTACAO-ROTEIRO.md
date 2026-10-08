# Apresentação AC1 — roteiro

17 slides. Capturas reais, algumas com preparação controlada; nenhuma ilustração substitui gameplay.

## 1. Jadefall: Guardiões do Refúgio

AC1 • Protótipo Jogo
Inity Pixel · FIAP School
07 de outubro de 2026

**Fala sugerida:** Capa. Apresentar o nome do jogo Jadefall: Guardiões do Refúgio e do estúdio Inity Pixel. Captura real do menu atual; Godot 4.6.2.

## 2. Conceito do jogo

Ação 3D + defesa de território

Explorar um vale, formar aliados e preparar o Refúgio para a noite.

Eliminar ou domesticar muda a estratégia.

**Fala sugerida:** O jogador controla diretamente o Guardião e prepara defesas indiretas. Público proposto: quem gosta de exploração, criaturas e estratégia. Não há classificação indicativa formal.

## 3. História do vale

Uma comunidade protege seu Refúgio de criaturas noturnas.

O Guardião transforma ameaças em companheiros.

Lore proposta; aprovação do grupo pendente.

**Fala sugerida:** História preservada da proposta existente. Não há campanha, diálogos ou nome próprio aprovado. Cristal e estandartes comunicam abrigo; jade comunica vínculo.

## 4. Core loop

Explorar e coletar
↓
Combater ou domesticar
↓
Recuperar áreas e preparar defesas
↓
Sobreviver à noite e repetir

**Fala sugerida:** A sequência representa possibilidades, não quests obrigatórias. Dia automático de 90 s. Neutralizar a onda inteira causa amanhecer. Destruir a base encerra sessão.

## 5. Gameplay e controles

WASD move · mouse mira
Clique ataca e coleta
E domestica / recupera marco
F posiciona aliado de dia
C constrói / melhora torre
I inventário · B construção
R gira · H cura · Esc pausa

**Fala sugerida:** Mouse não gira a câmera. E por 2 s, H por 3 s. Clique esquerdo confirma construção; direito cancela. Esc fecha painel antes de pausar. T e N são debug desativado.

## 6. Personagem e criaturas

Guardião com machado, túnica e lenço jade.

Dino selvagem pode virar aliado.

Carnotauro existe como variante; não compõe a onda padrão.

**Fala sugerida:** Modelos reais em scenes/visuals. Capturas de apresentação com câmera própria. WildDino: 80 HP. Carnotauro não domesticável.

## 7. Level design

Uma arena de 48 × 52 m

Refúgio e construção ao sul.
Bosque a oeste; rochas a leste.
Ruína e corredor ao norte.

Três rotas atacam a base.

**Fala sugerida:** Vista ortográfica inclinada do mapa real. Sul/Refúgio fica em cima da imagem e norte/ruína embaixo; oeste à esquerda. Marcos em (-14,13) e (13,16). Seis slots de torre.

## 8. Coleta e construção

Madeira e pedra vêm de recursos atacáveis.

Inventário mostra materiais e receitas.

Fogueira cura; Armadilha protege rotas. Construção só de dia.

**Fala sugerida:** Árvores 30 HP rendem 10 madeira; pedras 45 HP rendem 6 pedra. Fogueira custa 20/12; Armadilha 15/6. Materiais não são PD. Fantasma valida posição antes de cobrar.

## 9. Combate e domesticação

Golpe: 15 de dano.
Quatro golpes deixam 20/80 HP.

Segure E por 2 s para converter.
O aliado volta com 80/80 HP.

F alterna seguir / ficar de dia.

**Fala sugerida:** Domesticação exige HP até 30% e distância de até 3 m. Guardião domesticado também libera marco. A captura usa preparação controlada da cena de demonstração.

## 10. Dia e noite

90 s para preparar.

A noite traz ondas crescentes.

O relógio para em 05:59 se ainda houver ameaças.

Só vencer a onda traz o novo dia.

**Fala sugerida:** Relógio noturno percorre 45 s, mas não vence sozinho. Primeira onda: 3 inimigos; +1 a cada noite. Luz e céu acompanham o relógio; inimigos noturnos ganham dano e velocidade.

## 11. Torres e defesa

40 Pontos de Defesa iniciais.
30 PD constroem uma torre.

Três níveis de torre; seis pontos fixos.

Aliados e armadilhas complementam a defesa.

**Fala sugerida:** PD são ganhos por morte de inimigos de onda, 15 cada. Domesticar neutraliza mas não dá essa recompensa. Armadilha: 15 dano e 3 cargas; limite 3 ativas.

## 12. Interface e sobrevivência

HP do jogador e Refúgio
Dia, hora e progresso da onda
Madeira, pedra e PD
Territórios recuperados

Morte: respawn em 2 s.
Base destruída: derrota.

**Fala sugerida:** HUD mostra valores reais. Jogador tem 100 HP; proteção pós-respawn 1,5 s. Refúgio tem 100 HP. Pausa, reinício e retorno ao menu preservam contrato de nova sessão.

## 13. Moodboard do projeto

Low-poly · materiais foscos
Verdes naturais · jade de vínculo
Âmbar de foco · noite fria
Pedra, madeira, cristal e luz local

**Fala sugerida:** Referências internas: vegetação e pedras do mapa real; ciclo de luz; modelos low-poly e UI. Não foram usadas obras externas como colagem.

## 14. Identidade visual

ESTÚDIO  Inity Pixel
JOGO  Jadefall: Guardiões do Refúgio

Pixels na marca do estúdio.
Cristais e título âmbar/jade no jogo.

Grafias distintas preservadas.

**Fala sugerida:** Logo do jogo derivado do menu atual. O antigo logo Tower Defense Dino foi preservado como histórico e não deve ser usado nesta entrega. Paleta e uso em IDENTIDADE.md.

## 15. Monetização proposta

AC1 gratuita

Versão futura por compra única, com demonstração gratuita.

Hipótese: R$ 19,90.
Sem vender vantagens, vidas ou recursos.

**Fala sugerida:** Preço é hipótese escolar, não pesquisa de mercado nem preço publicado. Revisar após definir produto/custos. Não existe loja no protótipo.

## 16. Estado atual

Core loop implementado na Godot.
Menu, HUD, arte e trilha existentes.
Territórios e construções funcionais.

Regressões executadas; resultados no relatório.
Spec 015 ainda requer playtest do grupo.

**Fala sugerida:** Referência de testes: TESTES.md e evidence. Automação verifica regras, não aprovação humana de dificuldade/áudio. Captura territorial preparada pela cena de demonstração.

## 17. Entrega e próximos passos

Conferir lore, identidade e áudio.
Definir responsáveis e Game Designer.
Anexar materiais nos cards do Trello.
Publicar esta versão no GitHub, após revisão.

Game Designer envia o link do quadro.

**Fala sugerida:** Equipe documentada: Murilo Cassetti, Heitor Crispim, Pedro Ferreira, Juan Carlos. TRELLO-CHECKLIST.md relaciona arquivos e cards. Prazo original 04/10/2026; confirmar aceitação do envio. Nada foi publicado automaticamente.

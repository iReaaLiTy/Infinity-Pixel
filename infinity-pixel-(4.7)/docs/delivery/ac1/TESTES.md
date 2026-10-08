# Validação da entrega

Executado em 07/10/2026 com Godot 4.6.2, renderer GL Compatibility, Windows. O runner criado para esta entrega é [tools/test_ac1.ps1](../../../tools/test_ac1.ps1); relatórios e stdout estão em [evidence](evidence/).

## Resultado headless

Passaram **14 suítes**: `territory` 68/68; `sky_cycle` 45/45; `build_heal` 68/68; `healing_actions` 7/7; `combat_collect` 46/46; `defense_economy` 35/35; `day_cycle` 43/43; `day_cycle_real` 15/15; `world_layout` 57/57; `player_health` 47/47; `player_facing` 37/37; `physics_contracts` 23/23; `navigation_contracts` 38/38; `acceptance` 33/33.

## Resultado com renderização

`main_menu` 27/27; `territory` 68/68; `sky_cycle` 45/45; `build_heal` 68/68; `healing_actions` 7/7; `combat_collect` 46/46. Além disso, as cenas `map_showcase`, `hud_showcase` e `sky_showcase` geraram capturas reais; `map_showcase`, `hud_showcase`, `territory_showcase`, `build_showcase` e `sky_showcase` encerraram com código 0.

Os arquivos de stderr registram avisos de `ObjectDB instances leaked` e, em algumas suítes, um recurso ainda em uso durante o desligamento. Não houve `SCRIPT ERROR`, `SHADER ERROR`, `Parse Error`, suíte falha ou `FAIL:`. São avisos de teardown dos fixtures de teste e ficam preservados para transparência; não foram mascarados.

## Limites

Os testes automatizados verificam contratos e fluxos preparados. Não substituem uma partida livre, a aprovação de dificuldade/balanceamento, a audição da música, revisão de lore/identidade ou confirmação de acesso aos anexos por outra pessoa. A Spec 015 tem automação aprovada, mas o próprio registro ainda pede playtest manual do grupo.

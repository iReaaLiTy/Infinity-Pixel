# Core loop e roteiro de demonstração

Explorar → coletar → combater/domesticar → recuperar áreas → preparar defesas → enfrentar noite → amanhecer → repetir. Todas essas possibilidades existem; não há quest impondo essa ordem.

1. Abrir o projeto correto na Godot 4.6.2 e executar F5. Clicar JOGAR.
2. Mostrar HUD: jogador/Refúgio 100 HP, Dia 1, 40 PD e territórios 1/3.
3. WASD e mouse para mover/mirar. Atacar árvores do oeste/pedras do leste; I mostra materiais.
4. Aproximar de um dos pontos defensivos e C para construir uma torre por 30 PD.
5. Contra um dino isolado, quatro golpes de 15 deixam 20/80. Segurar E por 2 s dentro de 3 m. F posiciona o aliado de dia. Evitar continuar atacando até matá-lo.
6. Após neutralizar guardião, aproximar do marco e segurar E por 2 s de dia. Mostrar contador e área recuperada.
7. Com 20 madeiras/12 pedras, B e receita de Fogueira; posicionar em área válida, R gira, clique confirma. H por 3 s cura se ferido. Armadilha custa 15/6 e exige rota válida.
8. Ao fim dos 90 s diurnos começa a onda. Defender o Refúgio com jogador, aliados e torre. Neutralizar todos gera amanhecer; o relógio sozinho não vence a onda.
9. Esc para pausa; mostrar reinício e retorno ao menu. Morte do jogador respawna em 2 s; perda do Refúgio é derrota.

Uma primeira partida não precisa exibir todas as construções: o dia é curto. Ensaiar várias sessões ou usar as capturas de cada sistema como complemento. N não avança noite em jogo normal. Demonstrações automatizadas usam preparação controlada e não medem dificuldade humana.

Resultados de regressão e cobertura em [TESTES.md](TESTES.md).

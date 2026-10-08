# Trilha principal e áudio

Trilha existente: **Passos do Refúgio**, 112 segundos. Arquivo principal: [refugio_principal.wav](../../../assets/audio/refugio_principal.wav). Fonte original procedural: [compose_score.py](../../../tools/compose_score.py).

- [Mixagem calma](../../../assets/audio/refugio_calm.wav): menu e gameplay diurno.
- [Mixagem de combate](../../../assets/audio/refugio_combat.wav): noite.
- `victory.wav`, `defeat.wav`, `strike.wav`, `bond.wav`: sinais e efeitos, não substituem a música principal.

`scenes/ui/audio_director.gd` cria players de música, sinal e efeito e buses Music/SFX. Usa transições, loop e volume/mudo; a pausa atenua a música. O tema principal é referência de composição, enquanto calma/combate são os arquivos efetivamente alternados no runtime.

Proveniência documentada em `docs/ac1/ASSETS.md`: composição sintetizada sem samples externos, PCM estéreo 16-bit a 32 kHz. Nenhuma música foi baixada/adicionada nesta revisão. Testes de runtime verificam estados e reprodução; não equivalem à audição humana. Ouvir a faixa inteira e a transição/volume durante combate antes de apresentar.

Anexar o WAV principal e este documento ao card da trilha. As mixagens já ficam no projeto, sem duplicação na entrega.

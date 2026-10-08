import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const runtime = 'C:/Users/ppfti/.cache/codex-runtimes/codex-primary-runtime/dependencies';
const skill = 'C:/Users/ppfti/.codex/plugins/cache/openai-primary-runtime/presentations/26.909.12148/skills/presentations';
const { Presentation, PresentationFile } = await import(pathToFileURL(runtime + '/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs'));
const { resolvePresentationFont, finalizePresentation } = await import(pathToFileURL(skill + '/container_tools/artifact_tool_utils.mjs'));
const root = process.cwd();
const out = path.join(root, 'docs/delivery/ac1');
const build = path.join(out, '.build');
const previews = path.join(out, 'slides');
await fs.mkdir(build, {recursive:true});
await fs.mkdir(previews, {recursive:true});
const family = resolvePresentationFont({fontFamily:'Arial'});
const deck = Presentation.create({slideSize:{width:1280,height:720}});
const ev = 'docs/delivery/ac1/evidence/';
const slides = [
 ['Jadefall: Guardiões do Refúgio','AC1 • Protótipo Jogo\nInity Pixel · FIAP School\n07 de outubro de 2026', ev+'main_menu_Windows/menu_1280x720.png','Capa. Apresentar o nome do jogo Jadefall: Guardiões do Refúgio e do estúdio Inity Pixel. Captura real do menu atual; Godot 4.6.2.'],
 ['Conceito do jogo','Ação 3D + defesa de território\n\nExplorar um vale, formar aliados e preparar o Refúgio para a noite.\n\nEliminar ou domesticar muda a estratégia.', ev+'map_showcase_Windows/05_creature_glade.png','O jogador controla diretamente o Guardião e prepara defesas indiretas. Público proposto: quem gosta de exploração, criaturas e estratégia. Não há classificação indicativa formal.'],
 ['História do vale','Uma comunidade protege seu Refúgio de criaturas noturnas.\n\nO Guardião transforma ameaças em companheiros.\n\nLore proposta; aprovação do grupo pendente.',ev+'map_showcase_Windows/01_spawn.png','História preservada da proposta existente. Não há campanha, diálogos ou nome próprio aprovado. Cristal e estandartes comunicam abrigo; jade comunica vínculo.'],
 ['Core loop','Explorar e coletar\n↓\nCombater ou domesticar\n↓\nRecuperar áreas e preparar defesas\n↓\nSobreviver à noite e repetir',ev+'territory_showcase_Windows/07_oeste_controlada_hud_2de3.png','A sequência representa possibilidades, não quests obrigatórias. Dia automático de 90 s. Neutralizar a onda inteira causa amanhecer. Destruir a base encerra sessão.'],
 ['Gameplay e controles','WASD move · mouse mira\nClique ataca e coleta\nE domestica / recupera marco\nF posiciona aliado de dia\nC constrói / melhora torre\nI inventário · B construção\nR gira · H cura · Esc pausa',ev+'main_menu_Windows/menu_controles.png','Mouse não gira a câmera. E por 2 s, H por 3 s. Clique esquerdo confirma construção; direito cancela. Esc fecha painel antes de pausar. T e N são debug desativado.'],
 ['Personagem e criaturas','Guardião com machado, túnica e lenço jade.\n\nDino selvagem pode virar aliado.\n\nCarnotauro existe como variante; não compõe a onda padrão.',null,'Modelos reais em scenes/visuals. Capturas de apresentação com câmera própria. WildDino: 80 HP. Carnotauro não domesticável.'],
 ['Level design','Uma arena de 48 × 52 m\n\nRefúgio e construção ao sul.\nBosque a oeste; rochas a leste.\nRuína e corredor ao norte.\n\nTrês rotas atacam a base.',ev+'map_showcase_Windows/11_overview_diagnostic.png','Vista ortográfica inclinada do mapa real. Sul/Refúgio fica em cima da imagem e norte/ruína embaixo; oeste à esquerda. Marcos em (-14,13) e (13,16). Seis slots de torre.'],
 ['Coleta e construção','Madeira e pedra vêm de recursos atacáveis.\n\nInventário mostra materiais e receitas.\n\nFogueira cura; Armadilha protege rotas. Construção só de dia.',ev+'build_showcase_Windows/01_inventario.png','Árvores 30 HP rendem 10 madeira; pedras 45 HP rendem 6 pedra. Fogueira custa 20/12; Armadilha 15/6. Materiais não são PD. Fantasma valida posição antes de cobrar.'],
 ['Combate e domesticação','Golpe: 15 de dano.\nQuatro golpes deixam 20/80 HP.\n\nSegure E por 2 s para converter.\nO aliado volta com 80/80 HP.\n\nF alterna seguir / ficar de dia.',ev+'territory_showcase_Windows/11_leste_pronto_aliado.png','Domesticação exige HP até 30% e distância de até 3 m. Guardião domesticado também libera marco. A captura usa preparação controlada da cena de demonstração.'],
 ['Dia e noite','90 s para preparar.\n\nA noite traz ondas crescentes.\n\nO relógio para em 05:59 se ainda houver ameaças.\n\nSó vencer a onda traz o novo dia.',ev+'sky_showcase_Windows/08_2100_noite.png','Relógio noturno percorre 45 s, mas não vence sozinho. Primeira onda: 3 inimigos; +1 a cada noite. Luz e céu acompanham o relógio; inimigos noturnos ganham dano e velocidade.'],
 ['Torres e defesa','40 Pontos de Defesa iniciais.\n30 PD constroem uma torre.\n\nTrês níveis de torre; seis pontos fixos.\n\nAliados e armadilhas complementam a defesa.',ev+'build_showcase_Windows/10_armadilha_ativada_noite.png','PD são ganhos por morte de inimigos de onda, 15 cada. Domesticar neutraliza mas não dá essa recompensa. Armadilha: 15 dano e 3 cargas; limite 3 ativas.'],
 ['Interface e sobrevivência','HP do jogador e Refúgio\nDia, hora e progresso da onda\nMadeira, pedra e PD\nTerritórios recuperados\n\nMorte: respawn em 2 s.\nBase destruída: derrota.',ev+'hud_showcase_Windows/hud_atual_dia_1920.png','HUD mostra valores reais. Jogador tem 100 HP; proteção pós-respawn 1,5 s. Refúgio tem 100 HP. Pausa, reinício e retorno ao menu preservam contrato de nova sessão.'],
 ['Moodboard do projeto','Low-poly · materiais foscos\nVerdes naturais · jade de vínculo\nÂmbar de foco · noite fria\nPedra, madeira, cristal e luz local',null,'Referências internas: vegetação e pedras do mapa real; ciclo de luz; modelos low-poly e UI. Não foram usadas obras externas como colagem.'],
 ['Identidade visual','ESTÚDIO  Inity Pixel\nJOGO  Jadefall: Guardiões do Refúgio\n\nPixels na marca do estúdio.\nCristais e título âmbar/jade no jogo.\n\nGrafias distintas preservadas.',null,'Logo do jogo derivado do menu atual. O antigo logo Tower Defense Dino foi preservado como histórico e não deve ser usado nesta entrega. Paleta e uso em IDENTIDADE.md.'],
 ['Monetização proposta','AC1 gratuita\n\nVersão futura por compra única, com demonstração gratuita.\n\nHipótese: R$ 19,90.\nSem vender vantagens, vidas ou recursos.',null,'Preço é hipótese escolar, não pesquisa de mercado nem preço publicado. Revisar após definir produto/custos. Não existe loja no protótipo.'],
 ['Estado atual','Core loop implementado na Godot.\nMenu, HUD, arte e trilha existentes.\nTerritórios e construções funcionais.\n\nRegressões executadas; resultados no relatório.\nSpec 015 ainda requer playtest do grupo.',ev+'territory_showcase_Windows/12_leste_recuperada_hud_3de3.png','Referência de testes: TESTES.md e evidence. Automação verifica regras, não aprovação humana de dificuldade/áudio. Captura territorial preparada pela cena de demonstração.'],
 ['Entrega e próximos passos','Conferir lore, identidade e áudio.\nDefinir responsáveis e Game Designer.\nAnexar materiais nos cards do Trello.\nPublicar esta versão no GitHub, após revisão.\n\nGame Designer envia o link do quadro.',null,'Equipe documentada: Murilo Cassetti, Heitor Crispim, Pedro Ferreira, Juan Carlos. TRELLO-CHECKLIST.md relaciona arquivos e cards. Prazo original 04/10/2026; confirmar aceitação do envio. Nada foi publicado automaticamente.'],
];
function text(slide, str, x,y,w,h,size=29,color='#F2E8CE',bold=false){
 const s=slide.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
 s.text=str; s.text.style={typeface:family,fontSize:size,color,bold,autoFit:'none'}; return s;
}
async function pic(slide, rel,x,y,w,h){const bytes=await fs.readFile(path.join(root,rel));slide.images.add({blob:bytes,contentType:rel.endsWith('.svg')?'image/svg+xml':'image/png',alt:rel,fit:'contain',position:{left:x,top:y,width:w,height:h}});}
for(let i=0;i<slides.length;i++){
 const [title,body,img,notes]=slides[i]; const s=deck.slides.add();s.background.fill='#102B2A';
 text(s,'INITY PIXEL  /  AC1',52,28,700,30,18,'#69BE9B',true);
 text(s,title,52,76,1160,90,i===0?58:44,'#F2E8CE',true);
 text(s,body,52,184,img||[5,12,13].includes(i)?420:1120,440,i===0?30:28);
 if(img) await pic(s,img,505,182,725,430);
 if(i===5){await pic(s,ev+'art/guardian_frente.png',505,168,345,250);await pic(s,ev+'art/dino_lateral.png',875,168,345,250);await pic(s,ev+'art/carno_lateral.png',685,402,345,210);text(s,'Guardião',550,406,270,30,18,'#69BE9B');text(s,'Dino selvagem',925,406,290,30,18,'#69BE9B');text(s,'Carnotauro • variante',740,609,460,30,18,'#69BE9B');}
 if(i===12){await pic(s,ev+'map_showcase_Windows/06_woodland.png',505,180,345,195);await pic(s,ev+'map_showcase_Windows/07_stone_heath.png',875,180,345,195);await pic(s,ev+'sky_showcase_Windows/05_1730_por_do_sol.png',505,400,345,195);await pic(s,ev+'territory_showcase_Windows/14_oeste_noite_fogueira.png',875,400,345,195);}
 if(i===13){await pic(s,'docs/ac1/assets/logo_inity_pixel.png',520,190,650,145);await pic(s,'docs/delivery/ac1/logo-infinity-pixel.svg',520,360,650,195);}
 if(i===14){text(s,'COMPRA ÚNICA',55,532,1110,85,50,'#E7AE58',true);}
 text(s,'PROTÓTIPO ACADÊMICO  •  GODOT 4.6.2',52,667,1050,26,16,'#69BE9B');text(s,String(i+1).padStart(2,'0'),1165,667,65,26,16,'#69BE9B');
 s.speakerNotes.textFrame.setText(notes+'\nFonte: docs/ac1/GDD_AC1.md; '+(img||'assets do próprio projeto')+'. Código, modelos e música: produção assistida por IA conforme créditos existentes.');
 const png=await deck.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(previews,`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
 console.log('Rendered slide '+(i+1));
}
await fs.writeFile(path.join(out,'APRESENTACAO-ROTEIRO.md'),'# Apresentação AC1 — roteiro\n\n17 slides. Capturas reais, algumas com preparação controlada; nenhuma ilustração substitui gameplay.\n\n'+slides.map((s,i)=>`## ${i+1}. ${s[0]}\n\n${s[1]}\n\n**Fala sugerida:** ${s[3]}\n`).join('\n'));
const candidate=path.join(build,'candidate.pptx');await(await PresentationFile.exportPptx(deck)).save(candidate);
const result=await finalizePresentation({workspaceDir:root,candidatePath:candidate,finalPath:path.join(out,'Infinity-Pixel-AC1.pptx'),pythonExecutable:runtime+'/python/python.exe',integrityValidatorPath:skill+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:skill+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit'],explicitTotalSlideCount:17,requiredNativeTableOwnerSlides:[],requiredNativeChartOwnerSlides:[],fontPolicy:{basis:'design',families:[family]},verifyArtifactToolImport:true,receiptPath:path.join(build,'validation.json')});
console.log(JSON.stringify(result));


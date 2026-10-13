import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const workspaceDir = "C:/Users/ppfti/OneDrive/Desktop/TDnovo/Infinity-Pixel/infinity-pixel-(4.7)";
const SKILL_DIR = "C:/Users/ppfti/.codex/plugins/cache/openai-primary-runtime/presentations/26.1011.11113/skills/presentations";
const RUNTIME_PYTHON = "C:/Users/ppfti/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe";
const artifactModule = "C:/Users/ppfti/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";
const { Presentation, PresentationFile } = await import(pathToFileURL(artifactModule).href);
const { finalizePresentation } = await import(pathToFileURL(path.join(SKILL_DIR, "container_tools/artifact_tool_utils.mjs")).href);

const buildDir = path.join(workspaceDir, ".codex-build", "batata-slides");
const previewDir = path.join(buildDir, "previews");
const outputDir = path.join(workspaceDir, "output", "presentation");
const finalPath = path.join(outputDir, "Pilha_de_Batata_Apresentacao_pronta.pptx");
const heroPath = path.join(workspaceDir, "assets", "presentation", "pilha-batata-capa.png");

const W = 1280;
const H = 720;
const NAVY = "#0A2235";
const NAVY2 = "#123B52";
const TEAL = "#167C80";
const TEAL_LIGHT = "#DDF2EF";
const COPPER = "#B9683A";
const ZINC = "#AAB5BE";
const CREAM = "#FFF9EE";
const GOLD = "#F2B84B";
const RED = "#DE4A4A";
const INK = "#132434";
const MUTED = "#596C7B";
const PALE = "#EDF4F5";
const WHITE = "#FFFFFF";
const FONT = "Arial";

async function blobBytes(filePath) {
  const bytes = await fs.readFile(filePath);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

async function writeBlob(filePath, blob) {
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

function addShape(slide, geometry, position, fill = "none", line = "none", radius) {
  const spec = {
    geometry,
    position,
    fill,
    line: line === "none" ? { style: "solid", fill: "none", width: 0 } : line,
  };
  if (radius) spec.borderRadius = radius;
  return slide.shapes.add(spec);
}

function addText(slide, text, position, opts = {}) {
  const box = addShape(slide, "textbox", position, opts.fill ?? "none", opts.line ?? "none", opts.radius);
  box.text = text;
  box.text.style = {
    typeface: opts.fontFamily ?? FONT,
    fontSize: opts.fontSize ?? 24,
    bold: opts.bold ?? false,
    color: opts.color ?? INK,
    alignment: opts.align ?? "left",
    verticalAlignment: opts.valign ?? "top",
    autoFit: opts.autoFit ?? "none",
  };
  return box;
}

function addTitle(slide, title, number) {
  addShape(slide, "rect", { left: 0, top: 0, width: 18, height: H }, TEAL, "none");
  addText(slide, title, { left: 64, top: 42, width: 980, height: 58 }, {
    fontSize: 36, bold: true, color: NAVY,
  });
  addText(slide, String(number).padStart(2, "0"), { left: 1138, top: 48, width: 76, height: 36 }, {
    fontSize: 18, bold: true, color: TEAL, align: "right",
  });
  addShape(slide, "rect", { left: 64, top: 110, width: 1150, height: 2 }, TEAL_LIGHT, "none");
}

function addDarkTitle(slide, title, number) {
  addShape(slide, "rect", { left: 0, top: 0, width: 18, height: H }, TEAL, "none");
  addText(slide, title, { left: 64, top: 42, width: 980, height: 58 }, {
    fontSize: 36, bold: true, color: WHITE,
  });
  addText(slide, String(number).padStart(2, "0"), { left: 1138, top: 48, width: 76, height: 36 }, {
    fontSize: 18, bold: true, color: TEAL, align: "right",
  });
  addShape(slide, "rect", { left: 64, top: 110, width: 1150, height: 2 }, "#2C596B", "none");
}

function addFooter(slide, text = "Trabalho trimestral de Química") {
  addText(slide, text, { left: 64, top: 684, width: 520, height: 20 }, {
    fontSize: 10, color: MUTED,
  });
}

function addPhotoPlaceholder(slide, label, position, caption = "Substitua por uma foto do grupo") {
  addShape(slide, "roundRect", position, "#F5FAFA", { style: "solid", fill: "#76A9AA", width: 2 }, "rounded-xl");
  addText(slide, label, {
    left: position.left + 24, top: position.top + position.height / 2 - 30,
    width: position.width - 48, height: 36,
  }, { fontSize: 18, bold: true, color: TEAL, align: "center", valign: "middle" });
  addText(slide, caption, {
    left: position.left + 22, top: position.top + position.height / 2 + 12,
    width: position.width - 44, height: 28,
  }, { fontSize: 12, color: MUTED, align: "center" });
}

function addSectionLabel(slide, text, x, y, width = 320) {
  addText(slide, text.toUpperCase(), { left: x, top: y, width, height: 26 }, {
    fontSize: 13, bold: true, color: TEAL,
  });
}

function addNumberedItem(slide, number, title, body, x, y, width) {
  addShape(slide, "ellipse", { left: x, top: y + 3, width: 34, height: 34 }, TEAL, "none");
  addText(slide, String(number), { left: x, top: y + 6, width: 34, height: 25 }, {
    fontSize: 15, bold: true, color: WHITE, align: "center", valign: "middle",
  });
  addText(slide, title, { left: x + 50, top: y, width: width - 50, height: 28 }, {
    fontSize: 18, bold: true, color: NAVY,
  });
  addText(slide, body, { left: x + 50, top: y + 31, width: width - 50, height: 50 }, {
    fontSize: 14, color: MUTED,
  });
}

function addElectrode(slide, x, y, label) {
  addShape(slide, "roundRect", { left: x, top: y, width: 90, height: 132 }, "#D5A66E", { style: "solid", fill: "#B98550", width: 2 }, "rounded-xl");
  addShape(slide, "rect", { left: x + 18, top: y - 38, width: 17, height: 76 }, ZINC, { style: "solid", fill: "#75838C", width: 1 });
  addShape(slide, "rect", { left: x + 55, top: y - 38, width: 17, height: 76 }, COPPER, { style: "solid", fill: "#8E4A28", width: 1 });
  addText(slide, label, { left: x - 4, top: y + 54, width: 98, height: 28 }, {
    fontSize: 13, bold: true, color: NAVY, align: "center",
  });
}

const deck = Presentation.create({ slideSize: { width: W, height: H } });

// 1. Capa
{
  const slide = deck.slides.add();
  slide.background.fill = NAVY;
  slide.images.add({
    blob: await blobBytes(heroPath), contentType: "image/png", alt: "Ilustração de seis batatas ligadas em série acendendo um LED",
    fit: "cover", position: { left: 0, top: 0, width: W, height: H },
  });
  addShape(slide, "rect", { left: 0, top: 0, width: 510, height: H }, "#071B2A", "none");
  addText(slide, "PILHA CASEIRA", { left: 70, top: 78, width: 340, height: 28 }, {
    fontSize: 14, bold: true, color: "#71D3CE",
  });
  addText(slide, "Pilha de\nbatata inglesa", { left: 68, top: 140, width: 410, height: 174 }, {
    fontSize: 50, bold: true, color: WHITE,
  });
  addText(slide, "Transformação de energia química em energia elétrica", { left: 72, top: 334, width: 370, height: 72 }, {
    fontSize: 21, color: "#DCE9ED",
  });
  addText(slide, "NOMES: [INSERIR INTEGRANTES]", { left: 72, top: 524, width: 380, height: 28 }, {
    fontSize: 15, bold: true, color: WHITE,
  });
  addText(slide, "TURMA: [INSERIR]     DATA: [INSERIR]", { left: 72, top: 562, width: 380, height: 26 }, {
    fontSize: 14, color: "#DCE9ED",
  });
  addText(slide, "3º ano - Química", { left: 72, top: 644, width: 250, height: 22 }, {
    fontSize: 12, color: "#86B7C0",
  });
  slide.speakerNotes.text = "Fonte da ilustração: imagem criada para esta apresentação com IA generativa. A imagem é conceitual e não substitui as fotos reais do experimento.";
}

// 2. Objetivo
{
  const slide = deck.slides.add();
  slide.background.fill = CREAM;
  addTitle(slide, "Objetivo do experimento", 2);
  addSectionLabel(slide, "Objetivo principal", 76, 152);
  addText(slide, "Construir uma pilha caseira com batatas, cobre e zinco capaz de produzir diferença de potencial e acender um LED de baixa voltagem.",
    { left: 76, top: 186, width: 670, height: 132 }, { fontSize: 28, bold: true, color: NAVY });
  addShape(slide, "roundRect", { left: 798, top: 154, width: 394, height: 202 }, TEAL_LIGHT, "none", "rounded-xl");
  addText(slide, "Hipótese", { left: 834, top: 186, width: 300, height: 34 }, { fontSize: 22, bold: true, color: TEAL });
  addText(slide, "Ao conectar várias células de batata em série, as tensões se somam e podem superar a tensão mínima necessária para o LED.",
    { left: 834, top: 234, width: 314, height: 90 }, { fontSize: 17, color: INK });
  addSectionLabel(slide, "O que será observado", 76, 382);
  addText(slide, "Diferença de potencial medida com multímetro", { left: 76, top: 422, width: 500, height: 38 }, { fontSize: 19, color: INK });
  addText(slide, "Polaridade correta e brilho do LED", { left: 76, top: 475, width: 500, height: 38 }, { fontSize: 19, color: INK });
  addText(slide, "Relação entre as reações químicas e o fluxo de elétrons", { left: 76, top: 528, width: 600, height: 52 }, { fontSize: 19, color: INK });
  addPhotoPlaceholder(slide, "INSERIR FOTO DO GRUPO", { left: 798, top: 390, width: 394, height: 220 });
  addFooter(slide);
  slide.speakerNotes.text = "Conteúdo baseado nas orientações fornecidas no PDF do trabalho: montagem da pilha caseira, medição com multímetro, funcionamento de um LED e explicação química.";
}

// 3. Materiais
{
  const slide = deck.slides.add();
  slide.background.fill = WHITE;
  addTitle(slide, "Materiais utilizados", 3);
  addSectionLabel(slide, "Para a montagem", 76, 150);
  const materialsLeft = [
    ["6 batatas inglesas", "Cada batata funciona como uma célula eletroquímica."],
    ["6 pregos galvanizados", "O revestimento de zinco forma o polo negativo."],
    ["6 placas ou fios grossos de cobre", "O cobre funciona como polo positivo."],
  ];
  const materialsRight = [
    ["7 fios com garras jacaré", "Cinco ligações entre batatas e duas para o LED."],
    ["LED vermelho de 5 mm", "Modelo de baixo consumo e menor tensão de acionamento."],
    ["Multímetro e lixa", "Para medir a tensão e limpar os eletrodos."],
  ];
  materialsLeft.forEach((item, i) => addNumberedItem(slide, i + 1, item[0], item[1], 76, 196 + i * 116, 500));
  materialsRight.forEach((item, i) => addNumberedItem(slide, i + 4, item[0], item[1], 616, 196 + i * 116, 500));
  addPhotoPlaceholder(slide, "INSERIR FOTO DOS MATERIAIS", { left: 904, top: 510, width: 288, height: 132 }, "Foto antes da montagem");
  addText(slide, "Atenção: cobre e zinco precisam ser metais diferentes e não podem se tocar dentro da batata.",
    { left: 76, top: 588, width: 782, height: 46 }, { fontSize: 16, bold: true, color: RED });
  addFooter(slide);
  slide.speakerNotes.text = "A quantidade de seis batatas foi escolhida para aumentar a chance de o LED acender. Fontes consultadas: https://heyplix.mit.edu/t/alternatives-to-coin-cell-batteries/1703 e https://www.unco.edu/nhs/science/pdf/demos/Chemistry_Demos.pdf";
}

// 4. Montagem
{
  const slide = deck.slides.add();
  slide.background.fill = CREAM;
  addTitle(slide, "Montagem das células", 4);
  addNumberedItem(slide, 1, "Preparação", "Numeramos as batatas e lixamos as superfícies do cobre e do zinco.", 76, 154, 540);
  addNumberedItem(slide, 2, "Inserção dos eletrodos", "Colocamos um eletrodo de cobre e um prego galvanizado em cada batata.", 76, 255, 540);
  addNumberedItem(slide, 3, "Separação", "Mantivemos cerca de 2 a 3 cm entre os metais, sem contato interno.", 76, 356, 540);
  addNumberedItem(slide, 4, "Organização", "Alinhamos as seis batatas para facilitar as ligações em série.", 76, 457, 540);
  addPhotoPlaceholder(slide, "FOTO 1: PREPARAÇÃO", { left: 690, top: 154, width: 500, height: 205 });
  addPhotoPlaceholder(slide, "FOTO 2: ELETRODOS NAS BATATAS", { left: 690, top: 389, width: 500, height: 205 });
  addText(slide, "[Adicione pequenas legendas com o que está acontecendo em cada foto]", { left: 690, top: 613, width: 500, height: 28 }, { fontSize: 13, color: MUTED, align: "center" });
  addFooter(slide);
  slide.speakerNotes.text = "Fale durante a apresentação: a batata fornece o meio úmido com íons. Ela não deve ser consumida depois do experimento.";
}

// 5. Série e polaridade
{
  const slide = deck.slides.add();
  slide.background.fill = WHITE;
  addTitle(slide, "Ligação em série e polaridade", 5);
  addText(slide, "Ligamos o cobre de uma batata ao zinco da batata seguinte. Assim, as tensões das células se somam.",
    { left: 76, top: 142, width: 1120, height: 56 }, { fontSize: 20, color: INK });
  const startX = 116;
  const gap = 180;
  for (let i = 0; i < 6; i++) {
    const x = startX + i * gap;
    addElectrode(slide, x, 300, `Batata ${i + 1}`);
    addText(slide, "Zn", { left: x + 2, top: 250, width: 50, height: 22 }, { fontSize: 13, bold: true, color: "#66747D", align: "center" });
    addText(slide, "Cu", { left: x + 42, top: 250, width: 50, height: 22 }, { fontSize: 13, bold: true, color: COPPER, align: "center" });
    if (i < 5) {
      addShape(slide, "rect", { left: x + 74, top: 270, width: 122, height: 5 }, TEAL, "none");
    }
  }
  addShape(slide, "roundRect", { left: 65, top: 252, width: 48, height: 74 }, "#DDE4E7", "none", "rounded-xl");
  addText(slide, "−", { left: 65, top: 267, width: 48, height: 40 }, { fontSize: 30, bold: true, color: NAVY, align: "center" });
  addShape(slide, "roundRect", { left: 1160, top: 252, width: 48, height: 74 }, "#FDE4E4", "none", "rounded-xl");
  addText(slide, "+", { left: 1160, top: 267, width: 48, height: 40 }, { fontSize: 30, bold: true, color: RED, align: "center" });
  addShape(slide, "rect", { left: 88, top: 478, width: 1080, height: 3 }, TEAL_LIGHT, "none");
  addText(slide, "Polo negativo", { left: 76, top: 504, width: 190, height: 30 }, { fontSize: 18, bold: true, color: NAVY });
  addText(slide, "Zinco livre da primeira batata", { left: 76, top: 540, width: 280, height: 30 }, { fontSize: 15, color: MUTED });
  addText(slide, "Polo positivo", { left: 840, top: 504, width: 220, height: 30 }, { fontSize: 18, bold: true, color: RED, align: "right" });
  addText(slide, "Cobre livre da última batata", { left: 816, top: 540, width: 310, height: 30 }, { fontSize: 15, color: MUTED, align: "right" });
  addText(slide, "LED: perna curta no negativo. Perna longa no positivo.", { left: 355, top: 608, width: 570, height: 34 }, { fontSize: 17, bold: true, color: TEAL, align: "center" });
  addFooter(slide);
  slide.speakerNotes.text = "Fontes: University of Northern Colorado, Potato Battery: https://www.unco.edu/nhs/science/pdf/demos/Chemistry_Demos.pdf. University of Illinois Physics Van: https://van.physics.illinois.edu/ask/listing/2396. Observação: cada célula tem zinco negativo e cobre positivo. Em série, conecta-se o polo positivo de uma célula ao negativo da seguinte.";
}

// 6. Explicação química
{
  const slide = deck.slides.add();
  slide.background.fill = NAVY;
  addDarkTitle(slide, "Explicação química", 6);
  addShape(slide, "roundRect", { left: 76, top: 160, width: 480, height: 330 }, "#102E42", { style: "solid", fill: "#305165", width: 2 }, "rounded-xl");
  addText(slide, "Ânodo", { left: 114, top: 196, width: 190, height: 36 }, { fontSize: 25, bold: true, color: GOLD });
  addText(slide, "Zinco, polo negativo", { left: 114, top: 242, width: 310, height: 32 }, { fontSize: 18, color: WHITE });
  addText(slide, "O zinco perde elétrons e sofre oxidação.", { left: 114, top: 300, width: 370, height: 56 }, { fontSize: 18, color: "#DCE9ED" });
  addText(slide, "Zn(s)  →  Zn²⁺(aq) + 2 e⁻", { left: 114, top: 382, width: 390, height: 48 }, { fontSize: 25, bold: true, color: GOLD, align: "center" });
  addShape(slide, "roundRect", { left: 724, top: 160, width: 480, height: 330 }, "#102E42", { style: "solid", fill: "#305165", width: 2 }, "rounded-xl");
  addText(slide, "Cátodo", { left: 762, top: 196, width: 190, height: 36 }, { fontSize: 25, bold: true, color: "#71D3CE" });
  addText(slide, "Cobre, polo positivo", { left: 762, top: 242, width: 310, height: 32 }, { fontSize: 18, color: WHITE });
  addText(slide, "Na superfície do cobre ocorre a redução de íons do meio.", { left: 762, top: 300, width: 370, height: 62 }, { fontSize: 18, color: "#DCE9ED" });
  addText(slide, "2 H⁺(aq) + 2 e⁻  →  H₂(g)", { left: 762, top: 382, width: 390, height: 48 }, { fontSize: 25, bold: true, color: "#71D3CE", align: "center" });
  addShape(slide, "rightArrow", { left: 524, top: 282, width: 230, height: 66 }, TEAL, "none");
  addText(slide, "elétrons", { left: 558, top: 295, width: 160, height: 30 }, { fontSize: 16, bold: true, color: WHITE, align: "center" });
  addText(slide, "A batata funciona como eletrólito: seu meio úmido permite o movimento de íons e fecha o circuito interno.",
    { left: 145, top: 545, width: 990, height: 70 }, { fontSize: 23, bold: true, color: WHITE, align: "center" });
  addText(slide, "Os elétrons percorrem o circuito externo do zinco para o cobre", { left: 64, top: 684, width: 520, height: 20 }, { fontSize: 10, color: "#86B7C0" });
  slide.speakerNotes.text = "Fonte para a explicação da célula Zn/Cu com batata: https://anaisonline.uems.br/seminarioformacaodocente/article/download/10511/9659/24891 e University of Illinois Physics Van: https://van.physics.illinois.edu/ask/listing/2400. O cobre atua principalmente como superfície condutora para a redução; não há solução preparada de íons Cu2+ como na pilha de Daniell.";
}

// 7. Resultados
{
  const slide = deck.slides.add();
  slide.background.fill = CREAM;
  addTitle(slide, "Resultados do teste", 7);
  addPhotoPlaceholder(slide, "FOTO 3: LEITURA DO MULTÍMETRO", { left: 76, top: 154, width: 520, height: 250 });
  addPhotoPlaceholder(slide, "FOTO 4: LED ACESO", { left: 676, top: 154, width: 520, height: 250 });
  addSectionLabel(slide, "Medições", 76, 440);
  addText(slide, "Tensão total medida", { left: 76, top: 480, width: 270, height: 34 }, { fontSize: 19, bold: true, color: NAVY });
  addShape(slide, "roundRect", { left: 360, top: 464, width: 236, height: 62 }, WHITE, { style: "solid", fill: TEAL, width: 2 }, "rounded-xl");
  addText(slide, "[INSERIR] V", { left: 378, top: 480, width: 200, height: 30 }, { fontSize: 22, bold: true, color: TEAL, align: "center" });
  addText(slide, "O LED acendeu?", { left: 676, top: 480, width: 210, height: 34 }, { fontSize: 19, bold: true, color: NAVY });
  addShape(slide, "roundRect", { left: 900, top: 464, width: 296, height: 62 }, WHITE, { style: "solid", fill: TEAL, width: 2 }, "rounded-xl");
  addText(slide, "[SIM / NÃO / FRACO]", { left: 915, top: 480, width: 266, height: 30 }, { fontSize: 19, bold: true, color: TEAL, align: "center" });
  addSectionLabel(slide, "Observação", 76, 564);
  addText(slide, "[Descreva o brilho, a estabilidade da leitura e qualquer mudança feita durante o teste.]",
    { left: 76, top: 598, width: 1120, height: 50 }, { fontSize: 17, color: MUTED });
  addFooter(slide);
  slide.speakerNotes.text = "Preencher este slide somente depois do teste real. Não inventar o valor do multímetro. Fotografar a leitura com os dígitos visíveis e o LED em ambiente mais escuro se o brilho estiver fraco.";
}

// 8. Conclusão
{
  const slide = deck.slides.add();
  slide.background.fill = WHITE;
  addTitle(slide, "Conclusão", 8);
  addSectionLabel(slide, "Resultado principal", 76, 154);
  addText(slide, "[Explique se a pilha produziu tensão suficiente e se o LED funcionou.]", { left: 76, top: 194, width: 1120, height: 70 }, { fontSize: 24, bold: true, color: NAVY });
  addShape(slide, "rect", { left: 76, top: 286, width: 1120, height: 2 }, TEAL_LIGHT, "none");
  addSectionLabel(slide, "Dificuldades encontradas", 76, 322);
  addText(slide, "[Exemplo: mau contato nas garras, eletrodos sujos, LED invertido ou tensão baixa.]", { left: 76, top: 362, width: 1120, height: 58 }, { fontSize: 19, color: MUTED });
  addSectionLabel(slide, "Possíveis melhorias", 76, 464);
  addText(slide, "[Exemplo: usar mais células, aumentar a área dos eletrodos ou refazer conexões.]", { left: 76, top: 504, width: 1120, height: 58 }, { fontSize: 19, color: MUTED });
  addShape(slide, "roundRect", { left: 76, top: 594, width: 1120, height: 58 }, TEAL_LIGHT, "none", "rounded-xl");
  addText(slide, "Conclusão química: a oxidação do zinco liberou elétrons, enquanto a batata permitiu o transporte de íons.",
    { left: 105, top: 610, width: 1060, height: 30 }, { fontSize: 17, bold: true, color: TEAL, align: "center" });
  addFooter(slide);
  slide.speakerNotes.text = "A conclusão deve refletir o teste real. Se o LED não acendeu, isso não elimina a produção de tensão. Explique a resistência interna elevada e use a leitura do multímetro como evidência.";
}

// 9. Referências
{
  const slide = deck.slides.add();
  slide.background.fill = NAVY;
  addDarkTitle(slide, "Referências e vídeo", 9);
  addSectionLabel(slide, "Documento do trabalho", 76, 154);
  addText(slide, "Orientações do Trabalho Trimestral de Química — 3º ano", { left: 76, top: 188, width: 760, height: 34 }, { fontSize: 20, bold: true, color: WHITE });
  addSectionLabel(slide, "Fontes consultadas", 76, 256);
  addText(slide, "University of Northern Colorado — Potato Battery\nUniversity of Illinois Physics Van — Potato Battery\nMIT PLIX — Alternatives to coin-cell batteries",
    { left: 76, top: 292, width: 660, height: 128 }, { fontSize: 18, color: "#DCE9ED" });
  addSectionLabel(slide, "Vídeo recomendado", 76, 470);
  addText(slide, "Pilha de Batata (ou Batateria) — Leonardo Fernandez", { left: 76, top: 506, width: 760, height: 34 }, { fontSize: 20, bold: true, color: "#71D3CE" });
  addText(slide, "https://www.youtube.com/watch?v=sgajFGJ7g5Q", { left: 76, top: 552, width: 670, height: 32 }, { fontSize: 16, color: WHITE });
  addShape(slide, "roundRect", { left: 820, top: 176, width: 360, height: 390 }, "#102E42", { style: "solid", fill: "#305165", width: 2 }, "rounded-xl");
  addText(slide, "Antes de apresentar", { left: 860, top: 218, width: 280, height: 36 }, { fontSize: 24, bold: true, color: GOLD, align: "center" });
  addText(slide, "Substituam todos os campos [INSERIR].\n\nConfirmem a polaridade do LED.\n\nLevem a montagem pronta, o multímetro e peças de reserva.\n\nDistribuam a fala entre os integrantes.",
    { left: 858, top: 286, width: 284, height: 230 }, { fontSize: 18, color: WHITE, align: "left" });
  addText(slide, "Acesso às referências completas nas notas deste slide", { left: 64, top: 684, width: 520, height: 20 }, { fontSize: 10, color: "#86B7C0" });
  slide.speakerNotes.text = "Referências completas:\n1. Documento fornecido pelo professor: C:/Users/ppfti/OneDrive/Desktop/o que fazer batata inglesa.pdf\n2. University of Northern Colorado. Potato Battery. https://www.unco.edu/nhs/science/pdf/demos/Chemistry_Demos.pdf\n3. University of Illinois Physics Van. How Many Potatoes in a Potato Battery? https://van.physics.illinois.edu/ask/listing/2396\n4. University of Illinois Physics Van. Potato Battery. https://van.physics.illinois.edu/ask/listing/2400\n5. MIT PLIX. Alternatives to coin-cell batteries. https://heyplix.mit.edu/t/alternatives-to-coin-cell-batteries/1703\n6. Vídeo: Pilha de Batata (ou Batateria). https://www.youtube.com/watch?v=sgajFGJ7g5Q";
}

await fs.mkdir(previewDir, { recursive: true });
await fs.mkdir(outputDir, { recursive: true });

for (const [index, slide] of deck.slides.items.entries()) {
  const png = await deck.export({ slide, format: "png", scale: 1 });
  await writeBlob(path.join(previewDir, `slide-${String(index + 1).padStart(2, "0")}.png`), png);
}
const montage = await deck.export({ format: "webp", montage: true });
await writeBlob(path.join(buildDir, "montage.webp"), montage);

const stagingDir = path.join(workspaceDir, ".codex-finalizer", "batata-slides");
await fs.mkdir(stagingDir, { recursive: true });
const candidatePath = path.join(stagingDir, "candidate.pptx");
await (await PresentationFile.exportPptx(deck)).save(candidatePath);

const result = await finalizePresentation({
  workspaceDir,
  candidatePath,
  finalPath,
  pythonExecutable: RUNTIME_PYTHON,
  integrityValidatorPath: path.join(SKILL_DIR, "container_tools/inspect_presentation_package_integrity.py"),
  layoutValidatorPath: path.join(SKILL_DIR, "container_tools/inspect_presentation_layout_geometry.py"),
  layoutArgs: [
    "--expected-slide-size-emu", "12192000,6858000",
    "--validate-bullet-geometry",
    "--validate-heading-fit",
  ],
  explicitTotalSlideCount: 9,
  requiredNativeTableOwnerSlides: [],
  requiredNativeChartOwnerSlides: [],
  fontPolicy: { basis: "design", families: [FONT] },
  verifyArtifactToolImport: true,
  receiptPath: path.join(stagingDir, "Pilha_de_Batata_Apresentacao_pronta.validation.json"),
});

console.log(JSON.stringify({ finalPath, result }, null, 2));

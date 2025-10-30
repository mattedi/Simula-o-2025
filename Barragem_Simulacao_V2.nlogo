; ============================================
; SIMULACAO DA BARRAGEM - RIO ITAJAI ACU
; Integrada com Dados Reais da Bacia Hidrografica
; Vale do Itajai - Santa Catarina
; ============================================

extensions [gis]

globals [
  ; Dados GIS
  dataset-bacias              ; Dataset do shapefile
  bbox-xmin bbox-xmax         ; Bounding box UTM
  bbox-ymin bbox-ymax
  
  ; Lista de sub-bacias do Itajai Acu
  lista-subbacias             ; Lista de features filtradas
  
  ; Variaveis de entrada (Condicoes Externas)
  regime-hidrologico          ; Rh: vazao base agregada da bacia (m3/s)
  intensidade-chuvas          ; Cj: precipitacao acumulada (mm)
  
  ; Variaveis da barragem (Processos Internos)
  volume-reservatorio         ; Volume atual no reservatorio (m3)
  capacidade-maxima           ; Capacidade total do reservatorio (m3)
  eficiencia-tecnica          ; Et: eficiencia da operacao (0-1)
  capacidade-retencao         ; Cr: % da capacidade utilizavel (0-1)
  abertura-comportas          ; Fc: % de abertura das comportas (0-1)
  
  ; Variaveis de saida (Efeitos Resultantes)
  vazao-controlada            ; Vc: vazao final apos barragem (m3/s)
  nivel-rio-jusante           ; Nivel do rio a jusante (m)
  risco-enchente              ; Indicador de risco (0-100)
  impactos-socioeconomicos    ; Impactos nas comunidades (0-100)
  
  ; Variaveis de monitoramento
  total-chuva-acumulada
  eventos-criticos
  tempo-simulacao
  
  ; Estatisticas da bacia
  vazao-total-q7              ; Soma das vazoes Q7 de todas sub-bacias
  num-subbacias-ativas        ; Numero de sub-bacias com chuva
]

patches-own [
  tipo-area                   ; "sub-bacia", "barragem", "rio-jusante", "area-urbana"
  nivel-agua
  afetado?
  
  ; Atributos hidrologicos (dados reais)
  vazao-q7                    ; Vazao minima Q7 (m3/s)
  vazao-rest                  ; Vazao de restricao (m3/s)
  nome-microbacia             ; Nome da microbacia
  nome-rio                    ; Nome do rio principal
  area-bacia                  ; Area da sub-bacia (m2)
  tem-chuva?                  ; Se esta chovendo nesta sub-bacia
  contribuicao-vazao          ; Contribuicao atual para vazao total
]

breed [sensores sensor]
breed [comportas comporta]
breed [marcadores-bacia marcador-bacia]

sensores-own [
  leitura-atual
]

marcadores-bacia-own [
  nome-exibir
]

to setup
  clear-all
  
  ; Carregar shapefile e configurar mundo GIS
  print "Carregando shapefile da Bacia do Vale do Itajai..."
  
  set dataset-bacias gis:load-dataset "bacia_hidrografica_vale.shp"
  
  if dataset-bacias = nobody [
    user-message "ERRO: Shapefile nao encontrado! Certifique-se de que 'bacia_hidrografica_vale.shp' esta no mesmo diretorio do modelo."
    stop
  ]
  
  ; Configurar envelope do mundo baseado no shapefile
  let envelope gis:envelope-of dataset-bacias
  set bbox-xmin item 0 envelope
  set bbox-xmax item 1 envelope
  set bbox-ymin item 2 envelope
  set bbox-ymax item 3 envelope
  
  gis:set-world-envelope envelope
  
  print " Shapefile carregado com sucesso"
  
  ; Inicializar variaveis globais
  set regime-hidrologico 0
  set intensidade-chuvas 0
  set total-chuva-acumulada 0
  set vazao-total-q7 0
  set num-subbacias-ativas 0
  
  ; Parametros da barragem (Jose Boiteux)
  set capacidade-maxima 1000000000    ; 1 bilhao de m3 (ajustar conforme dados reais)
  set volume-reservatorio (capacidade-maxima * 0.4)  ; Inicia com 40%
  set eficiencia-tecnica 0.88
  set capacidade-retencao 0.75
  set abertura-comportas 0.25
  
  ; Inicializar saidas
  set vazao-controlada 0
  set nivel-rio-jusante 2.5
  set risco-enchente 0
  set impactos-socioeconomicos 0
  set eventos-criticos 0
  set tempo-simulacao 0
  
  ; Configurar ambiente
  setup-ambiente-gis
  setup-barragem
  setup-sensores
  
  print (word " Simulacao configurada: " count patches with [tipo-area = "sub-bacia"] " sub-bacias do Itajai Acu")
  print (word " Vazao Q7 total da bacia: " (precision vazao-total-q7 2) " m3/s")
  
  reset-ticks
end

to setup-ambiente-gis
  ; Inicializar todos os patches
  ask patches [
    set tipo-area "indefinido"
    set nivel-agua 0
    set afetado? false
    set vazao-q7 0
    set vazao-rest 0
    set tem-chuva? false
    set contribuicao-vazao 0
    set pcolor gray - 3
  ]
  
  ; Filtrar apenas sub-bacias do Rio Itajai Acu
  set lista-subbacias []
  
  foreach gis:feature-list-of dataset-bacias [ feature ->
    let nome-rio-feature gis:property-value feature "NM_RIO_PRI"
    
    ; Filtrar: Rio Itajai Acu (ACU ou ITAJAI-ACU)
    if is-string? nome-rio-feature [
      if (member? "ITAJAI" nome-rio-feature and member? "ACU" nome-rio-feature) [
        set lista-subbacias lput feature lista-subbacias
      ]
    ]
  ]
  
  print (word " Filtradas " (length lista-subbacias) " sub-bacias do Rio Itajai Acu")
  
  ; Mapear cada sub-bacia para patches
  let contador 0
  
  foreach lista-subbacias [ feature ->
    ; Obter centroide da sub-bacia
    let centroid gis:location-of gis:centroid-of feature
    
    if not empty? centroid [
      let px item 0 centroid
      let py item 1 centroid
      
      ; Verificar se esta dentro dos limites do mundo NetLogo
      if px >= min-pxcor and px <= max-pxcor and py >= min-pycor and py <= max-pycor [
        ask patch px py [
          set tipo-area "sub-bacia"
          
          ; Atribuir dados hidrologicos reais
          set vazao-q7 gis:property-value feature "VL_QMIN7"
          set vazao-rest gis:property-value feature "VL_QREST"
          set nome-microbacia gis:property-value feature "NM_MICRO"
          set nome-rio gis:property-value feature "NM_RIO_PRI"
          set area-bacia gis:property-value feature "SHAPE_AREA"
          
          ; Garantir valores numericos validos
          if not is-number? vazao-q7 [ set vazao-q7 0 ]
          if not is-number? vazao-rest [ set vazao-rest 0 ]
          if not is-number? area-bacia [ set area-bacia 0 ]
          
          ; Acumular vazao total
          set vazao-total-q7 vazao-total-q7 + vazao-q7
          
          ; Colorir baseado na vazao Q7 (azul: menor vazao, azul escuro: maior vazao)
          set pcolor scale-color blue vazao-q7 20 0
          
          set contador contador + 1
        ]
      ]
    ]
  ]
  
  print (word " Mapeadas " contador " sub-bacias para o grid NetLogo")
  
  ; Desenhar os poligonos das sub-bacias (opcional, pode impactar performance)
  if mostrar-poligonos? [
    gis:set-drawing-color blue - 2
    foreach lista-subbacias [ feature ->
      gis:draw feature 0.5
    ]
  ]
  
  ; Criar zona da barragem (centro do mundo)
  ask patches with [pxcor > -2 and pxcor < 2 and pycor > -2 and pycor < 2] [
    if tipo-area = "indefinido" [
      set tipo-area "barragem"
      set pcolor gray + 1
    ]
  ]
  
  ; Criar zona a jusante (abaixo da barragem)
  ask patches with [pycor < -2 and tipo-area = "indefinido"] [
    set tipo-area "rio-jusante"
    set pcolor blue - 1
  ]
  
  ; Criar zona urbana (extremo sul)
  ask patches with [pycor < -10 and tipo-area = "rio-jusante"] [
    set tipo-area "area-urbana"
    set pcolor brown - 2
  ]
end

to setup-barragem
  ; Criar estrutura visual da barragem
  ask patches with [tipo-area = "barragem"] [
    set pcolor gray + 2
  ]
  
  ; Criar comportas
  create-comportas 3 [
    setxy 0 0
    set shape "square"
    set color red
    set size 2
    set heading one-of [0 120 240]
    fd 2
  ]
end

to setup-sensores
  ; Posicionar sensores em sub-bacias representativas
  let subbacias-disponiveis patches with [tipo-area = "sub-bacia" and vazao-q7 > 0]
  
  if any? subbacias-disponiveis [
    create-sensores min (list 8 (count subbacias-disponiveis)) [
      move-to one-of subbacias-disponiveis
      set shape "circle"
      set color yellow
      set size 1.5
      set leitura-atual 0
    ]
  ]
end

to go
  if ticks >= tempo-simulacao-max [
    print " Simulacao finalizada"
    stop
  ]
  
  set tempo-simulacao tempo-simulacao + 1
  
  ; Etapa 1: Condicoes Externas
  atualizar-condicoes-climaticas
  calcular-regime-hidrologico-real
  
  ; Etapa 2: Processos Internos
  monitorar-sistema
  calcular-capacidade-retencao
  ajustar-comportas
  
  ; Etapa 3: Aplicar Modelo Formal
  calcular-vazao-controlada
  
  ; Etapa 4: Efeitos Resultantes
  atualizar-nivel-rio
  avaliar-risco-enchente
  calcular-impactos
  
  ; Visualizacao
  atualizar-visualizacao
  
  tick
end

to atualizar-condicoes-climaticas
  ; Resetar marcadores de chuva
  ask patches with [tipo-area = "sub-bacia"] [
    set tem-chuva? false
  ]
  
  set num-subbacias-ativas 0
  
  ; Simular eventos de chuva espacialmente distribuidos
  ask patches with [tipo-area = "sub-bacia"] [
    ; Probabilidade de chuva baseada em configuracao
    if random 100 < prob-chuva [
      set tem-chuva? true
      set num-subbacias-ativas num-subbacias-ativas + 1
      
      ; Intensidade variavel
      set intensidade-chuvas (random-float 50) + 10
      set total-chuva-acumulada total-chuva-acumulada + intensidade-chuvas
      
      ; Visualizar chuva
      set pcolor yellow
    ]
  ]
  
  ; Eventos extremos (5% de chance)
  if random 100 < 5 [
    ask n-of (max list 1 (count patches with [tipo-area = "sub-bacia"] * 0.1)) patches with [tipo-area = "sub-bacia"] [
      set tem-chuva? true
      set intensidade-chuvas intensidade-chuvas + (random-float 150)
      set pcolor red
    ]
    set eventos-criticos eventos-criticos + 1
  ]
end

to calcular-regime-hidrologico-real
  ; Regime hidrologico baseado nas vazoes Q7 reais das sub-bacias
  set regime-hidrologico 0
  
  ask patches with [tipo-area = "sub-bacia"] [
    ; Vazao base e a Q7
    let vazao-base vazao-q7
    
    ; Se tem chuva, aumentar vazao proporcionalmente
    ifelse tem-chuva? [
      ; Fator de amplificacao baseado na intensidade da chuva e area da bacia
      let fator-chuva (intensidade-chuvas / 100) * (area-bacia / 10000000)  ; Normalizar area
      set contribuicao-vazao vazao-base * (1 + fator-chuva * 2)
    ] [
      set contribuicao-vazao vazao-base
      
      ; Retornar cor original
      set pcolor scale-color blue vazao-q7 20 0
    ]
    
    ; Acumular regime total
    set regime-hidrologico regime-hidrologico + contribuicao-vazao
  ]
  
  ; Adicionar variabilidade sazonal
  set regime-hidrologico regime-hidrologico * (1 + sin(ticks / 20) * 0.15)
end

to monitorar-sistema
  ; Sensores coletam dados nas sub-bacias
  ask sensores [
    let patch-atual patch-here
    if [tipo-area] of patch-atual = "sub-bacia" [
      set leitura-atual [contribuicao-vazao] of patch-atual
    ]
  ]
  
  ; Atualizar volume do reservatorio com entrada de agua
  let entrada-agua regime-hidrologico * 3600  ; 1 tick = 1 hora = 3600 segundos
  set volume-reservatorio volume-reservatorio + entrada-agua
  
  ; Limitar ao maximo
  if volume-reservatorio > capacidade-maxima [
    set volume-reservatorio capacidade-maxima
  ]
end

to calcular-capacidade-retencao
  ; Cr depende do volume disponivel
  let volume-disponivel (capacidade-maxima - volume-reservatorio)
  set capacidade-retencao volume-disponivel / capacidade-maxima
  
  ; Ajustar eficiencia tecnica baseado na taxa de ocupacao
  let taxa-ocupacao (volume-reservatorio / capacidade-maxima)
  set eficiencia-tecnica 0.88 * (1 - taxa-ocupacao * 0.15)
end

to ajustar-comportas
  ; Decisao de abertura das comportas baseada na taxa de ocupacao
  let taxa-ocupacao (volume-reservatorio / capacidade-maxima)
  
  ; Logica de controle: abrir mais quando volume alto
  ifelse taxa-ocupacao > 0.85 [
    set abertura-comportas 0.9
    ask comportas [set color red set size 3]
  ] [
    ifelse taxa-ocupacao > 0.70 [
      set abertura-comportas 0.65
      ask comportas [set color orange set size 2.5]
    ] [
      ifelse taxa-ocupacao > 0.50 [
        set abertura-comportas 0.4
        ask comportas [set color yellow set size 2]
      ] [
        set abertura-comportas 0.2
        ask comportas [set color green set size 1.5]
      ]
    ]
  ]
end

to calcular-vazao-controlada
  ; MODELO FORMAL:
  ; Vc = (Rh + Cj)  [1 - (Et  Cr  Fc)]
  
  let Rh regime-hidrologico
  let Cj (intensidade-chuvas * num-subbacias-ativas) * 0.3  ; Conversao agregada
  let Et eficiencia-tecnica
  let Cr capacidade-retencao
  let Fc (1 - abertura-comportas)  ; Inverso: comporta fechada = retencao
  
  set vazao-controlada (Rh + Cj) * (1 - (Et * Cr * Fc))
  
  ; Liberar agua do reservatorio
  let saida-agua vazao-controlada * 3600
  set volume-reservatorio volume-reservatorio - saida-agua
  
  ; Nao pode ser negativo
  if volume-reservatorio < 0 [
    set volume-reservatorio 0
  ]
end

to atualizar-nivel-rio
  ; Nivel do rio a jusante depende da vazao controlada
  set nivel-rio-jusante 2.5 + (vazao-controlada / 50)
  
  ; Visualizar no rio
  ask patches with [tipo-area = "rio-jusante"] [
    set nivel-agua vazao-controlada / 30
    set pcolor scale-color blue nivel-agua 0 15
  ]
end

to avaliar-risco-enchente
  ; Risco baseado no nivel do rio (ajustado para o Itajai Acu)
  ifelse nivel-rio-jusante < 5 [
    set risco-enchente 0
  ] [
    ifelse nivel-rio-jusante < 7 [
      set risco-enchente 25
    ] [
      ifelse nivel-rio-jusante < 9 [
        set risco-enchente 55
      ] [
        ifelse nivel-rio-jusante < 11 [
          set risco-enchente 80
        ] [
          set risco-enchente 100
        ]
      ]
    ]
  ]
end

to calcular-impactos
  ; Impactos sociais e economicos nas comunidades
  set impactos-socioeconomicos risco-enchente * 0.85
  
  ; Marcar areas afetadas
  ask patches with [tipo-area = "area-urbana"] [
    ifelse nivel-rio-jusante > 8 [
      set afetado? true
      set pcolor red + 2
    ] [
      set afetado? false
      set pcolor brown - 2
    ]
  ]
end

to atualizar-visualizacao
  ; Atualizar comportas
  ask comportas [
    let tamanho-base 1.5
    set size tamanho-base + (abertura-comportas * 1.5)
  ]
  
  ; Destacar sub-bacias criticas (alto risco)
  if destacar-criticas? [
    ask patches with [tipo-area = "sub-bacia" and tem-chuva? and contribuicao-vazao > 10] [
      set pcolor orange
    ]
  ]
end

; ==========================================
; INTERFACE E RELATORIOS
; ==========================================

to-report taxa-ocupacao-reservatorio
  report (volume-reservatorio / capacidade-maxima) * 100
end

to-report vazao-media-subbacias
  let subbacias-ativas patches with [tipo-area = "sub-bacia" and contribuicao-vazao > 0]
  ifelse any? subbacias-ativas [
    report mean [contribuicao-vazao] of subbacias-ativas
  ] [
    report 0
  ]
end

to-report num-subbacias-totais
  report count patches with [tipo-area = "sub-bacia"]
end

to-report percentual-subbacias-com-chuva
  let total num-subbacias-totais
  ifelse total > 0 [
    report (num-subbacias-ativas / total) * 100
  ] [
    report 0
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
250
10
758
519
-1
-1
15.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
15
25
90
58
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
100
25
175
58
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
185
25
240
58
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
15
80
230
113
tempo-simulacao-max
tempo-simulacao-max
100
2000
500.0
50
1
ticks
HORIZONTAL

SLIDER
15
125
230
158
prob-chuva
prob-chuva
0
100
30.0
5
1
%
HORIZONTAL

SWITCH
15
170
230
203
mostrar-poligonos?
mostrar-poligonos?
1
1
-1000

SWITCH
15
210
230
243
destacar-criticas?
destacar-criticas?
0
1
-1000

MONITOR
775
25
920
70
Vazao Controlada
precision vazao-controlada 2
2
1
11

MONITOR
775
80
920
125
Nvel Rio (m)
precision nivel-rio-jusante 2
2
1
11

MONITOR
775
135
920
180
Risco Enchente
risco-enchente
0
1
11

MONITOR
775
190
920
235
Taxa Ocup. Res. (%)
precision taxa-ocupacao-reservatorio 1
2
1
11

MONITOR
935
25
1080
70
Regime Hidrol.
precision regime-hidrologico 2
2
1
11

MONITOR
935
80
1080
125
Vazao Q7 Total
precision vazao-total-q7 2
2
1
11

MONITOR
935
135
1080
180
Sub-bacias Ativas
num-subbacias-ativas
0
1
11

MONITOR
935
190
1080
235
% c/ Chuva
precision percentual-subbacias-com-chuva 1
2
1
11

PLOT
775
250
1080
400
Vazoes e Niveis
Tempo (ticks)
m3/s | m
0.0
100.0
0.0
50.0
true
true
"" ""
PENS
"Vazao Control." 1.0 0 -13345367 true "" "plot vazao-controlada"
"Regime Hidrol." 1.0 0 -2674135 true "" "plot regime-hidrologico"
"Nivel Rio (10)" 1.0 0 -955883 true "" "plot nivel-rio-jusante * 10"

PLOT
775
410
1080
560
Risco e Impactos
Tempo (ticks)
Indice (0-100)
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"Risco Enchente" 1.0 0 -2674135 true "" "plot risco-enchente"
"Impactos Socioecon." 1.0 0 -955883 true "" "plot impactos-socioeconomicos"

PLOT
15
260
240
410
Volume Reservatorio
Tempo
% Capacidade
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot taxa-ocupacao-reservatorio"

PLOT
15
420
240
560
Abertura Comportas
Tempo
% Abertura
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -7500403 true "" "plot abertura-comportas * 100"

MONITOR
15
575
120
620
Eventos Criticos
eventos-criticos
0
1
11

MONITOR
130
575
240
620
Tempo (h)
tempo-simulacao
0
1
11

TEXTBOX
20
635
230
701
LEGENDA:\nAzul escuro = Alta vazao Q7\nAzul claro = Baixa vazao Q7\nAmarelo = Chuva moderada\nVermelho = Chuva extrema
11
0.0
1

@#$#@#$#@
## O QUE E?

Este modelo simula o **Sistema de Controle de Enchentes do Rio Itajai Acu** atraves da Barragem de Jose Boiteux, integrado com dados reais da bacia hidrografica do Vale do Itajai, Santa Catarina.

## DADOS REAIS INTEGRADOS

O modelo utiliza dados geoespaciais reais:

- **57 sub-bacias** do Rio Itajai Acu
- **Vazoes Q7** (vazao minima de 7 dias consecutivos)
- **Areas reais** das sub-bacias
- **Coordenadas UTM** (SAD 1969 Zone 22S)
- **Topologia hidrografica** real

## COMO FUNCIONA

### 1. CONDICOES EXTERNAS
- Eventos de chuva distribuidos espacialmente pelas sub-bacias
- Cada sub-bacia contribui com sua vazao Q7 real
- Eventos extremos simulados (5% probabilidade)

### 2. PROCESSOS INTERNOS
- **Regime Hidrologico**: Soma das contribuicoes de todas as sub-bacias
- **Monitoramento**: Sensores coletam dados em sub-bacias representativas
- **Capacidade de Retencao**: Baseada no volume disponivel no reservatorio

### 3. MODELO FORMAL
**Vazao Controlada = (Rh + Cj)  [1 - (Et  Cr  Fc)]**

Onde:
- Rh = Regime hidrologico (vazao base)
- Cj = Contribuicao das chuvas
- Et = Eficiencia tecnica (0.88)
- Cr = Capacidade de retencao
- Fc = Fator de fechamento das comportas

### 4. EFEITOS RESULTANTES
- Nivel do rio a jusante
- Risco de enchente (0-100)
- Impactos socioeconomicos
- Areas urbanas afetadas

## COMO USAR

1. Clique **Setup** para carregar o shapefile e inicializar a simulacao
2. Ajuste os parametros:
   - `tempo-simulacao-max`: Duracao da simulacao
   - `prob-chuva`: Probabilidade de chuva em cada sub-bacia (%)
   - `mostrar-poligonos?`: Desenhar limites reais das sub-bacias
   - `destacar-criticas?`: Destacar sub-bacias com vazao critica

3. Clique **Go** para executar continuamente ou **Step** para avancar passo-a-passo

## INDICADORES

### Monitores Principais
- **Vazao Controlada**: Vazao apos a barragem (m3/s)
- **Nivel Rio**: Altura do rio a jusante (m)
- **Risco Enchente**: Indicador 0-100
- **Taxa Ocupacao Reservatorio**: % da capacidade utilizada
- **Regime Hidrologico**: Vazao total afluente (m3/s)
- **Vazao Q7 Total**: Soma das vazoes minimas de todas sub-bacias
- **Sub-bacias Ativas**: Quantidade com precipitacao
- **% com Chuva**: Percentual de sub-bacias sob chuva

### Graficos
1. **Vazoes e Niveis**: Evolucao temporal das vazoes e nivel do rio
2. **Risco e Impactos**: Indicadores de risco de enchente e impactos socioeconomicos
3. **Volume Reservatorio**: Taxa de ocupacao do reservatorio
4. **Abertura Comportas**: Percentual de abertura das comportas

## VISUALIZACAO

- **Azul escuro**: Sub-bacias com alta vazao Q7
- **Azul claro**: Sub-bacias com baixa vazao Q7
- **Amarelo**: Sub-bacias com chuva moderada
- **Vermelho**: Sub-bacias com chuva extrema
- **Laranja**: Sub-bacias criticas (vazao > 10 m3/s)
- **Cinza**: Barragem
- **Marrom**: Areas urbanas (vermelho = afetadas)

## OBSERVACOES

- O modelo requer o shapefile `bacia_hidrografica_vale.shp` (e arquivos associados .dbf, .prj, .shx) no mesmo diretorio
- A extensao GIS do NetLogo deve estar habilitada
- Baseado em dados reais da Agencia Nacional de Aguas (ANA)
- Calibracao recomendada com dados historicos de eventos de enchente

## REFERENCIAS

- Bacia Hidrografica do Rio Itajai - ANA
- Sistema de Controle de Enchentes do Vale do Itajai
- Barragem Norte (Jose Boiteux) - Defesa Civil de Santa Catarina

## CREDITOS

Modelo desenvolvido com integracao GIS real da Bacia do Vale do Itajai.
NetLogo 6.4.0 - Extensao GIS
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

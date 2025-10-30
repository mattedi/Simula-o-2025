# SIMULAÇÃO DA BARRAGEM - RIO ITAJAÍ AÇU
## Modelo NetLogo Integrado com Dados Geoespaciais Reais

---

## 📦 ARQUIVOS INCLUÍDOS

1. **Barragem_Itajai_Acu_GIS.nlogo** - Modelo NetLogo principal
2. **bacia_hidrografica_vale.shp** - Shapefile com geometrias das sub-bacias
3. **bacia_hidrografica_vale.dbf** - Tabela de atributos (vazões, nomes, etc.)
4. **bacia_hidrografica_vale.prj** - Sistema de coordenadas (UTM SAD 1969 Zone 22S)
5. **bacia_hidrografica_vale.shx** - Índice espacial do shapefile
6. **bacia_hidrografica_vale.cpg** - Codificação UTF-8
7. **bacia_hidrografica_vale.qmd** - Metadados QGIS

---

## 🚀 INSTALAÇÃO E EXECUÇÃO

### Pré-requisitos
- **NetLogo 6.4.0** ou superior ([download](https://ccl.northwestern.edu/netlogo/download.shtml))
- Extensão **GIS** (incluída no NetLogo 6.x)

### Passos para Executar

1. **Coloque todos os arquivos na mesma pasta**
   ```
   /sua-pasta/
   ├── Barragem_Itajai_Acu_GIS.nlogo
   ├── bacia_hidrografica_vale.shp
   ├── bacia_hidrografica_vale.dbf
   ├── bacia_hidrografica_vale.prj
   ├── bacia_hidrografica_vale.shx
   ├── bacia_hidrografica_vale.cpg
   └── bacia_hidrografica_vale.qmd
   ```

2. **Abra o NetLogo** e carregue o arquivo `Barragem_Itajai_Acu_GIS.nlogo`

3. **Clique em Setup** (aguarde o carregamento do shapefile - pode levar 10-30 segundos)

4. **Ajuste os parâmetros** conforme desejado

5. **Clique em Go** para executar a simulação

---

## 📊 DADOS INTEGRADOS

### Bacia do Rio Itajaí Açu
- **57 sub-bacias** mapeadas
- **Vazão Q7 Total**: ~157,84 m³/s (soma das vazões mínimas)
- **Vazão Q7 Média**: 2,77 m³/s por sub-bacia
- **Vazão Q7 Máxima**: 14,99 m³/s (sub-bacia mais crítica)
- **Área Total**: ~1.822 km²

### Atributos por Sub-bacia
- `VL_QMIN7` - Vazão mínima de 7 dias (m³/s)
- `VL_QREST` - Vazão de restrição (m³/s)
- `NM_MICRO` - Nome da microbacia
- `NM_RIO_PRI` - Rio principal (todos: "RIO ITAJAI ACU" ou "RIO ITAJAI-ACU")
- `SHAPE_AREA` - Área da sub-bacia (m²)

---

## ⚙️ PARÂMETROS CONFIGURÁVEIS

### Interface Principal

| Parâmetro | Descrição | Valor Padrão | Faixa |
|-----------|-----------|--------------|-------|
| `tempo-simulacao-max` | Duração da simulação (ticks = horas) | 500 | 100-2000 |
| `prob-chuva` | Probabilidade de chuva em cada sub-bacia (%) | 30 | 0-100 |
| `mostrar-poligonos?` | Desenhar limites reais das sub-bacias | ON | ON/OFF |
| `destacar-criticas?` | Destacar sub-bacias com vazão > 10 m³/s | OFF | ON/OFF |

### Parâmetros da Barragem (no código)
- `capacidade-maxima` = 1.000.000.000 m³ (1 bilhão de m³)
- `volume-inicial` = 40% da capacidade máxima
- `eficiencia-tecnica` = 0,88 (88%)
- `capacidade-retencao-inicial` = 0,75 (75%)

---

## 📈 INDICADORES E MONITORES

### Monitores em Tempo Real

**Coluna 1 - Controle de Vazão:**
- **Vazão Controlada** (m³/s) - Vazão após a barragem
- **Nível Rio** (m) - Altura do rio a jusante
- **Risco Enchente** (0-100) - Índice de risco
- **Taxa Ocupação Reservatório** (%) - % de capacidade utilizada

**Coluna 2 - Estado da Bacia:**
- **Regime Hidrológico** (m³/s) - Vazão total afluente
- **Vazão Q7 Total** (m³/s) - Soma das vazões base
- **Sub-bacias Ativas** - Quantidade sob precipitação
- **% com Chuva** - Percentual de sub-bacias com chuva

**Parte Inferior:**
- **Eventos Críticos** - Contador de eventos extremos
- **Tempo** (h) - Tempo de simulação em horas

### Gráficos

1. **Vazões e Níveis** (temporal)
   - Linha azul: Vazão Controlada
   - Linha verde: Regime Hidrológico
   - Linha vermelha: Nível do Rio (×10 para escala)

2. **Risco e Impactos** (temporal)
   - Linha verde: Risco de Enchente (0-100)
   - Linha vermelha: Impactos Socioeconômicos (0-100)

3. **Volume Reservatório** (temporal)
   - Percentual de ocupação do reservatório

4. **Abertura Comportas** (temporal)
   - Percentual de abertura das comportas

---

## 🎨 VISUALIZAÇÃO

### Cores das Sub-bacias
- **Azul escuro** → Alta vazão Q7 (> 5 m³/s)
- **Azul claro** → Baixa vazão Q7 (< 1 m³/s)
- **Amarelo** → Chuva moderada em andamento
- **Vermelho** → Chuva extrema (evento crítico)
- **Laranja** → Sub-bacia crítica (vazão > 10 m³/s) [se `destacar-criticas?` = ON]

### Outras Zonas
- **Cinza claro** → Barragem (centro do mundo)
- **Azul médio** → Rio a jusante
- **Marrom** → Áreas urbanas
- **Vermelho claro** → Áreas urbanas afetadas (nível rio > 8m)

### Agentes
- **Círculos amarelos** → Sensores de monitoramento (8 unidades)
- **Quadrados coloridos** → Comportas (3 unidades)
  - Verde = Baixa abertura (< 50%)
  - Amarelo = Média abertura (50-70%)
  - Laranja = Alta abertura (70-90%)
  - Vermelho = Abertura crítica (> 90%)

---

## 🔬 MODELO MATEMÁTICO

### Equação de Vazão Controlada

```
Vc = (Rh + Cj) × [1 - (Et × Cr × Fc)]
```

**Onde:**
- **Vc** = Vazão Controlada (m³/s)
- **Rh** = Regime Hidrológico = Σ(vazões de todas sub-bacias)
- **Cj** = Contribuição das Chuvas = (intensidade × n_subbacias_ativas) × 0,3
- **Et** = Eficiência Técnica = 0,88 × [1 - (taxa_ocupação × 0,15)]
- **Cr** = Capacidade de Retenção = volume_disponível / capacidade_máxima
- **Fc** = Fator de Fechamento = 1 - abertura_comportas

### Lógica de Controle das Comportas

| Taxa de Ocupação | Abertura | Cor | Descrição |
|------------------|----------|-----|-----------|
| > 85% | 90% | Vermelho | Emergência - liberação máxima |
| 70-85% | 65% | Laranja | Alerta - liberação alta |
| 50-70% | 40% | Amarelo | Atenção - liberação moderada |
| < 50% | 20% | Verde | Normal - liberação mínima |

### Cálculo do Risco de Enchente

| Nível do Rio | Risco | Descrição |
|--------------|-------|-----------|
| < 5m | 0 | Normal |
| 5-7m | 25 | Atenção |
| 7-9m | 55 | Alerta |
| 9-11m | 80 | Perigo |
| > 11m | 100 | Emergência |

---

## 🧪 CENÁRIOS DE TESTE

### Cenário 1: Condições Normais
- `prob-chuva` = 20%
- Observar comportamento padrão da bacia

### Cenário 2: Estação Chuvosa
- `prob-chuva` = 50%
- Avaliar eficiência da barragem sob chuvas frequentes

### Cenário 3: Eventos Extremos
- `prob-chuva` = 80%
- Testar limites do sistema de controle

### Cenário 4: Seca
- `prob-chuva` = 5%
- Avaliar vazões mínimas (próximas às Q7)

---

## 📝 CALIBRAÇÃO RECOMENDADA

Para melhorar a precisão do modelo com dados históricos:

### Parâmetros a Ajustar (no código fonte):

1. **Capacidade da Barragem** (linha 52-53)
   ```netlogo
   set capacidade-maxima 1000000000  ; Ajustar para valor real em m³
   set volume-reservatorio (capacidade-maxima * 0.4)
   ```

2. **Eficiência Técnica** (linha 54)
   ```netlogo
   set eficiencia-tecnica 0.88  ; Calibrar com dados operacionais
   ```

3. **Conversão Chuva → Vazão** (linha 306)
   ```netlogo
   let Cj (intensidade-chuvas * num-subbacias-ativas) * 0.3  ; Ajustar fator 0.3
   ```

4. **Limiares de Nível do Rio** (linhas 343-355)
   ```netlogo
   ; Ajustar limiares baseados em cotas de inundação reais
   ```

### Dados Necessários para Calibração:
- Séries históricas de vazão (montante e jusante)
- Registros de precipitação por sub-bacia
- Cotas de inundação observadas
- Volumes históricos do reservatório
- Registros de abertura de comportas

---

## 🔍 ANÁLISE DOS RESULTADOS

### Métricas de Desempenho

1. **Eficiência de Mitigação**
   ```
   Eficiência (%) = [(Vazão Sem Controle - Vazão Controlada) / Vazão Sem Controle] × 100
   ```

2. **Taxa de Ocupação Média**
   - Ideal: 40-70% (permite amortecer picos)
   - Crítico: > 85% (risco de extravasamento)

3. **Frequência de Eventos Críticos**
   - Eventos com risco > 80
   - Dias com área urbana afetada

4. **Impactos Socioeconômicos Acumulados**
   - Soma dos impactos ao longo da simulação

### Exportação de Dados

Para exportar resultados, adicione ao final do código `go`:

```netlogo
; No final do procedimento 'go':
if ticks mod 10 = 0 [
  file-open "resultados.csv"
  file-print (word ticks "," vazao-controlada "," nivel-rio-jusante "," 
                    risco-enchente "," taxa-ocupacao-reservatorio)
  file-close
]
```

---

## ⚠️ LIMITAÇÕES E CONSIDERAÇÕES

### Limitações do Modelo

1. **Simplificações Hidrológicas**
   - Tempo de concentração não modelado explicitamente
   - Evapotranspiração não considerada
   - Infiltração simplificada

2. **Espacialização**
   - Cada sub-bacia representada por seu centroide
   - Topologia interna das sub-bacias não modelada

3. **Operação da Barragem**
   - Regras de operação simplificadas
   - Não considera manutenções ou falhas

4. **Validação**
   - Modelo não calibrado com dados observados
   - Requer validação com séries históricas

### Melhorias Futuras

1. Integrar modelo de tempo de concentração (Kirpich, SCS)
2. Adicionar módulo de evapotranspiração (Penman-Monteith)
3. Implementar curva de permanência de vazões
4. Conectar com dados de estações pluviométricas reais (API ANA/INMET)
5. Adicionar módulo econômico para custos de enchentes

---

## 📚 REFERÊNCIAS

### Dados Geoespaciais
- **Fonte**: Agência Nacional de Águas e Saneamento Básico (ANA)
- **Sistema de Coordenadas**: SAD 1969 UTM Zone 22S (EPSG:29192)
- **Base Hidrográfica**: Ottocodificação de Bacias Hidrográficas

### Bibliografia Recomendada

1. **Tucci, C. E. M.** (2009). *Hidrologia: Ciência e Aplicação*. UFRGS/ABRH.
2. **Collischonn, W.; Dornelles, F.** (2013). *Hidrologia para Engenharia e Ciências Ambientais*. ABRH.
3. **ANA** (2021). *Manual de Operação de Reservatórios*.
4. **Defesa Civil SC** (2020). *Sistema de Controle de Enchentes do Vale do Itajaí*.

### Links Úteis
- Portal HidroWeb (ANA): https://www.snirh.gov.br/hidroweb/
- Defesa Civil SC: http://www.defesacivil.sc.gov.br/
- NetLogo GIS Extension: https://ccl.northwestern.edu/netlogo/docs/gis.html

---

## 🛠️ SUPORTE TÉCNICO

### Resolução de Problemas

**Problema**: "Shapefile não encontrado"
- **Solução**: Verifique se todos os arquivos (.shp, .dbf, .prj, .shx) estão na mesma pasta do .nlogo

**Problema**: Carregamento muito lento
- **Solução**: Desative `mostrar-poligonos?` para melhorar performance

**Problema**: Extensão GIS não encontrada
- **Solução**: Atualize para NetLogo 6.4 ou superior

**Problema**: Coordenadas fora do mundo NetLogo
- **Solução**: O modelo ajusta automaticamente o envelope - verifique se o shapefile foi carregado corretamente

---

## 👥 CRÉDITOS

**Desenvolvimento**: AuditAI - Agente de Engenharia de Software
**Dados Geoespaciais**: Agência Nacional de Águas (ANA)
**Plataforma**: NetLogo 6.4.0 (Northwestern University)
**Contexto**: Bacia Hidrográfica do Vale do Itajaí - Santa Catarina, Brasil
**Data**: Outubro de 2025

---

## 📄 LICENÇA

Este modelo é fornecido para fins educacionais e de pesquisa.
Os dados geoespaciais são de domínio público (ANA).

---

**Versão**: 1.0 - GIS Integrado
**Última Atualização**: 29/10/2025

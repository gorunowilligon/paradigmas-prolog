# 🧩 Resolvedor de Kakuro em Prolog

Este projeto consiste num resolvedor automático para o puzzle lógico **Kakuro**, desenvolvido inteiramente na linguagem **Prolog**. 

O projeto foi construído para lidar com tabuleiros dinâmicos de qualquer tamanho (NxN) e utiliza o paradigma de **Programação em Lógica com Restrições (Constraint Logic Programming)** para encontrar as soluções de forma otimizada e instantânea.

## 🚀 Tecnologias e Bibliotecas
- **Linguagem:** Prolog
- **Motor Recomendado:** SWI-Prolog
- **Biblioteca Principal:** `library(clpfd)` (Constraint Logic Programming over Finite Domains)

## 🧠 Como Funciona (A Lógica)

Em vez de utilizar uma abordagem ingénua de "Gerar e Testar" (Brute-force / Backtracking padrão), que causaria uma explosão combinatória e demoraria uma eternidade em tabuleiros maiores (ex: 10x10 ou 15x15), este algoritmo modela o problema matematicamente.

Através da biblioteca `clpfd`, aplicamos três regras fundamentais a cada sequência (run) de células brancas:
1. **Domínio:** Cada célula (`Vars ins 1..9`) só pode conter números de 1 a 9.
2. **Unicidade:** Numa mesma sequência contínua, os números não se podem repetir (`all_different(Vars)`).
3. **Soma:** A soma das variáveis de uma sequência deve ser exatamente igual à dica (`sum(Vars, #=, Clue)`).

**Vantagem do Paradigma de Restrições:** O Prolog poda a árvore de pesquisa *antes* de tentar adivinhar os números. Se a soma exigida for pequena ou grande demais para certos números, eles são imediatamente eliminados do domínio das variáveis, resolvendo tabuleiros gigantes em milissegundos.

## 🗺️ Representação do Tabuleiro (Sintaxe)

Para que o código consiga ler tabuleiros reais (como os do site Janko.at), criámos uma notação em formato de matriz (lista de listas). 

Cada elemento no tabuleiro é representado da seguinte forma:
- `b` : Bloco preto vazio (sem dicas).
- `_` : Célula branca vazia (variável que o Prolog irá preencher).
- `r(N)` : Dica para a **direita** (Right), onde `N` é a soma exigida.
- `d(N)` : Dica para **baixo** (Down), onde `N` é a soma exigida.
- `c(D, R)` : Bloco com **dica dupla** (Cruzamento), onde `D` é a soma para baixo e `R` é a soma para a direita.

Exemplo de um tabuleiro 5x5 no código:
```prolog
board(1, [
    [b,       d(17),    d(11),   d(23),       b    ],
    [r(17),   _,        _,       _,           b    ],
    [r(21),   _,        _,       _,           d(4) ],
    [b,       r(6),     _,       _,           _    ],
    [b,       r(11),    _,       _,           _    ]
]).
```

## ⚙️ Destaques Técnicos do Código

- **Resolução de Colunas Sem Loops Complexos:** Em vez de escrever algoritmos complexos para iterar verticalmente sobre as colunas da matriz 2D, utilizamos o predicado `transpose/2` do `clpfd`. Ele roda a matriz 90 graus, transformando as colunas em linhas. Assim, conseguimos reaproveitar a exata mesma lógica de varredura horizontal.
- **Processamento Dinâmico:** Graças ao uso do predicado `maplist/2` e da função `term_variables/2` (que encontra todas as variáveis vazias dinamicamente), o solucionador adapta-se a matrizes de qualquer dimensão sem necessitar de alterações no algoritmo principal.

## 💻 Como Executar

1. Certifique-se de que tem o **SWI-Prolog** instalado na sua máquina.
2. Abra o terminal (ou a linha de comandos) no diretório onde o ficheiro `.pl` está localizado.
3. Carregue o ficheiro Prolog:
   ```bash
   swipl kakuro.pl
   ```
4. Execute a função de teste passando o ID do tabuleiro que deseja resolver. Por exemplo, para resolver o tabuleiro 1:
   ```prolog
   ?- test_board(1).
   ```
5. O programa irá calcular as restrições e imprimir o tabuleiro com os números preenchidos de forma formatada e legível no próprio terminal.

## 📝 Notas para Desenvolvimento e Edição
Para adicionar tabuleiros maiores (ex: 15x15), é altamente recomendável criar a matriz inicialmente num programa de folhas de cálculo (como o Excel ou o Google Sheets) e formatar o alinhamento em colunas. Isto evita erros de sintaxe invisíveis (como falta de vírgulas ou de `_`) que quebram o fluxo da matriz em editores de texto tradicionais.

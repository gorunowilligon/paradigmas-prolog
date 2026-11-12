:- use_module(library(clpfd)). % Importa a biblioteca de Programação em Lógica com Restrições sobre Domínios Finitos (CLPFD). É o motor matemático que resolve o puzzle eficientemente sem tentativa e erro cega.
 
% --- Regras Fundamentais ---
% Aplica as regras matemáticas do Kakuro a uma lista de variáveis (células brancas).
apply_kakuro_rules(Clue, Vars) :-
    Vars ins 1..9,            % Restrição de domínio: cada variável na sequência tem de ser um número entre 1 e 9.
    all_different(Vars),      % Restrição de unicidade: não pode haver números repetidos na mesma sequência.
    sum(Vars, #=, Clue).      % Restrição de soma: a soma de todas as variáveis da sequência tem de ser exatamente igual à dica (Clue).
 
% --- Extrair a "Run" (sequência) de variáveis ---
% O objetivo destas duas regras é ler uma linha/coluna e recolher todas as células brancas consecutivas após uma dica.
 
% Passo recursivo: se o próximo elemento (Cell) for uma variável livre (célula branca),
% adiciona-a à sequência (Run) e continua a extrair as próximas células (Rest).
extract_run([Cell | Rest], [Cell | Run], Remainder) :-
    var(Cell), !,             % Verifica se Cell é uma variável não instanciada. O '!' (cut) impede que o Prolog tente a regra seguinte (retrocesso) se esta for verdadeira.
    extract_run(Rest, Run, Remainder).
 
% Condição de paragem: se a lista acabou ou se a célula NÃO for uma variável (é um bloco preto ou uma dica),
% a extração pára. A sequência fica vazia e devolvemos o que sobrou (List -> Remainder).
extract_run(List, [], List).
 
% --- Recolhe as sequências ("runs") de uma linha ---
% Percorre uma linha e devolve uma lista de pares Soma-Células, um por cada dica para a direita.
% Aqui ainda NÃO se aplica nenhuma restrição: apenas se descobre a estrutura do tabuleiro.

% Caso base: se a linha estiver vazia, não há mais sequências.
row_runs([], []).

% Se a célula atual for uma variável (célula em branco), ignora-a e avança.
% Isto evita que o Prolog unifique uma célula branca com uma dica nas cláusulas seguintes.
row_runs([Cell | Rest], Runs) :-
    var(Cell), !,
    row_runs(Rest, Runs).

% Se encontrar uma dica para a direita "r(Sum)":
row_runs([r(Sum) | Rest], [Sum-Run | Runs]) :- !,   % O '!' descarta as cláusulas seguintes: uma dica nunca é tratada como um bloco qualquer pela regra genérica lá em baixo.
    extract_run(Rest, Run, Remainder),              % Extrai todas as células em branco imediatamente a seguir.
    row_runs(Remainder, Runs).                      % Continua a varrer o que sobrou da linha.

% Se encontrar uma dica dupla "c(Down, Right)":
row_runs([c(_, Sum) | Rest], [Sum-Run | Runs]) :- !,
    extract_run(Rest, Run, Remainder),              % Ignora o "Down" (o _) e usa apenas a soma "Right" (Sum).
    row_runs(Remainder, Runs).

% Se for qualquer outra coisa (por exemplo, um bloco preto 'b' ou uma dica para baixo 'd(N)'), ignora e avança.
row_runs([_ | Rest], Runs) :-
    row_runs(Rest, Runs).

% --- Recolhe as sequências de uma coluna ---
% Funciona com a mesma lógica do row_runs, mas foca-se nas dicas verticais.
col_runs([], []).

col_runs([Cell | Rest], Runs) :-
    var(Cell), !,
    col_runs(Rest, Runs).

% Se encontrar uma dica para baixo "d(Sum)":
col_runs([d(Sum) | Rest], [Sum-Run | Runs]) :- !,
    extract_run(Rest, Run, Remainder),
    col_runs(Remainder, Runs).

% Se encontrar uma dica dupla "c(Down, Right)":
col_runs([c(Sum, _) | Rest], [Sum-Run | Runs]) :- !,
    extract_run(Rest, Run, Remainder),              % Desta vez, usa apenas o "Down" (Sum) e ignora o "Right" (_).
    col_runs(Remainder, Runs).

col_runs([_ | Rest], Runs) :-
    col_runs(Rest, Runs).

% Recolhe todas as sequências do tabuleiro: primeiro as horizontais, depois as verticais.
board_runs(Board, Runs) :-
    maplist(row_runs, Board, H0), append(H0, H),
    transpose(Board, Columns),                      % Transpõe a matriz: as colunas passam a ser linhas, por isso a mesma lógica de varrimento serve.
    maplist(col_runs, Columns, V0), append(V0, V),
    append(H, V, Runs).

% --- O solucionador principal ---
% A resolução é feita em duas fases: primeiro lê-se a estrutura (todas as sequências) e só depois
% se aplicam as restrições. A ordem importa: extract_run reconhece uma célula branca por ela ainda
% ser uma variável livre. Se as restrições fossem aplicadas à medida que o tabuleiro é lido, a
% propagação do CLP(FD) podia fixar o valor de uma célula antes de a coluna dela ser lida; essa
% célula deixava de parecer branca, a sequência ficava cortada e um tabuleiro válido era rejeitado.
solve_kakuro(Board) :-
    board_runs(Board, Runs),          % 1. Recolhe TODAS as sequências (linhas e colunas) antes de aplicar qualquer restrição.
    term_variables(Board, Cells),     % 2. Guarda as células brancas pela ordem em que aparecem no tabuleiro.
    maplist(apply_run, Runs),         % 3. Só agora aplica as regras do Kakuro (domínio, diferença e soma) a cada sequência.
    components(Runs, Cells, Groups),  % 4. Separa as células em grupos independentes (que não partilham nenhuma sequência).
    maplist(label_group, Groups).     % 5. Faz a pesquisa em cada grupo separadamente. Assim, num tabuleiro grande composto por várias zonas independentes, o retrocesso de uma zona nunca refaz o trabalho das outras.

apply_run(Sum-Run) :- apply_kakuro_rules(Sum, Run).

label_group(Vars) :- labeling([ffc], Vars).   % 'ffc': escolhe primeiro a variável com menor domínio (desempate: a que participa em mais restrições).

% Agrupa as variáveis em componentes ligados: duas variáveis estão no mesmo grupo se
% estiverem (direta ou indiretamente) ligadas por sequências.
% Dentro de cada grupo as variáveis ficam pela ordem do tabuleiro (Cells): o 'ffc' usa essa ordem
% como último critério de desempate, e ela dá uma pesquisa bem mais curta nos tabuleiros grandes.
components(Runs, Cells, Groups) :-
    pairs_values(Runs, Lists),
    foldl(merge_run, Lists, [], Groups0),
    maplist(board_order(Cells), Groups0, Groups).

merge_run(Run, Groups0, [Merged | Others]) :-
    partition(shares_var(Run), Groups0, Touching, Others),
    append([Run | Touching], Merged0),
    term_variables(Merged0, Merged).

shares_var(Run, Group) :- member(A, Run), member(B, Group), A == B, !.

% Reordena as variáveis de um grupo pela ordem em que aparecem no tabuleiro.
board_order(Cells, Group, Ordered) :- include(in_group(Group), Cells, Ordered).

in_group(Group, Cell) :- member(V, Group), V == Cell, !.

% --- Validação estrutural do tabuleiro ---
% O solver acima NÃO verifica se o tabuleiro é um Kakuro legal. Uma célula branca que
% só pertença a uma sequência (sem dica na outra direção) fica sem restrição e o tabuleiro
% era dado como "resolvido". valid_board/1 rejeita esses casos antes de resolver.

% Soma mínima/máxima possível para N dígitos distintos de 1..9.
run_ok(S-Run) :-
    length(Run, N),
    N >= 1, N =< 9,                    % sem runs vazios nem com mais de 9 células
    integer(S),
    Min is N*(N+1)//2,
    Max is N*(19-N)//2,
    S >= Min, S =< Max.                % soma alcançável com dígitos distintos

% Todas as células brancas aparecem exatamente uma vez em runs horizontais e uma vez em verticais.
valid_board(Board) :-
    must_be(list(list), Board),
    Board \== [],                                      % tabuleiro não vazio
    forall(( member(Row, Board), member(Cell, Row) ), cell_ok(Cell)),  % só células reconhecidas
    maplist(length_of(Board), Board),                  % tabuleiro retangular
    transpose(Board, Cols),
    maplist(row_runs, Board, HRuns0), append(HRuns0, HRuns),
    maplist(col_runs, Cols,  VRuns0), append(VRuns0, VRuns),
    maplist(run_ok, HRuns),
    maplist(run_ok, VRuns),
    term_variables(Board, Vars),
    forall(member(V, Vars),
           ( count_in(V, HRuns, 1), count_in(V, VRuns, 1) )).  % sem célula "órfã"

% Células aceites: branca (variável), b, r(_), d(_), c(_,_). Números soltos etc. são rejeitados.
cell_ok(C) :- var(C), !.
cell_ok(b).
cell_ok(r(_)).
cell_ok(d(_)).
cell_ok(c(_, _)).

length_of([R0|_], R) :- length(R0, N), length(R, N).
count_in(V, Runs, N) :-
    findall(x, ( member(_-Run, Runs), member(C, Run), C == V ), L),
    length(L, N).

% --- Unicidade ---
% Resolve e verifica que NÃO existe uma segunda solução diferente.
% (Os "true ;" extra no terminal vêm de choicepoints do labeling, não de soluções diferentes.)
solve_unique(Board) :-
    valid_board(Board),
    term_variables(Board, Vars),
    findall(Vars, limit(2, solve_kakuro(Board)), Sols),
    Sols = [Vars].                     % exatamente uma solução; unifica o tabuleiro com ela

% --- Funções de Impressão (Output visual no terminal) ---
% Caso base: se já não houver linhas no tabuleiro, termina a impressão.
print_board([]).
 
% Imprime a primeira linha da matriz, muda para a linha de baixo (nl - new line) e repete recursivamente.
print_board([Row | Rest]) :-
    print_row(Row),
    nl,                  
    print_board(Rest).
 
% Caso base: se a linha estiver vazia, termina.
print_row([]).
 
% Imprime as linhas, com cada célula formatada
print_row([Cell | Rest]) :-
    format('~|~w~t~12+', [Cell]),      
    print_row(Rest).
 
% --- Base de Dados de Tabuleiros ---
% Tabuleiro 1 (5x5)
board(1, [
    [ b         , d(17)     , d(11)     , d(23)     , b         ],
    [ r(17)     , _         , _         , _         , b         ],
    [ r(21)     , _         , _         , _         , d(4)      ],
    [ b         , r(6)      , _         , _         , _         ],
    [ b         , r(11)     , _         , _         , _         ]
]).
 
% Tabuleiro 2 (10x12)
board(2, [
    [ b         , b         , d(21)     , d(11)     , b         , d(16)     , d(16)     , d(23)     , b         , d(10)     , d(11)     , b         ],
    [ b         , c(16, 3)  , _         , _         , r(19)     , _         , _         , _         , r(8)      , _         , _         , d(4)      ],
    [ r(22)     , _         , _         , _         , c(34, 21) , _         , _         , _         , c(16, 7)  , _         , _         , _         ],
    [ r(33)     , _         , _         , _         , _         , _         , r(16)     , _         , _         , _         , _         , _         ],
    [ b         , r(10)     , _         , _         , _         , _         , b         , c(15, 6)  , _         , _         , _         , b         ],
    [ b         , b         , d(29)     , c(10, 8)  , _         , _         , r(3)      , _         , _         , d(29)     , d(25)     , b         ],
    [ b         , c(16, 17) , _         , _         , _         , d(24)     , r(11)     , _         , _         , _         , _         , d(16)     ],
    [ r(34)     , _         , _         , _         , _         , _         , c(16, 33) , _         , _         , _         , _         , _         ],
    [ r(14)     , _         , _         , _         , r(20)     , _         , _         , _         , r(23)     , _         , _         , _         ],
    [ b         , r(12)     , _         , _         , r(22)     , _         , _         , _         , r(16)     , _         , _         , b         ]
]).
 
% Tabuleiro 3 (10x12)
board(3, [
    [ b         , d(4)      , d(6)      , b         , d(30)     , d(17)     , b         , d(3)      , d(13)     , b         , d(16)     , d(29)     ],
    [ r(3)      , _         , _         , c(11, 16) , _         , _         , r(4)      , _         , _         , c(13, 13) , _         , _         ],
    [ r(23)     , _         , _         , _         , _         , _         , c(15, 15) , _         , _         , _         , _         , _         ],
    [ b         , r(16)     , _         , _         , _         , _         , _         , c(3, 30)  , _         , _         , _         , _         ],
    [ b         , b         , c(34, 10) , _         , _         , c(4, 6)   , _         , _         , _         , c(22, 9)  , _         , _         ],
    [ b         , c(11, 7)  , _         , _         , c(30, 7)  , _         , _         , _         , c(10, 5)  , _         , _         , b         ],
    [ r(10)     , _         , _         , c(12, 15) , _         , _         , _         , c(12, 9)  , _         , _         , d(22)     , b         ],
    [ r(29)     , _         , _         , _         , _         , c(10, 15) , _         , _         , _         , _         , _         , d(15)     ],
    [ r(16)     , _         , _         , _         , _         , _         , r(34)     , _         , _         , _         , _         , _         ],
    [ r(12)     , _         , _         , r(17)     , _         , _         , r(4)      , _         , _         , r(17)     , _         , _         ]
]).
 
%Tabuleiro 4 (10x12)
board(4, [
    [ b         , d(12)     , d(10)     , d(14)     , b         , b         , b         , d(13)     , d(34)     , d(16)     , d(29)     , b         ],
    [ r(8)      , _         , _         , _         , d(10)     , b         , c(6, 30)  , _         , _         , _         , _         , d(23)     ],
    [ r(28)     , _         , _         , _         , _         , c(22, 38) , _         , _         , _         , _         , _         , _         ],
    [ r(4)      , _         , _         , c(6, 15)  , _         , _         , _         , _         , _         , c(23, 16) , _         , _         ],
    [ b         , r(4)      , _         , _         , c(22, 9)  , _         , _         , c(8, 29)  , _         , _         , _         , _         ],
    [ b         , d(7)      , c(10, 12) , _         , _         , _         , c(24, 18) , _         , _         , _         , d(29)     , b         ],
    [ r(11)     , _         , _         , _         , _         , c(14, 11) , _         , _         , c(17, 14) , _         , _         , d(23)     ],
    [ r(4)      , _         , _         , c(3, 35)  , _         , _         , _         , _         , _         , c(16, 16) , _         , _         ],
    [ r(22)     , _         , _         , _         , _         , _         , _         , r(30)     , _         , _         , _         , _         ],
    [ b         , r(15)     , _         , _         , _         , _         , b         , b         , r(22)     , _         , _         , _         ]
]).
 
% Tabuleiro 5 (17x17)
board(5, [
    [ b         , b         , b         , b         , b         , b         , d(16)     , d(26)     , d(6)      , b         , b         , b         , b         , d(23)     , d(39)     , b         , b         ],
    [ b         , b         , b         , d(7)      , d(36)     , c(3, 11)  , _         , _         , _         , d(28)     , d(32)     , b         , c(3, 8)   , _         , _         , d(11)     , b         ],
    [ b         , b         , c(44, 41) , _         , _         , _         , _         , _         , _         , _         , _         , c(6, 15)  , _         , _         , _         , _         , d(4)      ],
    [ b         , c(5, 21)  , _         , _         , _         , _         , _         , _         , c(14, 41) , _         , _         , _         , _         , _         , _         , _         , _         ],
    [ r(10)     , _         , _         , _         , _         , c(12, 28) , _         , _         , _         , _         , _         , _         , d(35)     , c(16, 6)  , _         , _         , _         ],
    [ r(4)      , _         , _         , c(9, 13)  , _         , _         , _         , c(25, 24) , _         , _         , _         , c(25, 26) , _         , _         , _         , _         , b         ],
    [ b         , c(23, 11) , _         , _         , _         , _         , c(20, 37) , _         , _         , _         , _         , _         , _         , _         , _         , d(37)     , b         ],
    [ r(30)     , _         , _         , _         , _         , c(16, 15) , _         , _         , _         , _         , c(28, 11) , _         , _         , c(38, 4)  , _         , _         , d(7)      ],
    [ r(16)     , _         , _         , c(37, 26) , _         , _         , _         , _         , c(28, 40) , _         , _         , _         , _         , _         , _         , _         , _         ],
    [ r(38)     , _         , _         , _         , _         , _         , _         , _         , _         , c(19, 30) , _         , _         , _         , _         , c(11, 3)  , _         , _         ],
    [ b         , r(12)     , _         , _         , c(12, 3)  , _         , _         , c(30, 30) , _         , _         , _         , _         , c(12, 11) , _         , _         , _         , _         ],
    [ b         , b         , c(10, 43) , _         , _         , _         , _         , _         , _         , _         , _         , c(15, 29) , _         , _         , _         , _         , d(10)     ],
    [ b         , c(16, 10) , _         , _         , _         , _         , c(16, 19) , _         , _         , _         , c(24, 6)  , _         , _         , _         , c(22, 4)  , _         , _         ],
    [ r(16)     , _         , _         , _         , d(24)     , c(10, 38) , _         , _         , _         , _         , _         , _         , c(15, 29) , _         , _         , _         , _         ],
    [ r(42)     , _         , _         , _         , _         , _         , _         , _         , _         , c(17, 39) , _         , _         , _         , _         , _         , _         , b         ],
    [ b         , r(16)     , _         , _         , _         , _         , r(39)     , _         , _         , _         , _         , _         , _         , _         , _         , b         , b         ],
    [ b         , b         , r(9)      , _         , _         , b         , b         , b         , r(18)     , _         , _         , _         , b         , b         , b         , b         , b         ]
]).
 
% --- Tabuleiros adicionais (6-13) ---
% Gerados e verificados com um solver independente em Python: todos tem solucao UNICA.
% Os tabuleiros 9-13 sao compostos por blocos independentes, cada um com solucao unica,
% colados lado a lado (a solucao do conjunto e unica porque os blocos nao partilham celulas).

% Tabuleiro 6 (5x5)
board(6, [
    [ b           , b           , d(18)       , d(17)       , b           ],
    [ b           , r(3)        , _           , _           , d(4)        ],
    [ b           , c(11, 9)    , _           , _           , _           ],
    [ r(21)       , _           , _           , _           , _           ],
    [ r(17)       , _           , _           , b           , b           ]
]).

% Tabuleiro 7 (5x5)
board(7, [
    [ b           , d(3)        , d(12)       , d(24)       , b           ],
    [ r(6)        , _           , _           , _           , d(16)       ],
    [ r(26)       , _           , _           , _           , _           ],
    [ b           , b           , r(6)        , _           , _           ],
    [ b           , b           , r(17)       , _           , _           ]
]).

% Tabuleiro 8 (10x6)
board(8, [
    [ b           , d(17)       , d(7)        , b           , b           , b           ],
    [ r(4)        , _           , _           , d(40)       , d(18)       , b           ],
    [ r(26)       , _           , _           , _           , _           , d(17)       ],
    [ r(34)       , _           , _           , _           , _           , _           ],
    [ b           , b           , c(25, 11)   , _           , _           , _           ],
    [ b           , r(11)       , _           , _           , b           , b           ],
    [ b           , c(16, 17)   , _           , _           , b           , b           ],
    [ r(22)       , _           , _           , _           , d(15)       , b           ],
    [ r(17)       , _           , _           , _           , _           , b           ],
    [ b           , b           , r(13)       , _           , _           , b           ]
]).

% Tabuleiro 9 (10x10) - composto por 4 blocos 5x5 independentes
board(9, [
    [ b           , b           , b           , d(20)       , d(9)        , b           , b           , b           , d(23)       , d(14)       ],
    [ b           , d(18)       , c(13, 4)    , _           , _           , b           , b           , r(3)        , _           , _           ],
    [ r(28)       , _           , _           , _           , _           , b           , d(4)        , c(8, 8)     , _           , _           ],
    [ r(14)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , b           , b           , r(12)       , _           , _           , _           , _           ],
    [ b           , d(18)       , d(28)       , b           , b           , b           , b           , b           , d(20)       , d(29)       ],
    [ r(5)        , _           , _           , b           , b           , b           , b           , r(7)        , _           , _           ],
    [ r(16)       , _           , _           , d(11)       , d(3)        , b           , d(14)       , c(3, 17)    , _           , _           ],
    [ r(20)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ b           , r(19)       , _           , _           , _           , r(16)       , _           , _           , _           , _           ]
]).

% Tabuleiro 10 (15x15) - composto por 9 blocos 5x5 independentes
board(10, [
    [ b           , d(25)       , d(15)       , b           , b           , b           , b           , b           , d(23)       , d(14)       , b           , b           , b           , d(20)       , d(29)       ],
    [ r(3)        , _           , _           , b           , b           , b           , b           , r(3)        , _           , _           , b           , b           , r(7)        , _           , _           ],
    [ r(9)        , _           , _           , d(3)        , d(9)        , b           , d(4)        , c(8, 8)     , _           , _           , b           , d(14)       , c(3, 17)    , _           , _           ],
    [ r(26)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , _           , _           , r(12)       , _           , _           , _           , _           , r(16)       , _           , _           , _           , _           ],
    [ b           , d(12)       , d(21)       , d(5)        , d(10)       , b           , d(18)       , d(28)       , b           , b           , b           , b           , b           , d(20)       , d(9)        ],
    [ r(11)       , _           , _           , _           , _           , r(5)        , _           , _           , b           , b           , b           , d(18)       , c(13, 4)    , _           , _           ],
    [ r(19)       , _           , _           , _           , _           , r(16)       , _           , _           , d(11)       , d(3)        , r(28)       , _           , _           , _           , _           ],
    [ r(4)        , _           , _           , b           , b           , r(20)       , _           , _           , _           , _           , r(14)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , b           , b           , b           , r(19)       , _           , _           , _           , r(14)       , _           , _           , b           , b           ],
    [ b           , d(17)       , d(3)        , d(22)       , d(13)       , b           , d(19)       , d(14)       , b           , b           , b           , b           , d(18)       , d(17)       , b           ],
    [ r(15)       , _           , _           , _           , _           , r(10)       , _           , _           , b           , b           , b           , r(3)        , _           , _           , d(4)        ],
    [ r(26)       , _           , _           , _           , _           , r(3)        , _           , _           , d(16)       , d(9)        , b           , c(11, 9)    , _           , _           , _           ],
    [ b           , b           , r(3)        , _           , _           , r(22)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , _           ],
    [ b           , b           , r(11)       , _           , _           , b           , r(23)       , _           , _           , _           , r(17)       , _           , _           , b           , b           ]
]).

% Tabuleiro 11 (20x20) - composto por 16 blocos 5x5 independentes
board(11, [
    [ b           , b           , d(18)       , d(17)       , b           , b           , d(3)        , d(12)       , d(24)       , b           , b           , b           , b           , d(18)       , d(19)       , b           , b           , b           , d(23)       , d(14)       ],
    [ b           , r(3)        , _           , _           , d(4)        , r(6)        , _           , _           , _           , d(16)       , b           , b           , r(10)       , _           , _           , b           , b           , r(3)        , _           , _           ],
    [ b           , c(11, 9)    , _           , _           , _           , r(26)       , _           , _           , _           , _           , b           , d(3)        , c(17, 3)    , _           , _           , b           , d(4)        , c(8, 8)     , _           , _           ],
    [ r(21)       , _           , _           , _           , _           , b           , b           , r(6)        , _           , _           , r(25)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ r(17)       , _           , _           , b           , b           , b           , b           , r(17)       , _           , _           , r(19)       , _           , _           , _           , b           , r(12)       , _           , _           , _           , _           ],
    [ b           , d(17)       , d(3)        , d(22)       , d(13)       , b           , d(17)       , d(11)       , d(23)       , b           , b           , b           , b           , d(20)       , d(29)       , b           , d(25)       , d(15)       , b           , b           ],
    [ r(15)       , _           , _           , _           , _           , r(17)       , _           , _           , _           , b           , b           , b           , r(7)        , _           , _           , r(3)        , _           , _           , b           , b           ],
    [ r(26)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , d(4)        , b           , d(14)       , c(3, 17)    , _           , _           , r(9)        , _           , _           , d(3)        , d(9)        ],
    [ b           , b           , r(3)        , _           , _           , b           , r(6)        , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ b           , b           , r(11)       , _           , _           , b           , r(11)       , _           , _           , _           , r(16)       , _           , _           , _           , _           , r(14)       , _           , _           , _           , _           ],
    [ b           , d(24)       , d(17)       , b           , b           , b           , d(18)       , d(28)       , b           , b           , b           , d(19)       , d(14)       , b           , b           , b           , d(12)       , d(21)       , d(5)        , d(10)       ],
    [ r(4)        , _           , _           , b           , b           , r(5)        , _           , _           , b           , b           , r(10)       , _           , _           , b           , b           , r(11)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , d(10)       , d(5)        , r(16)       , _           , _           , d(11)       , d(3)        , r(3)        , _           , _           , d(16)       , d(9)        , r(19)       , _           , _           , _           , _           ],
    [ r(11)       , _           , _           , _           , _           , r(20)       , _           , _           , _           , _           , r(22)       , _           , _           , _           , _           , r(4)        , _           , _           , b           , b           ],
    [ r(27)       , _           , _           , _           , _           , b           , r(19)       , _           , _           , _           , b           , r(23)       , _           , _           , _           , r(14)       , _           , _           , b           , b           ],
    [ b           , b           , b           , d(20)       , d(9)        , b           , d(17)       , d(11)       , d(23)       , b           , b           , d(25)       , d(15)       , b           , b           , b           , d(18)       , d(28)       , b           , b           ],
    [ b           , d(18)       , c(13, 4)    , _           , _           , r(17)       , _           , _           , _           , b           , r(3)        , _           , _           , b           , b           , r(5)        , _           , _           , b           , b           ],
    [ r(28)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , d(4)        , r(9)        , _           , _           , d(3)        , d(9)        , r(16)       , _           , _           , d(11)       , d(3)        ],
    [ r(14)       , _           , _           , _           , _           , b           , r(6)        , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(20)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , b           , b           , b           , r(11)       , _           , _           , _           , r(14)       , _           , _           , _           , _           , b           , r(19)       , _           , _           , _           ]
]).

% Tabuleiro 12 (25x25) - composto por 25 blocos 5x5 independentes
board(12, [
    [ b           , d(12)       , d(21)       , d(5)        , d(10)       , b           , d(18)       , d(28)       , b           , b           , b           , b           , d(18)       , d(17)       , b           , b           , d(25)       , d(15)       , b           , b           , b           , b           , b           , d(18)       , d(19)       ],
    [ r(11)       , _           , _           , _           , _           , r(5)        , _           , _           , b           , b           , b           , r(3)        , _           , _           , d(4)        , r(3)        , _           , _           , b           , b           , b           , b           , r(10)       , _           , _           ],
    [ r(19)       , _           , _           , _           , _           , r(16)       , _           , _           , d(11)       , d(3)        , b           , c(11, 9)    , _           , _           , _           , r(9)        , _           , _           , d(3)        , d(9)        , b           , d(3)        , c(17, 3)    , _           , _           ],
    [ r(4)        , _           , _           , b           , b           , r(20)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(25)       , _           , _           , _           , _           ],
    [ r(14)       , _           , _           , b           , b           , b           , r(19)       , _           , _           , _           , r(17)       , _           , _           , b           , b           , r(14)       , _           , _           , _           , _           , r(19)       , _           , _           , _           , b           ],
    [ b           , d(19)       , d(14)       , b           , b           , b           , d(24)       , d(17)       , b           , b           , b           , b           , b           , d(20)       , d(29)       , b           , b           , b           , d(20)       , d(9)        , b           , b           , b           , d(23)       , d(14)       ],
    [ r(10)       , _           , _           , b           , b           , r(4)        , _           , _           , b           , b           , b           , b           , r(7)        , _           , _           , b           , d(18)       , c(13, 4)    , _           , _           , b           , b           , r(3)        , _           , _           ],
    [ r(3)        , _           , _           , d(16)       , d(9)        , r(14)       , _           , _           , d(10)       , d(5)        , b           , d(14)       , c(3, 17)    , _           , _           , r(28)       , _           , _           , _           , _           , b           , d(4)        , c(8, 8)     , _           , _           ],
    [ r(22)       , _           , _           , _           , _           , r(11)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(14)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ b           , r(23)       , _           , _           , _           , r(27)       , _           , _           , _           , _           , r(16)       , _           , _           , _           , _           , r(14)       , _           , _           , b           , b           , r(12)       , _           , _           , _           , _           ],
    [ b           , d(17)       , d(3)        , d(22)       , d(13)       , b           , d(17)       , d(11)       , d(23)       , b           , b           , d(3)        , d(12)       , d(24)       , b           , b           , d(19)       , d(14)       , b           , b           , b           , d(25)       , d(15)       , b           , b           ],
    [ r(15)       , _           , _           , _           , _           , r(17)       , _           , _           , _           , b           , r(6)        , _           , _           , _           , d(16)       , r(10)       , _           , _           , b           , b           , r(3)        , _           , _           , b           , b           ],
    [ r(26)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , d(4)        , r(26)       , _           , _           , _           , _           , r(3)        , _           , _           , d(16)       , d(9)        , r(9)        , _           , _           , d(3)        , d(9)        ],
    [ b           , b           , r(3)        , _           , _           , b           , r(6)        , _           , _           , _           , b           , b           , r(6)        , _           , _           , r(22)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           ],
    [ b           , b           , r(11)       , _           , _           , b           , r(11)       , _           , _           , _           , b           , b           , r(17)       , _           , _           , b           , r(23)       , _           , _           , _           , r(14)       , _           , _           , _           , _           ],
    [ b           , b           , d(18)       , d(17)       , b           , b           , d(25)       , d(15)       , b           , b           , b           , b           , b           , d(20)       , d(29)       , b           , d(12)       , d(21)       , d(5)        , d(10)       , b           , d(19)       , d(14)       , b           , b           ],
    [ b           , r(3)        , _           , _           , d(4)        , r(3)        , _           , _           , b           , b           , b           , b           , r(7)        , _           , _           , r(11)       , _           , _           , _           , _           , r(10)       , _           , _           , b           , b           ],
    [ b           , c(11, 9)    , _           , _           , _           , r(9)        , _           , _           , d(3)        , d(9)        , b           , d(14)       , c(3, 17)    , _           , _           , r(19)       , _           , _           , _           , _           , r(3)        , _           , _           , d(16)       , d(9)        ],
    [ r(21)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(4)        , _           , _           , b           , b           , r(22)       , _           , _           , _           , _           ],
    [ r(17)       , _           , _           , b           , b           , r(14)       , _           , _           , _           , _           , r(16)       , _           , _           , _           , _           , r(14)       , _           , _           , b           , b           , b           , r(23)       , _           , _           , _           ],
    [ b           , b           , d(18)       , d(17)       , b           , b           , d(25)       , d(15)       , b           , b           , b           , d(12)       , d(21)       , d(5)        , d(10)       , b           , d(17)       , d(11)       , d(23)       , b           , b           , d(17)       , d(11)       , d(23)       , b           ],
    [ b           , r(3)        , _           , _           , d(4)        , r(3)        , _           , _           , b           , b           , r(11)       , _           , _           , _           , _           , r(17)       , _           , _           , _           , b           , r(17)       , _           , _           , _           , b           ],
    [ b           , c(11, 9)    , _           , _           , _           , r(9)        , _           , _           , d(3)        , d(9)        , r(19)       , _           , _           , _           , _           , r(21)       , _           , _           , _           , d(4)        , r(21)       , _           , _           , _           , d(4)        ],
    [ r(21)       , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , r(4)        , _           , _           , b           , b           , b           , r(6)        , _           , _           , _           , b           , r(6)        , _           , _           , _           ],
    [ r(17)       , _           , _           , b           , b           , r(14)       , _           , _           , _           , _           , r(14)       , _           , _           , b           , b           , b           , r(11)       , _           , _           , _           , b           , r(11)       , _           , _           , _           ]
]).

% Tabuleiro 13 (30x30) - composto por blocos 10x12 e 10x6 independentes
board(13, [
    [ b           , d(12)       , d(10)       , d(14)       , b           , b           , b           , d(13)       , d(34)       , d(16)       , d(29)       , b           , b           , d(4)        , d(6)        , b           , d(30)       , d(17)       , b           , d(3)        , d(13)       , b           , d(16)       , d(29)       , b           , d(17)       , d(7)        , b           , b           , b           ],
    [ r(8)        , _           , _           , _           , d(10)       , b           , c(6, 30)    , _           , _           , _           , _           , d(23)       , r(3)        , _           , _           , c(11, 16)   , _           , _           , r(4)        , _           , _           , c(13, 13)   , _           , _           , r(4)        , _           , _           , d(40)       , d(18)       , b           ],
    [ r(28)       , _           , _           , _           , _           , c(22, 38)   , _           , _           , _           , _           , _           , _           , r(23)       , _           , _           , _           , _           , _           , c(15, 15)   , _           , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , d(17)       ],
    [ r(4)        , _           , _           , c(6, 15)    , _           , _           , _           , _           , _           , c(23, 16)   , _           , _           , b           , r(16)       , _           , _           , _           , _           , _           , c(3, 30)    , _           , _           , _           , _           , r(34)       , _           , _           , _           , _           , _           ],
    [ b           , r(4)        , _           , _           , c(22, 9)    , _           , _           , c(8, 29)    , _           , _           , _           , _           , b           , b           , c(34, 10)   , _           , _           , c(4, 6)     , _           , _           , _           , c(22, 9)    , _           , _           , b           , b           , c(25, 11)   , _           , _           , _           ],
    [ b           , d(7)        , c(10, 12)   , _           , _           , _           , c(24, 18)   , _           , _           , _           , d(29)       , b           , b           , c(11, 7)    , _           , _           , c(30, 7)    , _           , _           , _           , c(10, 5)    , _           , _           , b           , b           , r(11)       , _           , _           , b           , b           ],
    [ r(11)       , _           , _           , _           , _           , c(14, 11)   , _           , _           , c(17, 14)   , _           , _           , d(23)       , r(10)       , _           , _           , c(12, 15)   , _           , _           , _           , c(12, 9)    , _           , _           , d(22)       , b           , b           , c(16, 17)   , _           , _           , b           , b           ],
    [ r(4)        , _           , _           , c(3, 35)    , _           , _           , _           , _           , _           , c(16, 16)   , _           , _           , r(29)       , _           , _           , _           , _           , c(10, 15)   , _           , _           , _           , _           , _           , d(15)       , r(22)       , _           , _           , _           , d(15)       , b           ],
    [ r(22)       , _           , _           , _           , _           , _           , _           , r(30)       , _           , _           , _           , _           , r(16)       , _           , _           , _           , _           , _           , r(34)       , _           , _           , _           , _           , _           , r(17)       , _           , _           , _           , _           , b           ],
    [ b           , r(15)       , _           , _           , _           , _           , b           , b           , r(22)       , _           , _           , _           , r(12)       , _           , _           , r(17)       , _           , _           , r(4)        , _           , _           , r(17)       , _           , _           , b           , b           , r(13)       , _           , _           , b           ],
    [ b           , b           , d(21)       , d(11)       , b           , d(16)       , d(16)       , d(23)       , b           , d(10)       , d(11)       , b           , b           , d(4)        , d(6)        , b           , d(30)       , d(17)       , b           , d(3)        , d(13)       , b           , d(16)       , d(29)       , b           , d(17)       , d(7)        , b           , b           , b           ],
    [ b           , c(16, 3)    , _           , _           , r(19)       , _           , _           , _           , r(8)        , _           , _           , d(4)        , r(3)        , _           , _           , c(11, 16)   , _           , _           , r(4)        , _           , _           , c(13, 13)   , _           , _           , r(4)        , _           , _           , d(40)       , d(18)       , b           ],
    [ r(22)       , _           , _           , _           , c(34, 21)   , _           , _           , _           , c(16, 7)    , _           , _           , _           , r(23)       , _           , _           , _           , _           , _           , c(15, 15)   , _           , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , d(17)       ],
    [ r(33)       , _           , _           , _           , _           , _           , r(16)       , _           , _           , _           , _           , _           , b           , r(16)       , _           , _           , _           , _           , _           , c(3, 30)    , _           , _           , _           , _           , r(34)       , _           , _           , _           , _           , _           ],
    [ b           , r(10)       , _           , _           , _           , _           , b           , c(15, 6)    , _           , _           , _           , b           , b           , b           , c(34, 10)   , _           , _           , c(4, 6)     , _           , _           , _           , c(22, 9)    , _           , _           , b           , b           , c(25, 11)   , _           , _           , _           ],
    [ b           , b           , d(29)       , c(10, 8)    , _           , _           , r(3)        , _           , _           , d(29)       , d(25)       , b           , b           , c(11, 7)    , _           , _           , c(30, 7)    , _           , _           , _           , c(10, 5)    , _           , _           , b           , b           , r(11)       , _           , _           , b           , b           ],
    [ b           , c(16, 17)   , _           , _           , _           , d(24)       , r(11)       , _           , _           , _           , _           , d(16)       , r(10)       , _           , _           , c(12, 15)   , _           , _           , _           , c(12, 9)    , _           , _           , d(22)       , b           , b           , c(16, 17)   , _           , _           , b           , b           ],
    [ r(34)       , _           , _           , _           , _           , _           , c(16, 33)   , _           , _           , _           , _           , _           , r(29)       , _           , _           , _           , _           , c(10, 15)   , _           , _           , _           , _           , _           , d(15)       , r(22)       , _           , _           , _           , d(15)       , b           ],
    [ r(14)       , _           , _           , _           , r(20)       , _           , _           , _           , r(23)       , _           , _           , _           , r(16)       , _           , _           , _           , _           , _           , r(34)       , _           , _           , _           , _           , _           , r(17)       , _           , _           , _           , _           , b           ],
    [ b           , r(12)       , _           , _           , r(22)       , _           , _           , _           , r(16)       , _           , _           , b           , r(12)       , _           , _           , r(17)       , _           , _           , r(4)        , _           , _           , r(17)       , _           , _           , b           , b           , r(13)       , _           , _           , b           ],
    [ b           , d(12)       , d(10)       , d(14)       , b           , b           , b           , d(13)       , d(34)       , d(16)       , d(29)       , b           , b           , d(12)       , d(10)       , d(14)       , b           , b           , b           , d(13)       , d(34)       , d(16)       , d(29)       , b           , b           , d(17)       , d(7)        , b           , b           , b           ],
    [ r(8)        , _           , _           , _           , d(10)       , b           , c(6, 30)    , _           , _           , _           , _           , d(23)       , r(8)        , _           , _           , _           , d(10)       , b           , c(6, 30)    , _           , _           , _           , _           , d(23)       , r(4)        , _           , _           , d(40)       , d(18)       , b           ],
    [ r(28)       , _           , _           , _           , _           , c(22, 38)   , _           , _           , _           , _           , _           , _           , r(28)       , _           , _           , _           , _           , c(22, 38)   , _           , _           , _           , _           , _           , _           , r(26)       , _           , _           , _           , _           , d(17)       ],
    [ r(4)        , _           , _           , c(6, 15)    , _           , _           , _           , _           , _           , c(23, 16)   , _           , _           , r(4)        , _           , _           , c(6, 15)    , _           , _           , _           , _           , _           , c(23, 16)   , _           , _           , r(34)       , _           , _           , _           , _           , _           ],
    [ b           , r(4)        , _           , _           , c(22, 9)    , _           , _           , c(8, 29)    , _           , _           , _           , _           , b           , r(4)        , _           , _           , c(22, 9)    , _           , _           , c(8, 29)    , _           , _           , _           , _           , b           , b           , c(25, 11)   , _           , _           , _           ],
    [ b           , d(7)        , c(10, 12)   , _           , _           , _           , c(24, 18)   , _           , _           , _           , d(29)       , b           , b           , d(7)        , c(10, 12)   , _           , _           , _           , c(24, 18)   , _           , _           , _           , d(29)       , b           , b           , r(11)       , _           , _           , b           , b           ],
    [ r(11)       , _           , _           , _           , _           , c(14, 11)   , _           , _           , c(17, 14)   , _           , _           , d(23)       , r(11)       , _           , _           , _           , _           , c(14, 11)   , _           , _           , c(17, 14)   , _           , _           , d(23)       , b           , c(16, 17)   , _           , _           , b           , b           ],
    [ r(4)        , _           , _           , c(3, 35)    , _           , _           , _           , _           , _           , c(16, 16)   , _           , _           , r(4)        , _           , _           , c(3, 35)    , _           , _           , _           , _           , _           , c(16, 16)   , _           , _           , r(22)       , _           , _           , _           , d(15)       , b           ],
    [ r(22)       , _           , _           , _           , _           , _           , _           , r(30)       , _           , _           , _           , _           , r(22)       , _           , _           , _           , _           , _           , _           , r(30)       , _           , _           , _           , _           , r(17)       , _           , _           , _           , _           , b           ],
    [ b           , r(15)       , _           , _           , _           , _           , b           , b           , r(22)       , _           , _           , _           , b           , r(15)       , _           , _           , _           , _           , b           , b           , r(22)       , _           , _           , _           , b           , b           , r(13)       , _           , _           , b           ]
]).

% --- Tabuleiros de casos limite (edge cases) ---
% edge(ID, Descricao, ResultadoEsperado, Tabuleiro)
% ResultadoEsperado: unica | invalido | multiplas | sem_solucao
edge(1, 'controle: 2x2 valido, solucao unica', unica, [
    [ b      , d(3)   , d(7)   ],
    [ r(4)   , _      , _      ],
    [ r(6)   , _      , _      ]
]).
edge(2, 'celulas brancas sem dica vertical (orfas)', invalido, [
    [ b      , b      , b      ],
    [ r(3)   , _      , _      ],
    [ b      , b      , b      ]
]).
edge(3, 'celulas brancas sem dica horizontal (orfas)', invalido, [
    [ b      , d(3)   , d(4)   ],
    [ b      , _      , _      ],
    [ b      , b      , b      ]
]).
edge(4, 'dicas sem nenhuma celula branca (runs vazios)', invalido, [
    [ b      , d(3)   ],
    [ r(5)   , b      ]
]).
edge(5, 'dica seguida de outra dica (run vazio)', invalido, [
    [ b      , d(3)   , d(4)   ],
    [ r(3)   , d(4)   , _      ],
    [ b      , _      , b      ]
]).
edge(6, 'soma abaixo do minimo: r(2) em 2 celulas', invalido, [
    [ b      , d(1)   , d(1)   ],
    [ r(2)   , _      , _      ]
]).
edge(7, 'soma acima do maximo: r(18) em 2 celulas', invalido, [
    [ b      , d(9)   , d(9)   ],
    [ r(18)  , _      , _      ]
]).
edge(8, 'run com 10 celulas (so existem digitos 1..9)', invalido, [
    [ b      , d(1), d(1), d(1), d(1), d(1), d(1), d(1), d(1), d(1), d(1) ],
    [ r(55)  , _   , _   , _   , _   , _   , _   , _   , _   , _   , _    ]
]).
edge(9, 'linhas com tamanhos diferentes (nao retangular)', invalido, [
    [ b      , d(3)   , d(7)   ],
    [ r(4)   , _      , _      ],
    [ r(6)   , _      ]
]).
edge(10, 'dica nao numerica: r(abc)', invalido, [
    [ b      , d(3)   , d(7)   ],
    [ r(abc) , _      , _      ],
    [ r(6)   , _      , _      ]
]).
edge(11, 'celula pre-preenchida / token desconhecido (5)', invalido, [
    [ b      , d(3)   , d(7)   ],
    [ r(4)   , 5      , _      ],
    [ r(6)   , _      , _      ]
]).
edge(12, 'tabuleiro vazio', invalido, []).
edge(13, 'dica 0 (r(0)) em 1 celula', invalido, [
    [ b      , d(1)   ],
    [ r(0)   , _      ]
]).
edge(14, 'valido, mas com 2 solucoes (precisa ser detetado)', multiplas, [
    [ b      , d(3)   , d(3)   ],
    [ r(3)   , _      , _      ],
    [ r(3)   , _      , _      ]
]).
edge(15, 'valido na estrutura, mas somas contraditorias', sem_solucao, [
    [ b      , d(4)   , d(4)   ],
    [ r(3)   , _      , _      ],
    [ r(3)   , _      , _      ]
]).
edge(16, 'valido: a propagacao fixa celulas antes de as colunas serem lidas', unica, [
    [ b      , d(11)  , d(9)   ],
    [ r(17)  , _      , _      ],
    [ r(3)   , _      , _      ]
]).

% Classifica um tabuleiro: invalido | sem_solucao | unica | multiplas
classify(Board, Result) :-
    (   \+ catch(valid_board(Board), _, fail) -> Result = invalido
    ;   findall(Board, limit(2, solve_kakuro(Board)), Sols),
        (   Sols = []  -> Result = sem_solucao
        ;   Sols = [_] -> Result = unica
        ;   Result = multiplas
        )
    ).

% Corre todos os casos limite e mostra OK/FALHOU para cada um.  Uso: ?- run_edge_tests.
run_edge_tests :-
    forall(edge(ID, Desc, Expected, Board),
           (   classify(Board, Got),
               (   Got == Expected -> Status = 'OK    ' ; Status = 'FALHOU' ),
               format('~w #~|~w~t~3+ esperado=~w~t~13+ obtido=~w~t~13+ ~w~n',
                      [Status, ID, Expected, Got, Desc])
           )).

% Resolve todos os tabuleiros 1..13 e mostra o tempo de CPU de cada um.  Uso: ?- test_all.
test_all :-
    forall(( board(ID, _), ID < 100 ),
           (   statistics(cputime, T0),
               (   test_board(ID) -> true ; format('~w: FALHOU~n', [ID]) ),
               statistics(cputime, T1), T is T1 - T0,
               format('--- tabuleiro ~w: ~3f s~n~n', [ID, T])
           )).

% 7. FUNÇÃO DE TESTE COM PARADA IMEDIATA E MEDIÇÃO DE TEMPO DE CPU
test_board(ID) :-
    board(ID, Board),
    write('A analisar as restricoes do tabuleiro '), write(ID), write('...'), nl,
    
    % Captura o tempo de CPU inicial (em segundos)
    statistics(cputime, T0),
    
    % Procura no MÁXIMO 2 soluções e aborta imediatamente se achar a 2ª
    findnsols(2, Board, solve_kakuro(Board), RawSolutions),
    !, % Limpa o ponto de escolha deixado pelo findnsols
    
    % Captura o tempo de CPU final e calcula a duração exata
    statistics(cputime, T1),
    CPUTime is T1 - T0,
    format('Tempo de CPU: ~4f segundos (~2f ms)~n', [CPUTime, CPUTime * 1000]),
    
    sort(RawSolutions, Solutions),
    length(Solutions, Count),
    handle_results(Count, Solutions).

% Caso 0: Tabuleiro sem solução matemática ou com dimensões inválidas.
handle_results(0, _) :-
    write('ERRO: Tabuleiro invalido! Nao possui nenhuma solucao matematica (ou tem linhas desalinhadas).'), nl.

% Caso 1: Tabuleiro válido com solução única.
handle_results(1, [Solution]) :-
    write('Sucesso! Foi encontrada UMA solucao unica e valida:'), nl, nl,
    print_board(Solution).

% Caso 2: Encontrou uma segunda possibilidade e abortou na hora!
handle_results(2, [FirstSolution | _]) :-
    write('ERRO: Tabuleiro invalido/ambiguo! Possui MAIS DE UMA solucao (busca abortada imediatamente na 2a possibilidade).'), nl,
    write('Abaixo esta a primeira solucao encontrada antes da parada:'), nl, nl,
    print_board(FirstSolution).
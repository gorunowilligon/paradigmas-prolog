:- use_module(library(clpfd)). % Importa a biblioteca de Programação em Lógica com Restrições sobre Domínios Finitos (CLPFD). É o motor matemático que resolve o puzzle eficientemente sem tentativa e erro cega.

% --- Regras Fundamentais ---
% Aplica as regras matemáticas do Kakuro a uma lista de variáveis (células brancas).
apply_kakuro_rules(Clue, Vars) :-
    Vars ins 1..9,            % Restrição de domínio: cada variável na sequência tem de ser um número entre 1 e 9.
    all_different(Vars),      % Restrição de unicidade: não pode haver números repetidos na mesma sequência.
    sum(Vars, #=, Clue).      % Restrição de soma: a soma de todas as variáveis da sequência tem de ser exatamente igual à dica (Clue).

% --- Extrair a "Run" (sequência) de variáveis ---
% O objetivo destas três regras é ler uma linha/coluna e recolher todas as células brancas consecutivas após uma dica.

% Caso base: se a lista acabou, a sequência extraída está vazia.
extract_run([], [], []).

% Passo recursivo: se o próximo elemento (Cell) for uma variável livre (célula branca),
% adiciona-a à sequência (Run) e continua a extrair as próximas células (Rest).
extract_run([Cell | Rest], [Cell | Run], Remainder) :-
    var(Cell), !,             % Verifica se Cell é uma variável não instanciada. O '!' (cut) impede que o Prolog tente a regra seguinte (retrocesso) se esta for verdadeira.
    extract_run(Rest, Run, Remainder).

% Condição de paragem: se a célula NÃO for uma variável (é um bloco preto ou uma dica),
% a extração pára. A sequência fica vazia e devolvemos o que sobrou (List -> Remainder).
extract_run(List, [], List).

% --- Percorre as linhas à procura de dicas de soma à direita ---
% Caso base: se a linha estiver vazia, o processamento termina.
process_row([]).

% Se a célula atual for uma variável (célula em branco), ignora-a e avança. 
% Isto evita que o Prolog tente forçar uma dica de texto para dentro de uma célula onde devia estar um número.
process_row([Cell | Rest]) :-
    var(Cell), !,
    process_row(Rest).

% Se encontrar uma dica para a direita "r(Sum)":
process_row([r(Sum) | Rest]) :-
    extract_run(Rest, Run, Remainder), % Extrai todas as células em branco imediatamente a seguir.
    apply_kakuro_rules(Sum, Run),      % Aplica as regras (domínio, diferença e soma) a essas células.
    process_row(Remainder).            % Continua a varrer o que sobrou da linha.

% Se encontrar uma dica dupla "c(Down, Right)":
process_row([c(_, Sum) | Rest]) :-
    extract_run(Rest, Run, Remainder), % Ignora o "Down" (o _) e usa apenas a soma "Right" (Sum).
    apply_kakuro_rules(Sum, Run),
    process_row(Remainder).

% Se for qualquer outra coisa (por exemplo, um bloco preto 'b' ou uma dica para baixo 'd(N)'), ignora e avança.
process_row([_ | Rest]) :-
    process_row(Rest).


% --- Percorre as colunas à procura de dicas de soma para baixo ---
% Funciona com a mesma lógica do process_row, mas foca-se nas dicas verticais.
process_col([]).

process_col([Cell | Rest]) :-
    var(Cell), !,
    process_col(Rest).

% Se encontrar uma dica para baixo "d(Sum)":
process_col([d(Sum) | Rest]) :-
    extract_run(Rest, Run, Remainder),
    apply_kakuro_rules(Sum, Run),
    process_col(Remainder).

% Se encontrar uma dica dupla "c(Down, Right)":
process_col([c(Sum, _) | Rest]) :-
    extract_run(Rest, Run, Remainder), % Desta vez, usa apenas o "Down" (Sum) e ignora o "Right" (_).
    apply_kakuro_rules(Sum, Run),
    process_col(Remainder).

process_col([_ | Rest]) :-
    process_col(Rest).

% --- O solucionador principal ---
solve_kakuro(Board) :-
    maplist(process_row, Board),      % 1. Aplica a função process_row a cada uma das linhas do tabuleiro.
    transpose(Board, Columns),        % 2. Roda a matriz 90 graus (as colunas transformam-se em linhas perfeitamente legíveis para o Prolog).
    maplist(process_col, Columns),    % 3. Aplica a função process_col a todas as novas "linhas" (as colunas originais).
    term_variables(Board, Vars),      % 4. Recolhe numa lista (Vars) todas as variáveis livres em branco que restaram no tabuleiro inteiro.
    label(Vars).                      % 5. Inicia a pesquisa: força o Prolog a substituir as variáveis pelos números reais que satisfazem todas as restrições que criámos.

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

% --- Função Auxiliar de Teste ---
% Permite ao utilizador escrever test_board(1). ou test_board(2). no terminal.
% Vai carregar a matriz correspondente a esse ID, tentar resolvê-la e imprimi-la no ecrã.
test_board(ID) :-
    board(ID, Board),
    write('Resolvendo o tabuleiro '), write(ID), write('...'), nl,
    solve_kakuro(Board),
    print_board(Board).
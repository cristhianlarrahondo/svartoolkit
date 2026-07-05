function y = penalty_generic(q, S_rows, ssigma_norm)
%PENALTY_GENERIC  Generalizacion de helpfunctions/penalty.m (Mountford &
%Uhlig, 2009) a N restricciones de signo sobre un mismo choque.
%
%   y = PENALTY_GENERIC(q, S_rows, ssigma_norm)
%
%   IMPORTANTE: esta funcion vive en src/, NO en helpfunctions/. No
%   modifica ni reemplaza helpfunctions/penalty.m, que se preserva
%   intacto como referencia (convencion del proyecto: helpfunctions/
%   nunca se toca). run_pfa.m usa esta version generalizada via
%   funcion anonima en lugar de las variables globales `objective`/
%   `ssigma` que usa el helpfunctions/penalty.m original.
%
%   Con UNA sola fila (S_rows de 1xn) y ssigma_norm = ssigma(var,1), esta
%   funcion reproduce EXACTAMENTE la logica de helpfunctions/penalty.m:
%
%     x2 = -(1/ssigma_norm) * S_rows*q;
%     y  = 100*x2   si x2>0   (penaliza fuerte si el signo se viola)
%          x2       si x2<=0  (recompensa continua si el signo se cumple,
%                              tal como describe Mountford & Uhlig 2009 y
%                              critica ARW 2018 Seccion 5)
%
%   Con N filas, se SUMA la contribucion de cada restriccion de signo.
%
%   NOTA DE ALCANCE: la suma sobre N>1 filas es una extension de
%   ingenieria para soportar multiples restricciones de signo sobre un
%   mismo choque en PFA. Ni el paper de Mountford & Uhlig (2009) ni el
%   codigo original de ARW (2018) documentan o implementan el caso N>1
%   (BNW solo usa N=1). No existe caso de referencia en original/ para
%   validar N>1 numericamente contra una fuente externa — la validacion
%   de este chat cubre exclusivamente N=1 (reproduccion exacta BNW).
%
%   Entradas:
%     q             [n x 1]  vector unitario candidato (columna ortogonal)
%     S_rows        [nS x n] filas de signo ya proyectadas al espacio de
%                   q (ver run_pfa.m: coef = M_h(var,:) * L, con el signo
%                   de la restriccion ya aplicado)
%     ssigma_norm   [nS x 1] escala de normalizacion por fila (ssigma de
%                   la variable restringida en esa fila)
%
%   Salida:
%     y   escalar — valor de la funcion de perdida a MINIMIZAR por fmincon

y  = 0;
nS = size(S_rows, 1);

for i = 1:nS
    xi = -(1 / ssigma_norm(i)) * S_rows(i,:) * q;
    if xi > 0
        y = y + 100 * xi;
    else
        y = y + xi;
    end
end

end

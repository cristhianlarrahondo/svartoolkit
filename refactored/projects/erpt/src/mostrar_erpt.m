function mostrar_erpt(ERPT, shocks, precios)
%MOSTRAR_ERPT  Tabla de Exchange Rate Pass-Through por horizonte y choque.
%   shocks : cell de choques en orden, p.ej. {'Cam','Dem','Ofe'}.
%   precios: cell de variables de precio, p.ej. {'imp_inf','pro_inf','con_inf'}.
    erpt_print_erpt_digest(ERPT, shocks, precios);
end

function PRIOR = build_niw_custom_prior(Cfg)
%BUILD_NIW_CUSTOM_PRIOR  Construye Cfg.PRIOR para la variante 'niw_custom'
%   de ERPT-Chat 11 (D5, ver ERPT-Chat-10-discusion-cierre.md), aplicada a
%   los 4 specs spec_A_<base|rob>_mm_niwcustom_lag<2|4>_v0.
%
%   PRIOR = BUILD_NIW_CUSTOM_PRIOR(Cfg)
%
%   Diseno (D5): la UNICA diferencia entre esta variante y "Minnesota
%   corregida" (lambda1=0.2, lambda2=0.5, lambda3=2, ERPT-Chat 11) debe ser
%   la MEDIA del prior (Psi_bar) -- no su varianza. Por eso Omega_bar se
%   construye aqui con la MISMA formula y los MISMOS hiperparametros que
%   Minnesota, replicando la parte no-prior de build_posterior.m (carga de
%   datos + dummies + OLS crudo) para obtener sig2(j) identico al que
%   usaria build_posterior si esta spec fuera 'minnesota'. NO se modifica
%   build_posterior.m (Tipo S -- funcion nueva, propia de ERPT, en
%   projects/erpt/src/, no en el core compartido).
%
%   Psi_bar: bloque de rezago-1 con coeficiente propio = 0.90 (por debajo
%   del valor Minnesota estandar de caminata aleatoria, 1.0), dejando
%   margen de estabilidad en la MEDIA del prior. Resto de Psi_bar en cero,
%   mismo patron que Minnesota.
%
%   nu_bar=0, Phi_bar=zeros(n): vagos por defecto -- sin informacion
%   adicional sobre Sigma, igual tratamiento que 'diffuse'/'minnesota'.
%
%   Requiere que el spec que llama a esta funcion ya tenga definidos, ANTES
%   de la llamada: Cfg.DATA_FILE, Cfg.VARS, Cfg.VAR_ROLES, Cfg.NLAG,
%   Cfg.NEX, Cfg.SCALE_FACTOR, Cfg.DUMMIES.
%
%   Entrada:
%     Cfg     struct de configuracion (parcial, con los campos de arriba)
%
%   Salida:
%     PRIOR   struct listo para asignar a Cfg.PRIOR: .type='niw_custom',
%             .nu_bar, .Phi_bar, .Psi_bar, .Omega_bar

% -- Hiperparametros (D2-D5, ERPT-Chat-10-discusion-cierre.md) -----------
LAMBDA1      = 0.2;    % D2: mismo valor que "Minnesota corregida" (ERPT-Chat 11)
LAMBDA2      = 0.5;    % D4: sin cambio
LAMBDA3      = 2;      % D3: sin cambio
PSI_OWN_LAG1 = 0.90;   % D5: media de rezago-1 propio, por debajo de RW (1.0)

% -- Cargar datos y replicar la construccion NO-PRIOR de build_posterior.m
% (misma logica de Y/X, lags/constante/dummies; ver build_posterior.m
% lineas ~30-84). Necesario porque Omega_bar debe fijarse ANTES de que
% build_posterior corra, pero su formula depende de sig2(j) = OLS crudo.
Dataset = load_data(Cfg);

p = Cfg.NLAG;
n = Dataset.nvar;

endo_mask = strcmp(Dataset.var_roles, 'endogenous');
num = Dataset.Y_raw(:, endo_mask) * Cfg.SCALE_FACTOR;

DummyMatrix = build_dummies(Cfg, Dataset.dates);
ndummies    = size(DummyMatrix, 2);

nex_const = Cfg.NEX;
nex_total = nex_const + ndummies;
m         = n*p + nex_total;

yt = num(p+1:end, :);
T  = size(yt, 1);
xt = zeros(T, m);

for i = 1:p
    xt(:, n*(i-1)+1 : n*i) = num((p-(i-1)) : end-i, :);
end
if nex_const >= 1
    xt(:, n*p + 1) = ones(T, 1);
end
if ndummies > 0
    xt(:, n*p + nex_const + 1 : end) = DummyMatrix(p+1:end, :);
end

Y = yt;
X = xt;

B      = (X'*X) \ (X'*Y);
U      = Y - X*B;
Sigmau = U'*U / T;
sig2   = diag(Sigmau);

% -- Omega_bar: MISMA formula y MISMOS hiperparametros que Minnesota -----
w = (1 + (n-1)*LAMBDA2^2) / n;
omega_bar_diag = zeros(m, 1);
for l = 1:p
    for j = 1:n
        idx = (l-1)*n + j;
        omega_bar_diag(idx) = (LAMBDA1 / l^LAMBDA3)^2 * sig2(j) * w;
    end
end
omega_bar_diag(n*p+1 : end) = 1e6;   % constante y dummies: prior muy vaga

% -- Psi_bar: rezago-1 propio = 0.90 (unica diferencia vs Minnesota) -----
Psi_bar = zeros(m, n);
for j = 1:n
    Psi_bar(j, j) = PSI_OWN_LAG1;
end

% -- Empaquetar -----------------------------------------------------------
PRIOR.type      = 'niw_custom';
PRIOR.nu_bar    = 0;
PRIOR.Phi_bar   = zeros(n);
PRIOR.Psi_bar   = Psi_bar;
PRIOR.Omega_bar = diag(omega_bar_diag);

end

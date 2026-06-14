function LtildeStruct = pack_ltilde(Ltilde, mode, shock_idx, horizon, nvar, ndraws)
%PACK_LTILDE  Normaliza el array Ltilde a la struct canonica LtildeStruct.
%
%   LtildeStruct = PACK_LTILDE(Ltilde, mode, shock_idx, horizon, nvar, ndraws)
%
%   Resuelve la asimetria 3D/4D entre PFA e IS:
%     PFA: Ltilde es [horizon+1, nvar, nd]        (3D)
%     IS:  Ltilde es [horizon+1, nvar, nvar, ne]  (4D)
%
%   Campos de LtildeStruct:
%     .mode       string    'pfa' | 'is'
%     .data       array     original 3D o 4D
%     .shock_idx  scalar    indice del shock de interes
%     .horizon    scalar    horizonte maximo
%     .nvar       scalar    numero de variables
%     .ndraws     scalar    nd (PFA) o ne efectivos (IS)

LtildeStruct.mode      = lower(mode);
LtildeStruct.data      = Ltilde;
LtildeStruct.shock_idx = shock_idx;
LtildeStruct.horizon   = horizon;
LtildeStruct.nvar      = nvar;
LtildeStruct.ndraws    = ndraws;

end

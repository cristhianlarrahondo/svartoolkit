%% housekeeping
clearvars;
close all;
clc;

% variables in the following order
% 1: Ajusted TFP
% 2: Stock Prices
% 3: Consumption
% 4: Real Interest Rate
% 5: Hours Worked


%% PFA prior
cd ..
currentFolder = pwd;
cd table_3
try
load([currentFolder,'/figure_1_panel_a/results/matfiles/results.mat'])
catch
   display('Please replicate Panel (a) of Figure 1 before proceeding.') 
   return
end



% vector containing pointwise medians
FEVDq50 = quantile(FEVD,0.5,2);

% vector containing the 16th pointwise quantile
FEVDq16 = quantile(FEVD,0.16,2);

% vector containing the 84th pointwise quantile
FEVDq84 = quantile(FEVD,0.84,2);


format bank
display('PFA')
display([FEVDq16,FEVDq50,FEVDq84])



%% conditionally agnostic prior over IRF parameterization
try
cd ..
currentFolder = pwd;
cd table_3
load([currentFolder,'/figure_1_panel_b/results/matfiles/results.mat'])
catch
   display('Please replicate Panel (b) of Figure 1 before proceeding.') 
   return
end

% vector containing pointwise medians
FEVDq50 = quantile(FEVD,0.5,2);

% vector containing the 16th pointwise quantile
FEVDq16 = quantile(FEVD,0.16,2);

% vector containing the 84th pointwise quantile
FEVDq84 = quantile(FEVD,0.84,2);
display('Importance Sampler')
display([FEVDq16,FEVDq50,FEVDq84])

